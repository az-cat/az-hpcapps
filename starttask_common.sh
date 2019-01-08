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

# check if running on HB
vmSize=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-12-01" | jq -r '.compute.vmSize')
if [ "${vmSize,,}" = "standard_hb60rs" ]; then
    ifconfig ib0 $(sed '/rdmaIPv4Address=/!d;s/.*rdmaIPv4Address="\([0-9.]*\)".*/\1/' /var/lib/waagent/SharedConfig.xml)/16
fi
