#!/bin/bash
NFS_SERVER="#NFS_SERVER#"
NFS_MOUNT="#NFS_MOUNT#"
BEEGFS_MGMT="#BEEGFS_MGMT#"
BEEGFS_MOUNT="#BEEGFS_MOUNT#"

mkdir /data
echo "$NFS_SERVER:${NFS_MOUNT}    /data   nfs defaults,proto=tcp,nfsvers=3,rsize=65536,wsize=65536,noatime,soft,timeo=30 0 0" >> /etc/fstab
chmod 777 /data

mount -a

if [ "$BEEGFS_MGMT" != "" ]; then
	sed -i 's/^sysMgmtdHost.*/sysMgmtdHost = '$BEEGFS_MGMT'/g' /etc/beegfs/beegfs-client.conf
	echo "$BEEGFS_MOUNT /etc/beegfs/beegfs-client.conf" > /etc/beegfs/beegfs-mounts.conf

	systemctl enable beegfs-helperd.service
	systemctl enable beegfs-client.service
	systemctl start beegfs-helperd.service
	systemctl start beegfs-client.service
else
	systemctl disable beegfs-helperd.service
	systemctl disable beegfs-client.service
fi

# Get VM Size
VMSIZE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2018-04-02" | jq -r '.compute.vmSize')
VMSIZE=${VMSIZE,,}
echo "vmSize is $VMSIZE"
ifconfig

if [ "$VMSIZE" == "standard_hb60rs" ] || [ "$VMSIZE" == "standard_hc44rs" ]
then
    # check if IB is up
    status=$(ibv_devinfo | grep "state:")
    if [ $? != 0 ]; then
        echo "ERROR: Failed to get IB device"
        exit 1
    fi

    status=$(echo $status | cut -d' ' -f 2)
    if [ "$status" = "PORT_DOWN" ]; then
        echo "ERROR: IB is down"
        ibv_devinfo 
        exit 1
    fi
fi

# end of starttask_common
