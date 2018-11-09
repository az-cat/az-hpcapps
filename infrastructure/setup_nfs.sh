#! /bin/bash
set -x

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

# Disable requiretty to allow run sudo within scripts
sed -i -e 's/Defaults    requiretty.*/ #Defaults    requiretty/g' /etc/sudoers

yum -y install epel-release
yum -y install nfs-utils nfs-utils-lib


# Shares
NFS_DATA=/data

# Partitions all data disks attached to the VM 
#
setup_data_disks()
{
    mountPoint="$1"
    filesystem="$2"
    devices="$3"
    raidDevice="$4"
    createdPartitions=""

    # Loop through and partition disks until not found
    for disk in $devices; do
        fdisk -l /dev/$disk || break
        fdisk /dev/$disk << EOF
n
p
1


p
w
EOF
        createdPartitions="$createdPartitions /dev/${disk}1"
    done
    
    # Create RAID-0 volume
    if [ -n "$createdPartitions" ]; then
        devices=`echo $createdPartitions | wc -w`
        mdadm --create /dev/$raidDevice --level 0 --raid-devices $devices $createdPartitions
        
        sleep 10
        
        mdadm /dev/$raidDevice

        if [ "$filesystem" == "xfs" ]; then
            mkfs -t $filesystem /dev/$raidDevice
            echo "/dev/$raidDevice $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
        else
            mkfs.ext4 -i 2048 -I 512 -J size=400 -Odir_index,filetype /dev/$raidDevice
            sleep 5
            tune2fs -o user_xattr /dev/$raidDevice
            echo "/dev/$raidDevice $mountPoint $filesystem noatime,nodiratime,nobarrier,nofail 0 2" >> /etc/fstab
        fi
        
        sleep 10
        
        mount /dev/$raidDevice
    fi
}

setup_single_disk()
{
    mountPoint="$1"
    filesystem="$2"
    device="$3"

    fdisk -l /dev/$device || break
    fdisk /dev/$device << EOF
n
p
1


p
w
EOF
    
    if [ "$filesystem" == "xfs" ]; then
        mkfs -t $filesystem /dev/$device
        echo "/dev/$device $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,nofail 0 2" >> /etc/fstab
    else
        mkfs.ext4 -F -i 2048 -I 512 -J size=400 -Odir_index,filetype /dev/$device
        sleep 5
        tune2fs -o user_xattr /dev/$device
        echo "/dev/$device $mountPoint $filesystem noatime,nodiratime,nobarrier,nofail 0 2" >> /etc/fstab
    fi
        
    sleep 10
        
    mount /dev/$device $mountPoint
}

setup_disks()
{      
    # Dump the current disk config for debugging
    fdisk -l
    
    # Dump the scsi config
    lsscsi
    
    # Get the root/OS disk so we know which device it uses and can ignore it later
    rootDevice=`mount | grep "on / type" | awk '{print $1}' | sed 's/[0-9]//g'`
    
    # Get the TMP disk so we know which device and can ignore it later
    tmpDevice=`mount | grep "on /mnt/resource type" | awk '{print $1}' | sed 's/[0-9]//g'`

    # Get the data disk sizes from fdisk, we ignore the disks above
    dataDiskSize=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | awk '{print $3}' | sort -n -r | tail -1`

	# Compute number of disks
	nbDisks=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | wc -l`
	echo "nbDisks=$nbDisks"
	
	dataDevices="`fdisk -l | grep '^Disk /dev/' | grep $dataDiskSize | awk '{print $2}' | awk -F: '{print $1}' | sort | head -$nbDisks | tr '\n' ' ' | sed 's|/dev/||g'`"

	mkdir -p $NFS_DATA
    chmod 777 $NFS_DATA

    if [ $nbDisks=="1" ]; then
	    setup_single_disk $NFS_DATA "ext4" "$dataDevices" 
	else
	    setup_data_disks $NFS_DATA "xfs" "$dataDevices" "md10"
    fi

	echo "$NFS_DATA    *(rw,async)" >> /etc/exports
	exportfs
	exportfs -a
	exportfs 
}


mkdir -p /var/local
SETUP_MARKER=/var/local/install_nfs.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl enable nfs

systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
systemctl start nfs

setup_disks

systemctl restart nfs-server

chmod 777 $NFS_DATA/.

# Create marker file so we know we're configured
touch $SETUP_MARKER

exit 0

