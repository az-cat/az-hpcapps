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
get_pool_id $app
pool_id=$POOL_ID

az image list \
    --resource-group $images_rg \
    --query "[?contains(name,'$pool_id-')].[name,id]" \
    --output tsv \
    | sort

