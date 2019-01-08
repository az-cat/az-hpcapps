#!/bin/bash
# contains reusable functions across scripts

# Read value from json file $config_file
# $1 is the variable to fill
# $2 is the json path to the value
function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
    if [ $? != 0 ]; then
        echo "ERROR: Failed to read $2 from $config_file"
        exit 1
    fi
}

# read a secret from key vault
# keyvault name and key name are stored in the value of the variable read from the json $config_file
function read_secret {
    read_value keyvault_name $2
    vault_name=$(echo ${keyvault_name} | cut -d'.' -f1)
    key_name=$(echo ${keyvault_name} | cut -d'.' -f2)

    # if working in CloudShell MSI_ENDPOINT is setup
    # if MSI_ENDPOINT is empty and if running in an Azure VM then update it to the local metadata endpoint
    if [ "$MSI_ENDPOINT" = "" ]; then
        # check if we are running in an Azure VM
        compute=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-12-01" | jq '.compute')
        if [ "$compute" != "" ]; then
            MSI_ENDPOINT="http://169.254.169.254/metadata/identity/oauth2/token"
        fi
    fi

    echo "MSI_ENDPOINT=$MSI_ENDPOINT"
    if [ "$MSI_ENDPOINT" != "" ]; then
        token=$(curl -s -H Metadata:true "$MSI_ENDPOINT?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" | jq -r '.access_token')
        echo $token
        read $1 <<< $(curl -s -H "Authorization: Bearer $token" https://$vault_name.vault.azure.net/secrets/$key_name?api-version=2016-10-01 | jq -r '.value')
    else        
        read $1 <<< $(az keyvault secret show --name $key_name --vault-name $vault_name | jq -r '.value')
    fi

    echo "read_secret: $1=${!1}"
    if [ $? != 0 ]; then
        echo "ERROR: Failed to read $2 from key vault $vault_name $key_name"
        exit 1
    fi
}

function azure_login {
    # do we use the service principal?
    read_value subscription_id ".subscription_id"
    current_subscription="$(az account show | jq -r .id)"
    if [ "$current_subscription" != "$subscription_id" ]; then

        if [[ "$sp_client_id" = "" ]]; then
            read_value sp_client_id ".service_principal.client_id"
            read_secret sp_client_secret ".service_principal.client_secret"
            read_value sp_tenant_id ".service_principal.tenant_id"
        fi

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
    read_value batch_account ".batch.account_name"
    read_value batch_rg ".batch.resource_group"

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

function create_read_sas_key {
    rg=$1
    storagename=$2
    container=$3

    key=$(az storage account keys list \
        --resource-group $rg \
        --account-name $storagename \
        --query "[0].value" \
        --output tsv)

    container_exists="$(az storage container exists \
        --account-name $storagename \
        --account-key "$key" \
        --name $container --output tsv)"
    if [ "$container_exists" == "False" ]; then
        echo "Creating container ($container)..."
        az storage container create \
            --account-name $storagename \
            --account-key "$key" \
            --name $container \
            --output table
    else
        echo "Container ($container) already exists."
    fi

    echo "Adding container policy for read access"
    az storage container policy create \
        --container-name $container \
        --name read \
        --permissions r \
        --account-key "$key" \
        --account-name $storagename \
        --start $(date --utc -d "-2 hours" +%Y-%m-%dT%H:%M:%SZ) \
        --expiry $(date --utc -d "+1 year" +%Y-%m-%dT%H:%M:%SZ) \
        --output table

    SAS_KEY=$(az storage container generate-sas \
        --policy-name read \
        --name $container \
        --account-name $storagename \
        --account-key $key \
        --output tsv)
    key=""
}

function create_rw_sas_key()
{
    rg=$1
    storagename=$2
    container=$3

    key=$(az storage account keys list \
        --resource-group $rg \
        --account-name $storagename \
        --query "[0].value" \
        --output tsv)

    container_exists="$(az storage container exists \
        --account-name $storagename \
        --account-key "$key" \
        --name $container --output tsv)"
    if [ "$container_exists" == "False" ]; then
        echo "Creating container ($container)..."
        az storage container create \
            --account-name $storagename \
            --account-key "$key" \
            --name $container \
            --output table
    else
        echo "Container ($container) already exists."
    fi

    echo "Adding container policy for read write access"
    az storage container policy create \
        --container-name $container \
        --name rw \
        --permissions rw \
        --account-key "$key" \
        --account-name $storagename \
        --start $(date --utc -d "-2 hours" +%Y-%m-%dT%H:%M:%SZ) \
        --expiry $(date --utc -d "+1 year" +%Y-%m-%dT%H:%M:%SZ) \
        --output table

    SAS_KEY=$(az storage container generate-sas \
        --policy-name rw \
        --name $container \
        --account-name $storagename \
        --account-key $key \
        --output tsv)

}