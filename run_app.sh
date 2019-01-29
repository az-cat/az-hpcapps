#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

config_file="config.json"
app=
app_script=
num_nodes=
ppn=
script_flags=
jobname=
taskname=
repeat=1
identity="autouser/pool/nonadmin"

function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -c config.json -a APPNAME "
    echo "    -a: application (application list)"
    echo "    -c: config file to use"
    echo "    -h: help"
    echo "    -i: identity : username or scope/elevation for batch auto user - scope: pool or task - elevation: admin or nonadmin"
    echo "    -j: job name (create job if not exists) - if not specified application name is used"
    echo "    -n: number of nodes"
    echo "    -p: processes per node"
    echo "    -q: pool name (in order to force running a script on a specific pool)"
    echo "    -r: repeat n times the same task"
    echo "    -s: script to run"
    echo "    -t: task name - if not specified automatically built"
    echo "    -x: script flags to pass"
    echo ""
}

while getopts "a: c: s: n: p: q: x: r: j: t: i: h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        a)
        app=$OPTARG
            ;;
        j)
        jobname=$OPTARG
            ;;
        t)
        taskname=$OPTARG
            ;;
        s)
        app_script=$OPTARG
            ;;
        n)
        num_nodes=$OPTARG
            ;;
        p)
        ppn=$OPTARG
            ;;
        q)
        pool_name=$OPTARG
            ;;
        x)
        script_flags=$OPTARG
            ;;
        r)
        repeat=$OPTARG
            ;;
        i)
        identity=$OPTARG
            ;;
        h)
        usage
        exit 0
            ;;
    esac
done

shift $(( OPTIND - 1 ));

if [ -z "$pool_name" ]; then
    get_pool_id $app
    pool_id=$POOL_ID
else
    pool_id=$pool_name
fi

if [ -z "$jobname" ]; then
    jobname=$pool_id
fi

# Set to default values if not set through input args
ppn=${ppn:-"1"}
num_nodes=${num_nodes:-"1"}

# Print out input values
echo "config file: $config_file"
echo "app: $app"
echo "app script: $app_script"
echo "num nodes: $num_nodes"
echo "processes per node: $ppn"
echo "script flags: $script_flags"
echo "job name: $jobname"
echo "task name: $taskname"
echo "repeat: $repeat"
echo "identity: $identity"

function fill_jobfile {

    task_template_file=$DIR/batch/task-template.json
    
    replace="s,#TASK_ID#,$task_id,g"
    replace+=";s,#JOB_ID#,$job_id,g"
    replace+=";s,#APP#,$app,g"
    replace+=";s,#APP_SCRIPT#,$app_script,g"
    replace+=";s,#RESULTS_ENDPOINT#,$results_storage_endpoint,g"
    replace+=";s,#RESULTS_CONTAINER#,$results_container,g"
    replace+=";s,#RESULTS_SASKEY#,$results_saskey,g"
    replace+=";s,#NUM_NODES#,$num_nodes,g"
    replace+=";s,#PPN#,$ppn,g"
    replace+=";s,#LICSERVER#,$licserver,g"
    replace+=";s,#HPC_DATA_SASKEY#,$hpc_data_saskey,g"
    replace+=";s,#HPC_DATA_STORAGE_ENDPOINT#,${hpc_data_storage_endpoint},g"
    replace+=";s,#HPC_APPS_STORAGE_ENDPOINT#,${hpc_apps_storage_endpoint},g"
    replace+=";s,#HPC_APPS_SASKEY#,$hpc_apps_saskey,g"
    replace+=";s,#SCRIPT_FLAGS#,${script_flags},g"
    replace+=";s,#ANALYTICS_WORKSPACE#,${analytics_workspace},g"
    replace+=";s,#ANALYTICS_KEY#,${analytics_key},g"

    user=$(echo $identity | cut -d'/' -f1)
    if [ "${user,,}" = "autouser" ]; then
        scope=$(echo $identity | cut -d'/' -f2)
        elevation=$(echo $identity | cut -d'/' -f3)
        autoUser=$(jq -c '.autoUser.scope=$scope | .autoUser.elevationLevel=$elevation' --arg scope "$scope" --arg elevation "$elevation" <<< "{}")
        template=$(jq -c '.userIdentity=$autoUser' --argjson autoUser "$autoUser" <<< $(cat $task_template_file))
    else
        template=$(jq -c 'del(.userIdentity.autoUser) | .userIdentity.username=$user' --arg user "$user" <<< $(cat $task_template_file))        
    fi


    # escape string for sed
    echo "Replace string: \"$replace\""
    replace=$(sed "s/\&/\\\&/g" <<< "$replace")
    sed "$replace" <<< $(echo $template) > ${task_id}.json

}


function create_jobfile {
    # create container for results and policy (if it doesn't exist)
    read_value results_storage_rg ".results.resource_group"
    read_value results_storage_name ".results.storage_account"
    read_value results_container ".results.container"
    read_value app_storage_name ".appstorage.storage_account"
    read_value app_container ".appstorage.app_container"

    create_rw_sas_key $results_storage_rg $results_storage_name $results_container
    results_saskey=$SAS_KEY
    echo "SAS Key = $results_saskey"
    results_storage_endpoint=$(az storage account show \
        --resource-group $results_storage_rg \
        --name $results_storage_name \
        --query "primaryEndpoints.blob" \
        --output tsv)
    echo "Results storage endpoint is $results_storage_endpoint"

    # upload the batch wrapper and the application scripts
    echo "Uploading batch wrapper"
    filename="$DIR/batch/batch_wrapper.sh"
    blobname="${app}/${job_id}/scripts/batch_wrapper.sh"
    az storage blob upload \
        --container-name $results_container \
        --account-name $results_storage_name \
        --file $filename \
        --name $blobname \
        --output table

    echo "Uploading application runner"
    filename="$DIR/apps/${app}/run_${app_script}.sh"
    blobname="${app}/${job_id}/scripts/run_${app_script}.sh"
    az storage blob upload \
        --container-name $results_container \
        --account-name $results_storage_name \
        --file $filename \
        --name $blobname \
        --output table

    read_value licserver ".infrastructure.licserver"
    read_value data_storage_name ".appstorage.storage_account"
    read_value data_container ".appstorage.data_container"
    read_value hpc_data_saskey ".appstorage.data_saskey"

    if [ "$hpc_data_saskey" == "" ]; then
        # Create input data SAS KEY
        read_value data_storage_rg ".appstorage.resource_group"
        create_read_sas_key $data_storage_rg $data_storage_name $data_container
        hpc_data_saskey=$SAS_KEY
    fi
    echo "HPC data SAS Key = $hpc_data_saskey"
    hpc_data_storage_endpoint="http://$data_storage_name.blob.core.windows.net/$data_container"
    echo "HPC data storage endpoint is $hpc_data_storage_endpoint"

    read_value analytics_workspace ".infrastructure.analytics.workspace"
    read_secret analytics_key ".infrastructure.analytics.key"

    read_value hpc_apps_saskey ".appstorage.app_saskey"
    if [ "$hpc_apps_saskey" == "" ]; then
        read_value app_storage_rg ".appstorage.resource_group"
        read_value app_storage_name ".appstorage.storage_account"
        read_value app_container ".appstorage.app_container"
        # Create input data SAS KEY
        create_read_sas_key $app_storage_rg $app_storage_name $app_container
        hpc_apps_saskey=$SAS_KEY
    fi

    hpc_apps_storage_endpoint="https://$app_storage_name.blob.core.windows.net/$app_container"
    echo "HPC apps storage endpoint is $hpc_apps_storage_endpoint"

    fill_jobfile
}

timestamp=$(date +%Y%m%d-%H%M%S)
if [ -z "$taskname" ]; then
    taskname=${app_script}_${num_nodes}_${ppn}
fi

job_id=$jobname
task_id=${taskname}_${timestamp}

azure_login

read_value cluster_type ".cluster_type"

if [ "$cluster_type" == "batch" ]; then

    #
    # RUN SCRIPT ON BATCH POOL FOR THE CLUSTER
    #

    batch_login

    jobstate=$(az batch job show --job-id $jobname --query "state" 2>/dev/null)
    if [ -z "$jobstate" ]; then
        echo "Create job $job_id for pool $pool_id"
        az batch job create \
            --id $job_id \
            --pool-id $pool_id \
            --output table
    fi

    create_jobfile

    echo "Task ID: $task_id"
    echo "Job ID: $job_id"
    for i in $(seq 1 $repeat); do
        az batch task create --job-id $job_id --json-file ${task_id}.json --output table
        rm ${task_id}.json

        timestamp=$(date +%Y%m%d-%H%M%S)
        task_id=${taskname}_${timestamp}
        fill_jobfile
    done

    echo "Job ID: $job_id"
    rm ${task_id}.json

elif [ "$cluster_type" == "cyclecloud" ]; then
    echo "Running app in the Cycle GridEngine Cluster"
    create_jobfile

    if ! which cyclecloud > /dev/null ;then
    PATH=$HOME/bin:./bin:$PATH
    fi

    rsaPublicKey="$HOME/.ssh/id_rsa.pub"
    if [ ! -f $rsaPublicKey ]; then
        echo "No public ssh key found ($rsaPublicKey)."
        echo "Run ssh-key with all default options and re-run this script."
        exit 1
    fi

    cluster_ip=$(cyclecloud show_nodes master -c appcatalog_gridengine --format json | jq '.[0]["Instance"]["PublicIp"]' | sed 's/\"//g')
    scp ${task_id}.json $cluster_ip:appcatalog/


    # images names are tagged with the node Sku
    get_pool_id $app
    pool_id=$POOL_ID

    read_value image_rg ".images.resource_group"
    image_id=$(az image list \
        --resource-group $image_rg \
        --query "[?contains(name,'$pool_id-')].[name,id]" \
        --output tsv \
        | sort | tail -n1 | cut -d$'\t' -f2)
    echo "$app image: $image_id"

    if [ -z $image_id ];then
        echo "Unable to locate image for app $app"
        exit 1
    fi

    read_value machine_size ".images.vm_size"
    command="submit_azbatch_task.py -a $app -b ~/appcatalog/${task_id}.json -i $image_id -p $ppn -n $num_nodes -m $machine_size"

    echo "Submmiting job in cluster: "
    echo "$command"
    ssh $cluster_ip "cd ~/appcatalog/; $command"
    rm -f ${task_id}.json

else
    echo "Unknown cluster type"
fi
