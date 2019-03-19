#!/bin/bash

config_file=$1
vnetname=$2
resource_group=$3

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me config.json VNETname ResourceGroup"
    echo ""
}


if [ ! -f $config_file ] || [ -z $vnetname ] || [ -z $resource_group ];then
    usage
    exit 1
fi

rsaPublicKey=$(cat ~/.ssh/id_rsa.pub)

if [ "$rsaPublicKey" == "" ]; then
    echo "No public ssh key found (in ~/.ssh/id_rsa.pub)."
    echo "Run ssh-key with all default options and re-run this script."
    exit 1
fi

parameters=$(cat << EOF
{
    "vnetName": {
        "value": "$vnetname"
    },
    "rsaPublicKey": {
        "value": "$rsaPublicKey"
    }
}
EOF
)

# deploy NFS server
echo "Deploying VNET $vnetname and NFS Server in resource group $resource_group "
az group deployment create \
    --resource-group "$resource_group" \
    --template-file deploy_nfs.json \
    --parameters "$parameters" | tee deploy_nfs.log

nfsnode=$(jq -r '.properties.outputs.nfsname.value' deploy_nfs.log)
echo "NFS server can be reach at $nfsnode"
echo "uploading setup script"
# remove old entries for the nfs nodes in case of several retries to avoid ssh failures
ssh-keygen -f "~/.ssh/known_hosts" -R ${nfsnode}
scp -o StrictHostKeyChecking=no setup_nfs.sh hpcadmin@${nfsnode}:setup_nfs.sh
echo "Configuring NFS disk and mount point"
ssh -o StrictHostKeyChecking=no hpcadmin@${nfsnode} "sudo bash setup_nfs.sh"

jqstr="."
jqstr+="|.infrastructure.nfsserver=\"10.0.2.4\""
jqstr+="|.infrastructure.licserver=\"10.1.0.4\""
jqstr+="|.infrastructure.network.resource_group=\"$resource_group\""
jqstr+="|.infrastructure.network.vnet=\"$vnetname\""
jqstr+="|.infrastructure.network.subnet=\"compute\""
jqstr+="|.infrastructure.network.admin_subnet=\"admin\""

TIMESTAMP=$(date +"%Y%m%d%H%M")
mv $config_file ${config_file%.*}-${TIMESTAMP}.json
jq "$jqstr" ${config_file%.*}-${TIMESTAMP}.json > ${config_file}
