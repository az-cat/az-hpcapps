#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

config_file="config.json"
app=
update_pool=no

function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -c config.json -a APPNAME "
    echo "    -c: config file to use"
    echo "    -a: application (application list)"
    echo "    -u: [yes, no] update if pool exists, otherwise delete and re-create (default behavior)"
    echo "    -h: help"
    echo ""
}

while getopts "a: c: u: h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        a)
        app=$OPTARG
            ;;
        u)
        update_pool=$OPTARG
            ;;
        h)
        usage
        exit 0
            ;;
    esac
done

shift $(( OPTIND - 1 ));

echo "config file: $config_file"
echo "app: $app"
echo "update pool: $update_pool"

read_value subscription_id ".subscription_id"
read_value location ".location"
read_value vnet_rg ".infrastructure.network.resource_group"
read_value vnet ".infrastructure.network.vnet"
read_value subnet ".infrastructure.network.subnet"
read_value admin_subnet ".infrastructure.network.admin_subnet"
read_value nfsserver ".infrastructure.nfsserver"
read_value nodeAgentSKUId ".images.nodeAgentSKUId"

timestamp=$(date +%Y%m%d-%H%M%S)

azure_login

read_value cluster_type ".cluster_type"

if [ "$cluster_type" == "batch" ]; then

    #
    # CREATE A BATCH POOL FOR THE CLUSTER
    #

    echo "Creating cluster with Batch Pool."

    read_value batch_rg ".batch.resource_group"
    read_value storage_name ".batch.storage_account"
    read_value container_name ".batch.storage_container"
    read_value app_storage_rg ".appstorage.resource_group"
    read_value app_storage_name ".appstorage.storage_account"
    read_value app_container ".appstorage.app_container"
    read_value hpc_apps_saskey ".appstorage.app_saskey"

    # create SAS key
    create_read_sas_key $batch_rg $storage_name $container_name
    saskey=$SAS_KEY
    echo "SAS Key = $saskey"

    if [ "$hpc_apps_saskey" == "" ]; then
        # Create input data SAS KEY
        create_read_sas_key $app_storage_rg $app_storage_name $app_container
        hpc_apps_saskey=$SAS_KEY
    fi

    echo "HPC apps SAS Key = $hpc_apps_saskey"
    hpc_apps_storage_endpoint="https://$app_storage_name.blob.core.windows.net/$app_container"
    echo "HPC apps storage endpoint is $hpc_apps_storage_endpoint"

    # create and upload the node config script (i.e. mount NFS)
    read_value nfsmount ".infrastructure.nfsmount"
    read_value beegfs_mgmt ".infrastructure.beegfs.mgmt"
    read_value beegfs_mount ".infrastructure.beegfs.mount"

    start_task_file_name="starttask-${app}.sh"
    temp_start="${timestamp}.sh"
    cp starttask_common.sh ${temp_start}

    # append app start task if it exists
    app_starttask=$DIR/apps/$app/starttask_$app.sh
    echo $app_starttask
    if [ -f "$app_starttask" ]; then
        echo "Appending to start task ($app_starttask)"
        cat $app_starttask >> $temp_start
    fi

    # replace keywords in startask
    replace="s,#NFS_SERVER#,$nfsserver,g"
    replace+=";s,#NFS_MOUNT#,$nfsmount,g"
    replace+=";s,#BEEGFS_MGMT#,$beegfs_mgmt,g"
    replace+=";s,#BEEGFS_MOUNT#,$beegfs_mount,g"
    replace+=";s,#HPC_APPS_STORAGE_ENDPOINT#,$hpc_apps_storage_endpoint,g"
    replace+=";s,#HPC_APPS_SASKEY#,$hpc_apps_saskey,g"

    # escape string for sed
    echo "Replace string: \"$replace\""
    replace=$(sed "s/\&/\\\&/g" <<< "$replace")
    sed "$replace" ${temp_start} > ${start_task_file_name}

    # upload file
    echo "Uploading start task"
    az storage blob upload \
        --container-name $container_name \
        --account-name $storage_name \
        --file $start_task_file_name \
        --name $start_task_file_name \
        --output table

    # get storage endpoint
    read_value image_rg ".images.resource_group"
    storage_endpoint=$(az storage account show \
        --resource-group $batch_rg \
        --name $storage_name \
        --query "primaryEndpoints.blob" \
        --output tsv)
    echo "Storage endpoint is $storage_endpoint"

    # generate start task source string
    start_task_source="${storage_endpoint}${container_name}/$start_task_file_name?$saskey"
    echo "Start task source: $start_task_source"

    # get vhd for image
    read_value vmsize ".images.vm_size"
    read_value image_rg ".images.resource_group"

    get_pool_id $app
    pool_id=$POOL_ID

    image_id=$(az image list \
        --resource-group $image_rg \
        --query "[?contains(name,'$pool_id-')].[name,id]" \
        --output tsv \
        | sort | tail -n1 | cut -d$'\t' -f2)
    echo "Image ID: $image_id"

    subnet_id=$(az network vnet subnet show \
        --resource-group $vnet_rg \
        --vnet-name $vnet \
        --name $subnet \
        --query id --output tsv)
    batchpool_template=batchpool-${app}.json
    cat <<EOF >$batchpool_template
{
  "id": "$pool_id",
  "vmSize": "$vmsize",
  "virtualMachineConfiguration": {
    "imageReference": {
      "virtualMachineImageId": "$image_id"
    },
    "nodeAgentSKUId": "$nodeAgentSKUId"
  },
  "targetDedicatedNodes": 0,
  "enableInterNodeCommunication": true,
  "networkConfiguration": {
    "subnetId": "$subnet_id"
  },
  "maxTasksPerNode": 1,
  "taskSchedulingPolicy": {
    "nodeFillType": "Pack"
  },
  "startTask": {
    "commandLine":"bash ${start_task_file_name}",
    "resourceFiles": [
      {
        "httpUrl":"$start_task_source",
        "filePath":"${start_task_file_name}"
      }
    ],
    "userIdentity": {
        "autoUser": {
          "scope":"pool",
          "elevationLevel":"admin"
        }
    },
    "maxTaskRetryCount":3,
    "waitForSuccess":true
  }
}
EOF

    read_value batch_account ".batch.account_name"
    batch_login

    echo "check if batch pool $pool_id exists"
    batch_pool=$(az batch pool list --filter "id eq '$pool_id'" -o tsv)
    if [[ ! -z "$batch_pool" ]]; then
        # if update pool, update it otherwise delete and recreate the pool
        if [ "$update_pool" = "yes" ]; then 
            echo "updating batch pool $pool_id"
            az batch pool set \
                --pool-id ${pool_id} \
                --json-file $batchpool_template \
                --output table

            if [ $? != 0 ]; then
                echo "ERROR: Failed to update pool $pool_id"
                exit 1
            fi
        else
            echo "deleting batch pool $pool_id"
            az batch pool delete \
                --pool-id ${pool_id} \
                --account-name $batch_account \
                --yes

            # wait for the pool to be deleted        
            loop=true
            while [ "$loop" != false ]; do
                sleep 30
                # retrieve the pool status. If deleting then loop
                poolstatus=$(az batch pool show --pool-id $pool_id --account-name $batch_account --query "allocationState" --output tsv)
                echo "pool status is $poolstatus"
                if [ "$poolstatus" == "deleting" ] || [ "$poolstatus" == "resizing" ] || [ "$poolstatus" == "steady" ]; then
                    continue
                fi
                loop=false
            done

            echo "creating batch pool $pool_id"
            az batch pool create \
                --json-file $batchpool_template \
                --output table

            if [ $? != 0 ]; then
                echo "ERROR: Failed to create pool $pool_id"
                exit 1
            fi

        fi
    else
        echo "creating batch pool $pool_id"
        az batch pool create \
            --json-file $batchpool_template \
            --output table

        if [ $? != 0 ]; then
            echo "ERROR: Failed to create pool $pool_id"
            exit 1
        fi
    fi


    rm $batchpool_template
    rm $start_task_file_name
    rm $temp_start

else
    echo "Unknown cluster type"
fi
