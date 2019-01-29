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
read_secret sp_client_secret ".service_principal.client_secret"
read_value sp_tenant_id ".service_principal.tenant_id"
read_value images_rg ".images.resource_group"
read_value images_storage ".images.storage_account"
read_value image_name ".images.name"
read_value image_publisher ".images.publisher"
read_value image_offer ".images.offer"
read_value image_sku ".images.sku"
read_value vm_size ".images.vm_size"
read_value packer_exe ".packer.executable"
read_value base_image ".packer.base_image"

timestamp=$(date +%Y%m%d-%H%M%S)

azure_login

# create resource group for images (if not already there)
echo "create resource group for images (if not already there)"
exists=$(az group show --name $images_rg --out tsv)
if [ "$exists" == "" ]; then
    echo "Creating resource group for images ($images_rg)"
    az group create --name $images_rg --location $location --output tsv
    if [ $? != 0 ]; then
        echo "ERROR: Failed to create resource group"
        exit 1
    fi
fi

# create storage account for images (if not already there)
echo "create storage account for images (if not already there)"
exists=$( \
    az storage account show \
        --name $images_storage \
        --resource-group $images_rg \
        --output tsv \
)
if [ "$exists" == "" ]; then
    echo "Creating storage account for images ($images_storage)"
    az storage account create \
        --name $images_storage \
        --sku Standard_LRS \
        --location $location \
        --resource-group $images_rg \
        --access-tier Hot \
        --output table
    if [ $? != 0 ]; then
        echo "ERROR: Failed to storage account"
        exit 1
    fi
fi

#
# prepare the install script
#
echo "prepare the install script"
read_value app_storage_name ".appstorage.storage_account"
read_value app_container ".appstorage.app_container"
read_value hpc_apps_saskey ".appstorage.app_saskey"
read_value licserver ".infrastructure.licserver"
read_value app_storage_rg ".appstorage.resource_group"

if [ "$hpc_apps_saskey" == "" ]; then
    # Create input data SAS KEY
    create_read_sas_key $app_storage_rg $app_storage_name $app_container
    hpc_apps_saskey=$SAS_KEY
fi

echo "HPC apps SAS Key = $hpc_apps_saskey"
hpc_apps_storage_endpoint="https://$app_storage_name.blob.core.windows.net/$app_container"
echo "HPC apps storage endpoint is $hpc_apps_storage_endpoint"
replace="s,#HPC_APPS_STORAGE_ENDPOINT#,$hpc_apps_storage_endpoint,g"
replace+=";s,#HPC_APPS_SASKEY#,$hpc_apps_saskey,g"
replace+=";s,#LICSERVER#,$licserver,g"
# escape string for sed
echo "Replace string: \"$replace\""
replace=$(sed "s/\&/\\\&/g" <<< "$replace")
app_install_script=install_${app}_${timestamp}.sh
sed "$replace" $DIR/apps/$app/install_$app.sh > $app_install_script

get_pool_id $app
app_img_name=$POOL_ID-$timestamp

# update storage type based on VM size
storage_account_type="Premium_LRS"
vm_size=${vm_size,,}
case "$vm_size" in
    *_h16*) 
        storage_account_type="Standard_LRS"
        ;;
    *_f72*)
        storage_account_type="Standard_LRS"
        ;;
esac
echo "storage_account_type=$storage_account_type"

case $storage_account_type in
    "Premium_LRS")
        packer_build_template=$DIR/packer/build.json
        image_name=$app_img_name
        ;;
    "Standard_LRS")
        packer_build_template=$DIR/packer/build_vhd.json
        ;;
esac
echo "packer_build_template=$packer_build_template"

# run packer
PACKER_LOG=1
packer_log=packer-output-$timestamp.log
version=$($packer_exe --version)

echo "running on packer version $version"

if [ "$version" == "1.3.3" ]; then
    echo "version 1.3.3 is not supported and have a bug, use 1.3.2 or 1.3.4+"
    exit 1
fi

$packer_exe build -timestamp-ui \
    -var subscription_id=$subscription_id \
    -var location=$location \
    -var resource_group=$images_rg \
    -var tenant_id=$sp_tenant_id \
    -var client_id=$sp_client_id \
    -var client_secret=$sp_client_secret \
    -var image_name=$image_name \
    -var image_publisher=$image_publisher \
    -var image_offer=$image_offer \
    -var image_sku=$image_sku \
    -var vm_size=$vm_size \
    -var storage_account_type=$storage_account_type \
    -var appinstaller=$app_install_script \
    -var baseimage=packer/$base_image \
    -var app_name=$app \
    -var storage_account=$images_storage \
    $packer_build_template \
    | tee $packer_log

if [ $? != 0 ]; then
    echo "ERROR: Bad exit status for packer"
    exit 1
fi

rm $app_install_script

errors=$(grep "ERROR" $packer_log)
echo "Testing errors : $errors"
if [ "$errors" != "" ]; then
    echo "errors while creating the image"
    echo "*******************************"
    echo $errors
    echo "*******************************"

    echo "Deleting image $app_img_name"
    az image delete --name $app_img_name --resource-group $images_rg
    exit 1
fi

if [ "$storage_account_type" == "Standard_LRS" ]; then
    # get vhd source from the packer output
    vhd_source="$(grep -Po '(?<=OSDiskUri\: )[^$]*' $packer_log)"

    echo "Creating image: $app_img_name (using $vhd_source)"
    az image create \
        --name $app_img_name \
        --resource-group $images_rg \
        --source $vhd_source \
        --os-type Linux \
        --location $location \
        --output table

    if [ $? != 0 ]; then
        echo "ERROR: Failed to create image"
        exit 1
    fi
fi

rm $packer_log

