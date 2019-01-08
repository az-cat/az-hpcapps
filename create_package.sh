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
    echo "    -a: application"
    echo "    -d: package directory - all files included in this directory will be added to the application package"
    echo "    -h: help"
    echo ""
}

while getopts "a: d: c: h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        a)
        app=$OPTARG
            ;;
        d)
        package_dir=$OPTARG
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
echo "package_dir: $package_dir"

pushd $package_dir
rm -f $app.zip
zip -r $app.zip $app
popd

read_value batch_account ".batch.account_name"
read_value batch_rg ".batch.resource_group"

az batch application create \
    --resource-group $batch_rg \
    --name $batch_account \
    --application-id $app \
    --display-name "$app application package"

az batch application package create \
    --resource-group $batch_rg \
    --name $batch_account \
    --application-id $app \
    --package-file $package_dir/${app}.zip \
    --version "latest"

az batch application set \
    --resource-group $batch_rg \
    --name $batch_account \
    --application-id $app \
    --default-version "latest"

