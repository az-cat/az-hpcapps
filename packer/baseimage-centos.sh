#!/bin/bash
set -e
set -o pipefail

# temporarily stop yum service conflicts if applicable
set +e
systemctl stop yum.cron
systemctl stop packagekit
set -e

# wait for wala to finish downloading driver updates
sleep 60

# temporarily stop waagent
systemctl stop waagent.service

# cleanup any aborted yum transactions
yum-complete-transaction --cleanup-only

# set limits for HPC apps
cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               hard    nofile          65535
*               soft    nofile          65535
EOF

# install based packages
yum install -y epel-release
if [ $? != 0 ]; then
    echo "ERROR: unable to install epel-release"
    exit 1
fi
yum install -y nfs-utils jq htop axel
if [ $? != 0 ]; then
    echo "ERROR: unable to install nfs-utils jq htop"
    exit 1
fi

# turn off GSS proxy
sed -i 's/GSS_USE_PROXY="yes"/GSS_USE_PROXY="no"/g' /etc/sysconfig/nfs

# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

setenforce 0
# Disable SELinux
cat << EOF > /etc/selinux/config
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#       enforcing - SELinux security policy is enforced.
#       permissive - SELinux prints warnings instead of enforcing.
#       disabled - No SELinux policy is loaded.
SELINUX=disabled
# SELINUXTYPE= can take one of these two values:
#       targeted - Targeted processes are protected,
#       mls - Multi Level Security protection.
SELINUXTYPE=targeted
EOF

# optimize
systemctl disable cpupower
systemctl disable firewalld

install_beegfs_client()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing BeeGFS Client                    *" 
    echo "*                                                       *"
    echo "*********************************************************"
	wget -O /etc/yum.repos.d/beegfs-rhel7.repo https://www.beegfs.io/release/beegfs_7/dists/beegfs-rhel7.repo
	rpm --import https://www.beegfs.io/release/latest-stable/gpg/RPM-GPG-KEY-beegfs

	yum install -y beegfs-client beegfs-helperd beegfs-utils gcc gcc-c++
    set +e
	yum install -y "kernel-devel-uname-r == $(uname -r)"
    set -e

	sed -i 's/^sysMgmtdHost.*/sysMgmtdHost = localhost/g' /etc/beegfs/beegfs-client.conf
	echo "/beegfs /etc/beegfs/beegfs-client.conf" > /etc/beegfs/beegfs-mounts.conf
	
	systemctl daemon-reload
	systemctl enable beegfs-helperd.service
	systemctl enable beegfs-client.service
}

setup_intel_mpi_2018()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing Intel MPI & Tools                *" 
    echo "*                                                       *"
    echo "*********************************************************"
    VERSION=2018.4.274
    IMPI_VERSION=l_mpi_${VERSION}
    wget -q http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/13651/${IMPI_VERSION}.tgz

    tar xvf ${IMPI_VERSION}.tgz

    replace="s,ACCEPT_EULA=decline,ACCEPT_EULA=accept,g"
    sed "$replace" ./${IMPI_VERSION}/silent.cfg > ./${IMPI_VERSION}/silent-accept.cfg

    ./${IMPI_VERSION}/install.sh -s ./${IMPI_VERSION}/silent-accept.cfg

    source /opt/intel/impi/${VERSION}/bin64/mpivars.sh
}

install_mlx_ofed_centos75()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing Mellanox OFED drivers            *" 
    echo "*                                                       *"
    echo "*********************************************************"

    KERNEL=$(uname -r)
    echo $KERNEL
    yum install -y kernel-devel-${KERNEL}
    
    if [ $? -eq 1 ]; then
        KERNEL=3.10.0-862.el7.x86_64
        echo "added RPM for $KERNEL"
        rpm -i http://vault.centos.org/7.5.1804/os/x86_64/Packages/kernel-devel-${KERNEL}.rpm
    fi
    
    yum install -y python-devel
    yum install -y redhat-rpm-config rpm-build gcc-gfortran gcc-c++
    yum install -y gtk2 atk cairo tcl tk createrepo
    
    wget --retry-connrefused \
        --tries=3 \
        --waitretry=5 \
        http://content.mellanox.com/ofed/MLNX_OFED-4.5-1.0.1.0/MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64.tgz
        
    tar zxvf MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64.tgz
    
    ./MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64/mlnxofedinstall \
        --kernel-sources /usr/src/kernels/$KERNEL \
        --add-kernel-support \
        --skip-repo
        
    sed -i 's/LOAD_EIPOIB=no/LOAD_EIPOIB=yes/g' /etc/infiniband/openib.conf
    /etc/init.d/openibd restart
    if [ $? != 0 ]; then
        echo "ERROR: unable to restart openibd"
        exit 1
    fi
}

install_mlx_ofed_centos76()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing Mellanox OFED drivers            *" 
    echo "*                                                       *"
    echo "*********************************************************"

    KERNEL=$(uname -r)
    echo $KERNEL
    yum install -y kernel-devel-${KERNEL} python-devel

    yum install -y redhat-rpm-config rpm-build gcc-gfortran gcc-c++
    yum install -y gtk2 atk cairo tcl tk createrepo
    
    wget --retry-connrefused \
        --tries=3 \
        --waitretry=5 \
        http://content.mellanox.com/ofed/MLNX_OFED-4.5-1.0.1.0/MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64.tgz
        
    tar zxvf MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64.tgz
    
    ./MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64/mlnxofedinstall \
        --add-kernel-support \
        --skip-repo

}

upgrade_lis()
{
    cd /mnt/resource
    set +e
    wget --retry-connrefused --read-timeout=10 https://aka.ms/lis
    tar xvzf lis
    pushd LISISO
    ./install.sh
    popd
    set -e
}

update_waagent()
{
    /usr/sbin/waagent --version
    # update WALA
    #yum update -y WALinuxAgent
    pushd /mnt/resource

    yum install -y python-pip
    python -m pip install --upgrade pip setuptools wheel
    wget "https://github.com/Azure/WALinuxAgent/archive/v2.2.36.zip"
    
    unzip v2.2.36.zip
    cd WALinuxAgent*
    python setup.py install --register-service --force
    sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
    #sed -i -e 's/# AutoUpdate.Enabled=y/AutoUpdate.Enabled=y/g' /etc/waagent.conf
    systemctl restart waagent

    popd
}

# check if running on HB/HC
VMSIZE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2018-04-02" | jq -r '.compute.vmSize')
VMSIZE=${VMSIZE,,}
echo "vmSize is $VMSIZE"
if [ "$VMSIZE" == "standard_hb60rs" ] || [ "$VMSIZE" == "standard_hc44rs" ]
then
    update_waagent

    set +e
    yum install -y numactl
    install_mlx_ofed_centos76

    echo 1 >/proc/sys/vm/zone_reclaim_mode
    # AMD recommended 1 - however we had issues with some application, so 3 should be used.
    echo "vm.zone_reclaim_mode = 3" >> /etc/sysctl.conf
    sysctl -p
    set -e

    upgrade_lis
fi

ifconfig

echo "End of base image "
