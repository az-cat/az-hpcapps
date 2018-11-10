#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

config_file="config.json"
app=

function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -c config.json -a APPNAME "
    echo "    -c: config file to use"
    echo "    -a: application (application list)"
    echo "    -h: help"
    echo ""
}

while getopts "a: c: h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        a)
        app=$OPTARG
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

read_value subscription_id ".subscription_id"
read_value location ".location"
read_value sp_client_id ".service_principal.client_id"
read_value sp_client_secret ".service_principal.client_secret"
read_value sp_tenant_id ".service_principal.tenant_id"
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

    storage_key=$(az storage account keys list \
        --resource-group $batch_rg \
        --account-name $storage_name \
        --query "[0].value" \
        --output tsv)

    # create container for start tasks and policy (if it doesn't exist)
    container_exists="$(az storage container exists \
        --account-name $storage_name \
        --account-key "$storage_key" \
        --name $container_name --output tsv)"
    if [ "$container_exists" == "False" ]; then
        echo "Creating container ($container_name)..."
        az storage container create \
            --account-name $storage_name \
            --account-key "$storage_key" \
            --name $container_name \
            --output table

        echo "Adding container policy for read access"
        az storage container policy create \
            --container-name $container_name \
            --name read \
            --permissions r \
            --account-key $storage_key \
            --account-name $storage_name \
            --start $(date --utc -d "-2 hours" +%Y-%m-%dT%H:%M:%SZ) \
            --expiry $(date --utc -d "+1 year" +%Y-%m-%dT%H:%M:%SZ)
    else
        echo "Container ($container_name) already exists."
    fi

    # create and upload the node config script (i.e. mount NFS)
    read_value nfsmount ".infrastructure.nfsmount"
    read_value beegfs_mgmt ".infrastructure.beegfs.mgmt"
    read_value beegfs_mount ".infrastructure.beegfs.mount"

    start_task_file_name="starttask-${app}-${timestamp}.sh"
    cat <<EOF >$start_task_file_name
#!/bin/bash

mkdir /data
echo "$nfsserver:${nfsmount}    /data   nfs defaults,proto=tcp,nfsvers=3,rsize=65536,wsize=65536,noatime,soft,timeo=30 0 0" >> /etc/fstab
chmod 777 /data

mount -a

if [ "$beegfs_mgmt" != "" ]; then
	sed -i 's/^sysMgmtdHost.*/sysMgmtdHost = '$beegfs_mgmt'/g' /etc/beegfs/beegfs-client.conf
	echo "$beegfs_mount /etc/beegfs/beegfs-client.conf" > /etc/beegfs/beegfs-mounts.conf

	systemctl enable beegfs-helperd.service
	systemctl enable beegfs-client.service
	systemctl start beegfs-helperd.service
	systemctl start beegfs-client.service
else
	systemctl disable beegfs-helperd.service
	systemctl disable beegfs-client.service
fi
EOF
    # append app start task if it exists
    app_starttask=./apps/$app/starttask_$app.sh
    echo $app_starttask
    if [ -f "$app_starttask" ]; then
        echo "Appending to start task ($app_starttask)"
        cat $app_starttask >> $start_task_file_name
    fi
    # upload file
    echo "Uploading start task"
    az storage blob upload \
        --container-name $container_name \
        --account-name $storage_name \
        --account-key $storage_key \
        --file $start_task_file_name \
        --name $start_task_file_name \
        --output table
    # create SAS key
    saskey=$(az storage container generate-sas \
        --policy-name read \
        --name $container_name \
        --account-name $storage_name \
        --account-key $storage_key \
        --output tsv)
    echo "SAS Key = $saskey"
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
    cat <<EOF >batchpool-${app}-${timestamp}.json
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
    "commandLine":"bash starttask-${app}-${timestamp}",
    "resourceFiles": [
      {
        "blobSource":"$start_task_source",
        "filePath":"starttask-${app}-${timestamp}"
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
    fi

    echo "creating batch pool $pool_id"
    az batch pool create \
        --json-file batchpool-${app}-${timestamp}.json \
        --output table

    if [ $? != 0 ]; then
        echo "ERROR: Failed to create pool $pool_id"
        exit 1
    fi

    rm "batchpool-${app}-${timestamp}.json"
    rm $start_task_file_name

elif [ "$cluster_type" == "cyclecloud" ]; then

    username=$(whoami)
    PATH=$HOME/bin:$PATH
    read_value cyclecloud_rg .cyclecloud.resource_group
    cyclecloud_ver="latest"

    # 1. Check that the CycleCloud CLI is installed. It not, download and install it
    if ! which cyclecloud > /dev/null ;then
        mkdir -p bin
        
        # Check to see if we're in Cloud Shell. Need to make python point to python2 
        if [ ! -z $ACC_TERM_ID ];then
            echo "In Azure Cloud Shell"
            python2_bin=$(which python2)
            ln -s $python2_bin ./bin/python
        fi
        PATH=$(pwd)/bin:$PATH
        wget "https://cyclecloudarm.blob.core.windows.net/cyclecloudrelease/$cyclecloud_ver/cyclecloud-cli.zip"
        unzip cyclecloud-cli.zip
        pushd cyclecloud-cli-installer > /dev/null 
        ./install.sh
        popd > /dev/null
        rm -rf cyclecloud-cli.zip cyclecloud-cli-installer 
    fi
    # create hpcuser key
    # Take a page from the infrastructure deployment -- use user's public key.
    rsaPublicKey=$(cat ~/.ssh/id_rsa.pub)

    if [ "$rsaPublicKey" == "" ]; then
        echo "No public ssh key found (in ~/.ssh/id_rsa.pub)."
        echo "Run ssh-key with all default options and re-run this script."
        exit 1
    fi

    read_value cyclecloud_admin_password .cyclecloud.admin_password

    cyclecloud_container_name=$(echo "${cyclecloud_rg}acc01" | tr '[:upper:]' '[:lower:]')

    # 2. Check that the CycleCloud server is setup and initialized with the CLI
    if ! cyclecloud config use $cyclecloud_rg > /dev/null 2>&1 ;then
        echo "Searching for 'cyclecloud' in Resoruce Group '$cyclecloud_rg'"
        cyclecloud_fqdn=$(az container show -g $cyclecloud_rg  --name $cyclecloud_container_name  --query "ipAddress.fqdn" | sed 's/\"//g')
        if [ -z $cyclecloud_fqdn ]; then
            while true; do
                echo "---- Azure Container Instance $cyclecloud_container_name in resource group $cyclecloud_rg not found."
                read -p "    Start Azure container running Cyclecloud? [y/n] " yn
                case $yn in
                    y )
                    break;;
                    n ) exit;;
                    - ) echo "-- Please answer yes or no.";;
                esac
            done
            echo "Creating resource group $cyclecloud_rg"
            az group create -n $cyclecloud_rg --location $location 
            echo "Deploying Azure CycleCloud container in resource group $cyclecloud_rg. Please wait. This takes about 5mins."
            hostname_suffix=$(date | md5sum | awk '{print $1}' | cut -c1-8)
            cyclecloud_hostname="cyclecloud$hostname_suffix"

            az container create -g $cyclecloud_rg --location $location --name $cyclecloud_container_name \
            --dns-name-label $cyclecloud_hostname  --image mcr.microsoft.com/hpc/azure-cyclecloud  \
            --ip-address public --ports 80 443 --cpu 2 --memory 7 \
            -e JAVA_HEAP_SIZE=4096 DNS_NAME=$cyclecloud_hostname LOCATION=$location \
            CYCLECLOUD_AUTOCONFIG=true CYCLECLOUD_ACCEPT_TERMS=true \
            CYCLECLOUD_USERNAME=$username CYCLECLOUD_PASSWORD=$cyclecloud_admin_password \
            CYCLECLOUD_USER_PUB_KEY="$rsaPublicKey"

            cyclecloud_fqdn=$(az container show -g $cyclecloud_rg  --name $cyclecloud_container_name  --query "ipAddress.fqdn" | sed 's/\"//g')
            echo "Waiting for Azure CycleCloud container at $cyclecloud_fqdn to start "
            until $(curl -k --connect-timeout 2 --output /dev/null --silent --head --fail https://$cyclecloud_fqdn); do
                printf "."
                sleep 10s
            done
            echo ""
            sleep 10s

        fi
        cyclecloud_fqdn=$(az container show -g $cyclecloud_rg  --name $cyclecloud_container_name  --query "ipAddress.fqdn" | sed 's/\"//g')
        echo "CycleCloud server found: $cyclecloud_fqdn"
        echo "Initializing CLI with CycleCloud server"
        read_value cyclecloud_admin_user .cyclecloud.admin_user
        cyclecloud initialize --force --batch --name $cyclecloud_rg --url=https://$cyclecloud_fqdn --verify-ssl=false --username=$cyclecloud_admin_user --password=$cyclecloud_admin_password

        cat > azure_account.json << FILE
{
    "Environment": "public",
    "AzureRMApplicationId": "$sp_client_id",
    "AzureRMApplicationSecret": "$sp_client_secret",
    "AzureRMSubscriptionId": "$subscription_id",
    "AzureRMTenantId": "$sp_tenant_id",
    "AzureResourceGroup": "$cyclecloud_rg",
    "DefaultAccount": true,
    "Location": "$location",
    "Name": "azure",
    "Provider": "azure",
    "ProviderId": "$subscription_id",
    "RMStorageAccount": "$cyclecloud_hostname",
    "RMStorageContainer": "cyclecloud"
}
FILE

        cyclecloud account create -f azure_account.json 
        sleep 60s

    fi

    cyclecloud config use $cyclecloud_rg

    cyclecloud_storage_account=$(cyclecloud locker list  |  sed -e 's|^[^/]*//||' -e 's|/.*$||')
    pogo_config_file=~/.cycle/pogo.ini
    touch $pogo_config_file
    if ! grep -q $cyclecloud_storage_account $pogo_config_file; then
        echo "Creating ~/.cycle/pogo.ini"
        cyclecloud_storage_key=$(az storage account keys list -g $cyclecloud_rg -n $cyclecloud_storage_account --query "[0].value" | sed 's/\"//g')


        cat <<EOF >> $pogo_config_file

[pogo $cyclecloud_storage_account]
type = az
matches = az://$cyclecloud_storage_account
access_key=$cyclecloud_storage_key
EOF

    fi

    # update the applications benchmark and run scripts into CycleCloud projects so that they are available on each cluster
    cyclecloud_project_dir=cyclecloud/projects/appcatalog
    cp -a apps $cyclecloud_project_dir/specs/master/cluster-init/files/

    pushd $cyclecloud_project_dir/ > /dev/null
    echo "Updating cyclecloud appcatalog project in your storage account"
    cyclecloud project upload azure-storage
    popd >/dev/null

    # if application is specified, create an app specific cluster
    # else create a generic one that is able to run all apps
    # if [ -z $app ];then

    # Disable the app specific clusters for now.
    if [ ! -z $app ];then
        echo ""        
        echo "  You specified an app: '$app'"
        echo "  Azure CycleCloud will create a single cluster that can run any of the supported apps."
        echo ""
    fi

    cyclecloud_cluster_name=appcatalog_gridengine

    # check is cluster is running, if not, create cluster
    if ! cyclecloud show_cluster $cyclecloud_cluster_name ;then

        echo "Cluster $cyclecloud_cluster_name not found. Creating cluster"

        master_subnet="$vnet_rg/$vnet/$admin_subnet"
        compute_subnet="$vnet_rg/$vnet/$subnet"
        compute_subnet_cidr=$(az network vnet subnet list -g $vnet_rg --vnet-name $vnet  --query "[?contains(name,'$subnet')]"  | jq '.[0]["addressPrefix"]' | sed 's/\"//g')


        # create cluster
        pushd $cyclecloud_project_dir/templates/ > /dev/null
            cyclecloud_params_file=$cyclecloud_cluster_name.params.$timestamp.json
            replace="s,_REGION_,$location,g"
            replace+=";s,_MASTERSUBNETID_,$master_subnet,g"
            replace+=";s,_COMPUTESUBNETID_,$compute_subnet,g"
            replace+=";s,_COMPUTESUBNET_,$compute_subnet_cidr,g"

            sed  "$replace" appcatalog_gridengine.params.json > $cyclecloud_params_file
            cyclecloud import_cluster $cyclecloud_cluster_name -c appcatalog -p $cyclecloud_params_file -f appcatalog_gridengine.txt
        popd > /dev/null

    fi
    cyclecloud start_cluster $cyclecloud_cluster_name
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "  Azure CycleCloud "
    echo "      Running at: https://$cyclecloud_fqdn"
    echo ""
    echo "  Login to the web interface using your username: '$(whoami)' "
    echo "  The password is the secret of your service-principal"
    echo "  You can find the service principal-sercret in the config file: ./$config_file"
    echo ""
    echo "  To see running clusters and the ipaddress of the cluster nodes, run: "
    echo "      $ $HOME/bin/cyclecloud show_cluster -l to see running clusters"
    echo ""
    echo "  Connect to the master node by running: "
    echo "      $ $HOME/bin/cyclecloud connect master -c appcatalog_gridengine"
    echo "  Or by using your SSH client: "
    echo "      $ ssh $(whoami)@masternode-public-ip"
    echo ""
    echo "  For more operations, go to the Web interface or run:"
    echo "      $ $HOME/bin/cyclecloud -h"
    echo "--------------------------------------------------------------------------------"
    echo ""

else
    echo "Unknown cluster type"
fi
