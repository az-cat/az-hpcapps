#!/bin/bash

image_rg_name=$1
image_name=$2
location=$3
vm_name=vmtest
vmsize=standard_h16r

# create temporary RG
test_rg=azcat_$(date "+%Y%m%d-%H%M%S")
az group create --name $test_rg --location $location

rsaPublicKey=$(cat ~/.ssh/id_rsa.pub)
image_id=$(az image list -g ${image_rg_name} --query "[?name=='${image_name}']" | jq -r '.[0].id')
az vm create -g $test_rg -n $vm_name --image $image_id --size $vmsize --ssh-key-value "$rsaPublicKey" | tee azcreate.json

