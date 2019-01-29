#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

TIMESTAMP=$(date +"%Y%m%d%H%M")
LOGDIR=log-$TIMESTAMP
mkdir $LOGDIR

config_file="config.json"
debug_mode=0

function usage {
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -c config.json -d"
    echo "    -c: config file to use"
    echo "    -d: debug mode (leave log files)"
    echo "    -h: help"
    echo ""
}

while getopts "c: d h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        d)
        debug_mode=1
            ;;
        h)
        usage
        exit 0
            ;;
    esac
done

if [ ! -e "$config_file" ]; then
    cp template-config.json $config_file
fi

function is_not_set {
    val="$(jq -r $1 $config_file)"
    [ "$val" = "NOT-SET" -o "$val" = "" ]
}

function create_storage_account {
    local sa=$1
    local rg=$2
    local loc=$3

    exists=$(az storage account list -g $rg -o table | grep $sa)

    if [ "$exists" = "" ]; then
        echo "Creating storage account ($sa)"
        az storage account create \
            --name $sa \
            --sku Standard_LRS \
            --location $loc \
            --resource-group $rg 
        if [ $? != 0 ]; then
            echo "ERROR: Failed to storage account"
            exit 1
        fi
    fi
}

jqstr="."

function update_config_file {
    tag=$1

    if [ "$jqstr" != "." ]; then
        if [ "$debug_mode" -eq "1" ]; then
            echo "Applying changes: $jqstr"
        fi

        mv $config_file $LOGDIR/${config_file%.*}-${TIMESTAMP}-${tag}.json
        jq "$jqstr" $LOGDIR/${config_file%.*}-${TIMESTAMP}-${tag}.json > ${config_file}

        jqstr="."
    else
        if [ "$debug_mode" -eq "1" ]; then
            echo "No changes to apply."
        fi
    fi
}

read_value subscription_id .subscription_id
if is_not_set .subscription_id; then
    az account list > $LOGDIR/az_account_list.log
    jq -r  '.[] | "\(.id) (\(.name))"' $LOGDIR/az_account_list.log
    echo -n "Enter the subscription id to use: "
    read subscription_id
    jqstr+="|.subscription_id=\"$subscription_id\""

    update_config_file subscription
fi

echo "Setting to correct subscription id"
az account set --subscription $subscription_id > $LOGDIR/az_account_set.log

read_value location .location
if is_not_set .location; then
    echo ""
    echo "** Note: If you intend to use CycleCloud, it runs in an Azure Container Instance"
    echo "   and the only supported regions are: "
    echo "   eastus, westus, westus2, westeurope, northeurope, and southeastasia"

    echo -n "Enter location (for anything new to be created in): "
    read location
    jqstr+="|.location=\"$location\""

    update_config_file location
fi

read_value resource_group .resource_group
if is_not_set .resource_group; then
    echo -n "Enter resource group (for anything new to be created in): "
    read resource_group

    group_exists=$(az group exists -n $resource_group)
    if [ "$group_exists" = "false" ];then
        az group create -n $resource_group --location "$location"
    fi

    jqstr+="|.resource_group=\"$resource_group\""

    update_config_file resource_group
fi
echo ""
echo "** Note: Azure Key Vault is used to store secrets"
echo "   If you sepcify an existing Vault, this script will add secrets in it"
echo "   If the Vault doesn't exists, it will create one for you"

echo -n "Enter the Key Vault Name: "
read vault_name
vault=$(az keyvault show --name $vault_name --output tsv)
if [ "$vault" = "" ]; then
    az keyvault create --name $vault_name --resource_group $resource_group
fi

if is_not_set .service_principal.name; then
    echo -n "Enter the service principal name to create: "
    read sp_name
    az ad sp create-for-rbac --name $sp_name > $LOGDIR/az_ad_sp_create-for-rbac.log

    secret=$(jq -r '.password' $LOGDIR/az_ad_sp_create-for-rbac.log)
    az keyvault secret set --vault-name $vault_name --name "spn-secret" --value $secret
    
    jqstr+="|.service_principal.name=\"$sp_name\""
    jqstr+="|.service_principal.tenant_id=\"$(jq -r '.tenant' $LOGDIR/az_ad_sp_create-for-rbac.log)\""
    jqstr+="|.service_principal.client_id=\"$(jq -r '.appId' $LOGDIR/az_ad_sp_create-for-rbac.log)\""
    jqstr+="|.service_principal.client_secret=\"$vault_name.spn-secret\""

    update_config_file service_principal
fi

if is_not_set .packer.executable; then
    packer_version=1.3.2
    if [[ $(uname -r) =~ Microsoft$ ]]; then
        echo "Downloading Windows version of Packer"
        packerzip=https://releases.hashicorp.com/packer/$packer_version/packer_${packer_version}_windows_amd64.zip
        jqstr+="|.packer.executable=\"bin/packer.exe\""
    else
        echo "Download Linux version of Packer"
        packerzip=https://releases.hashicorp.com/packer/$packer_version/packer_${packer_version}_linux_amd64.zip
        jqstr+="|.packer.executable=\"bin/packer\""
    fi
    
    mkdir -p bin && cd bin \
        && wget $packerzip -O packer.zip \
        && unzip packer.zip && rm -f packer.zip \
        && cd -

    update_config_file packer
fi


if is_not_set .images.name; then
    echo "Select image/SKU to use:"
    echo " - centos74    [ H16r   ]"
    echo " - centos75_hb [ HB60rs ]"
    echo " - centos75_hc [ HC44rs ]"
    echo " - ubuntu1604  [ NC24r  ]"
    read image
    valid_image=1
    case "$image" in
        centos75_hb)
            packer_base_image="baseimage-centos.sh"
            images_name="centos75"
            images_publisher="OpenLogic"
            images_offer="CentOS"
            images_sku="7.5"
            images_vm_size="Standard_HB60rs"
            images_nodeAgentSKUId="batch.node.centos 7"
            ;;
        centos75_hc)
            packer_base_image="baseimage-centos.sh"
            images_name="centos75"
            images_publisher="OpenLogic"
            images_offer="CentOS"
            images_sku="7.5"
            images_vm_size="Standard_HC44rs"
            images_nodeAgentSKUId="batch.node.centos 7"
            ;;
        centos74)
            packer_base_image="baseimage-centos.sh"
            images_name="centos74"
            images_publisher="OpenLogic"
            images_offer="CentOS-HPC"
            images_sku="7.4"
            images_vm_size="STANDARD_H16R"
            images_nodeAgentSKUId="batch.node.centos 7"
            ;;
        ubuntu1604)
            packer_base_image="baseimage-ubuntu.sh"
            images_name="ubuntu1604"
            images_publisher="Canonical"
            images_offer="UbuntuServer"
            images_sku="16.04-LTS"
            images_vm_size="STANDARD_NC24r"
            images_nodeAgentSKUId="batch.node.ubuntu 16.04"
            ;;
        *)
            echo "Unrecognised option ($image), skipping."
            valid_image=0
    esac
    if [ "$valid_image" = "1" ]; then
        jqstr+="|.packer.base_image=\"$packer_base_image\""
        jqstr+="|.images.name=\"$images_name\""
        jqstr+="|.images.publisher=\"$images_publisher\""
        jqstr+="|.images.offer=\"$images_offer\""
        jqstr+="|.images.sku=\"$images_sku\""
        jqstr+="|.images.vm_size=\"$images_vm_size\""
        jqstr+="|.images.nodeAgentSKUId=\"$images_nodeAgentSKUId\""
    fi

    update_config_file image_and_sku
fi

if is_not_set .images.storage_account; then
    echo -n "Enter the storage account to be created for images: "
    read sa
    create_storage_account $sa $resource_group $location
    jqstr+="|.images.storage_account=\"$sa\""
    jqstr+="|.images.resource_group=\"$resource_group\""

    update_config_file images_storage
fi

read_value cluster_type .cluster_type
if is_not_set .cluster_type; then
    echo -n "Select \"batch\" or \"cyclecloud\": "
    read cluster_type
    jqstr+="|.cluster_type=\"$cluster_type\""

    update_config_file cluster_type
fi

if [ "$cluster_type" = "batch" ]; then

    # check batch account and set if necessary
    read_value batch_storage_account .batch.storage_account
    if is_not_set .batch.storage_account; then
        echo -n "Enter batch storage account name: "
        read batch_storage_account
        create_storage_account $batch_storage_account $resource_group $location
        jqstr+="|.batch.storage_account=\"$batch_storage_account\""

        update_config_file batch_storage
    fi

    if is_not_set .batch.account_name; then
        echo -n "Enter batch account name: "
        read batch_account_name
        az batch account create \
            --location $location \
            --name $batch_account_name \
            --resource-group $resource_group \
            --storage-account $batch_storage_account \
            > $LOGDIR/az_batch_account_create.log
        if [ $? != 0 ]; then
            echo "ERROR: Failed to create batch account"
            exit 1
        fi

        jqstr+="|.batch.resource_group=\"$resource_group\""
        jqstr+="|.batch.account_name=\"$batch_account_name\""

        update_config_file batch_account
    fi
    

elif [ "$cluster_type" = "cyclecloud" ]; then
    if is_not_set .cyclecloud.resource_group; then
        echo -n "Enter resource group to run AzureCycleCloud and clusters in: "
        read cyclecloud_resource_group
        jqstr+="|.cyclecloud.resource_group=\"$cyclecloud_resource_group\""
    fi

    if is_not_set .cyclecloud.admin_user; then
        admin_user=$(whoami)
        jqstr+="|.cyclecloud.admin_user=\"$admin_user\""
    fi

    if is_not_set .cyclecloud.admin_password; then
        read_value admin_password .service_principal.client_secret
        jqstr+="|.cyclecloud.admin_password=\"$admin_password\""
    fi

    update_config_file cyclecloud
else
    echo "Unknown cluster type ($cluster_type)."
fi

# look at infrastructure
if is_not_set .infrastructure.network.vnet; then
    echo "Infrastrure (network, NFS) node defined.  Setting up infrastructure".
    rsaPublicKey=$(cat $HOME/.ssh/id_rsa.pub)
    if [ "$rsaPublicKey" == "" ]; then    
        echo "No public ssh key found (in ~/.ssh/id_rsa.pub)."
        echo "Run ssh-key with all default options and re-run this script."
        exit 1
    fi

    echo -n "Enter VNET name to set up infrastructure in: "
    read vnetname
    jqstr+="|.infrastructure.network.vnet=\"$vnetname\"" 

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

    echo "Deploying VNET $vnetname and NFS Server in resource group $resource_group "
    az group deployment create \
        --resource-group "$resource_group" \
        --template-file infrastructure/deploy_nfs.json \
        --parameters "$parameters" | tee $LOGDIR/deploy_nfs.log

    nfsnode=$(jq -r '.properties.outputs.nfsname.value' $LOGDIR/deploy_nfs.log)
    echo "NFS server can be reach at $nfsnode"
    echo "uploading setup script"
    # remove old entries for the nfs nodes in case of several retries to avoid ssh failures
    ssh-keygen -f "~/.ssh/known_hosts" -R ${nfsnode}
    scp -o StrictHostKeyChecking=no infrastructure/setup_nfs.sh hpcadmin@${nfsnode}:setup_nfs.sh
    echo "Configuring NFS disk and mount point"
    ssh -o StrictHostKeyChecking=no hpcadmin@${nfsnode} "sudo bash setup_nfs.sh"

    jqstr+="|.infrastructure.nfsserver=\"10.0.2.4\""
    jqstr+="|.infrastructure.licserver=\"10.1.0.4\""
    jqstr+="|.infrastructure.network.resource_group=\"$resource_group\""
    jqstr+="|.infrastructure.network.vnet=\"$vnetname\""
    jqstr+="|.infrastructure.network.subnet=\"compute\""
    jqstr+="|.infrastructure.network.admin_subnet=\"admin\""

    update_config_file infrastructure
fi

# analytics
if is_not_set .infrastructure.analytics.workspace; then
    echo "Warning: Log analytics not set up."
    echo "         To use this feature, set up an account and set workspace/key."
fi

# app storage
if is_not_set .appstorage.storage_account; then
    echo "Warning: You do not have anything set for app storage."
    echo "         You must either create a copy installers/test data."
    echo "         Alternatively obtain account details and SAS key existing one."
fi

if is_not_set .results.storage_account; then
    echo -n "Enter the storage account to be created for results: "
    read sa
    create_storage_account $sa $resource_group $location
    jqstr+="|.results.storage_account=\"$sa\""
    jqstr+="|.results.resource_group=\"$resource_group\""
    
    update_config_file results_storage
fi

if [ "$debug_mode" -eq "0" ]; then
    rm -rf $LOGDIR
fi
