#!/bin/bash
# contains reusable functions across scripts

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
    if [ $? != 0 ]; then
        echo "ERROR: Failed to read $2 from $config_file"
        exit 1
    fi
}

function azure_login {
    # do we use the service principal?
    current_subscription="$(az account show | jq -r .id)"
    if [ "$current_subscription" != "$subscription_id" ]; then
        echo "Log in with Azure CLI"
        az login --service-principal \
            --username=$sp_client_id \
            --password=$sp_client_secret \
            --tenant=$sp_tenant_id \
            --output table
        if [ $? != 0 ]; then
            echo "ERROR: Failed to log in to Azure CLI"
            exit 1
        fi

        echo "Setting subscription ($subscription_id)"
        az account set --subscription "$subscription_id"
        if [ $? != 0 ]; then
            echo "ERROR: Failed to set the subscription"
            exit 1
        fi
    fi
}

function batch_login {
    echo "logging in to batch account"
    az batch account login \
        --resource-group $batch_rg \
        --name $batch_account \
        --output table    
}


function wait_for_task {
    job_id=$1
    task_log=$2
    application_log=$3
    # retrieve the task id
    taskid=$(grep "Task ID:" ${task_log} | cut -d ' ' -f 3)
    if [ "$taskid" == "" ]; then
        echo "ERROR: unable to retrieve task id"
        exit 1
    fi

    # get the task status, wait until the task is finished

    loop=true
    while [ "$loop" != false ]; do
        sleep 20
        task_state=$(az batch task show --job-id ${job_id} --task-id ${taskid} --query "state" --output tsv)
        echo "task ${taskid} is $task_state"
        if [ "$task_state" == "active" ]; then
            continue
        elif [ "$task_state" == "completed" ]; then
            # get stderr & stdout
            az batch task file download --job-id ${job_id} --task-id ${taskid} --destination ./stderr.txt --file-path stderr.txt
            az batch task file download --job-id ${job_id} --task-id ${taskid} --destination ./stdout.txt --file-path stdout.txt
            cat stdout.txt
            cat stderr.txt

            # get application log
            if [ "$application_log" != "" ]; then
                az batch task file download --job-id ${job_id} --task-id ${taskid} --destination ./${application_log} --file-path ./wd/${application_log}
                cat ${application_log}
            fi
            # task is finished, check if its succeeded or failed
            task_result=$(az batch task show --job-id ${job_id} --task-id ${taskid} --query "executionInfo.result" --output tsv)
            if [ "$task_result" == "failure" ]; then
                exit 1
            fi
            loop=false
        fi
    done
}

function get_pool_id {
    appname=$1
    read_value vm_size ".images.vm_size"
    vmsku=$(echo $vm_size | cut -d '_' -f 2)
    POOL_ID="${appname}_${vmsku}"
}