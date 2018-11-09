#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

config_file="config.json"
app=
vmcount=1

function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -c config.json -a APPNAME "
    echo "    -c: config file to use"
    echo "    -a: application (application list)"
    echo "    -n: nb VMs"
    echo "    -h: help"
    echo ""
}

while getopts "a: c: n: h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        a)
        app=$OPTARG
            ;;
        n)
        vmcount=$OPTARG
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
echo "vmcount: $vmcount"

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
}

read_value subscription_id ".subscription_id"
read_value location ".location"
read_value sp_client_id ".service_principal.client_id"
read_value sp_client_secret ".service_principal.client_secret"
read_value sp_tenant_id ".service_principal.tenant_id"
read_value vnet_rg ".infrastructure.network.resource_group"
read_value vnet ".infrastructure.network.vnet"
read_value subnet ".infrastructure.network.subnet"
read_value vmsize ".images.vm_size"
read_value image_rg ".images.resource_group"
read_value batch_rg ".batch.resource_group"
read_value storage_name ".batch.storage_account"
read_value container_name ".batch.storage_container"

echo "Setting subscription ($subscription_id)"
az account set --subscription $subscription_id
if [ $? != 0 ]; then
    echo "ERROR: Failed to set the subscription"
    exit 1
fi

#
# Upload compute node script
#
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

# upload file
echo "Uploading compute node script"
compute_node_script_name="cn-setup.sh"

az storage blob upload \
    --container-name $container_name \
    --account-name $storage_name \
    --account-key $storage_key \
    --file $compute_node_script_name \
    --name "${app}/$compute_node_script_name" \
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

storage_endpoint=$(az storage account show \
    --resource-group $batch_rg \
    --name $storage_name \
    --query "primaryEndpoints.blob" \
    --output tsv)
echo "Storage endpoint is $storage_endpoint"

# generate start task source string
compute_node_source="${storage_endpoint}${container_name}/${app}/$compute_node_script_name?$saskey"
echo "Compute Node source: $compute_node_source"


image_id=$(az image list \
    --resource-group $image_rg \
    --query "[?contains(name,'$app-')].[name,id]" \
    --output tsv \
    | sort | tail -n1 | cut -d$'\t' -f2)
echo "Image Id: $image_id"

rsaPublicKey=$(cat ~/.ssh/hpcuser.pub)

parameters=$(cat << EOF
{
    "vmSku" : {
        "value": "$vmsize"
    },
    "vmssName": {
        "value": "$app"
    },
    "instanceCount": {
        "value": $vmcount 
    },
    "vnetName": {
        "value": "$vnet"
    },
    "subnetName": {
        "value": "$subnet"
    },
    "fastNetwork": {
        "value": true
    },
    "imageId": {
        "value": "$image_id"
    },
    "adminUser": {
        "value": "hpcuser"
    },
    "rsaPublicKey": {
        "value": "$rsaPublicKey"
    },
    "cnscript": {
        "value": "$compute_node_source"
    }
}
EOF
)

echo $parameters

# deploy VMSS 
echo "Build VMSS"
az group deployment create \
    --resource-group "$vnet_rg" \
    --template-file vmss.json \
    --parameters "$parameters" | tee deploy_vmss.log

echo "Retrieve the node list"
jq -r '.[].osProfile.computerName' <<< $(az vmss list-instances --resource-group "$vnet_rg" --name "$app") > "$app.host"

