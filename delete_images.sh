#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

config_file="config.json"
app=

function usage {
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

read_value images_rg ".images.resource_group"

azure_login
batch_login

get_pool_id $app
pool_id=$POOL_ID

pool_image=$(az batch pool show \
                --pool-id $pool_id \
                --query "[virtualMachineConfiguration.imageReference.virtualMachineImageId]" \
                --output tsv)
echo "pool image id : $pool_image"


echo "get all images for $pool_id"
image_list=$(az image list \
    --resource-group $images_rg \
    --query "[?contains(name,'$pool_id-')].[id]" \
    --output tsv \
    | sort)

for image in $image_list; do
    echo "image_id: $image"
    blobUri=$(az image show --ids $image --query "[storageProfile.osDisk.blobUri]" --output tsv)
    if [ "$image" != "$pool_image" ]; then
        echo "Deleting blob $blobUri"
        if [ "$blobUri" != "None" ]; then
            [[ "$blobUri" =~ ^https://([^.]+).blob.core.windows.net/([^/]+)/(.*)$ ]]
            az storage blob delete -c ${BASH_REMATCH[2]} -n ${BASH_REMATCH[3]} --account-name ${BASH_REMATCH[1]}
        fi

        echo "Deleting image $image"
        az image delete --ids $image        
    fi
done
