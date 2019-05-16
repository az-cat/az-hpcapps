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
yum install -y nfs-utils jq htop hwloc environment-modules
if [ $? != 0 ]; then
    echo "ERROR: unable to install nfs-utils jq htop hwloc environment-modules"
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


setup_intel_mpi_2018()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing Intel MPI & Tools                *" 
    echo "*                                                       *"
    echo "*********************************************************"
    VERSION=2018.4.274

    yum -y install yum-utils
    yum-config-manager --add-repo https://yum.repos.intel.com/mpi/setup/intel-mpi.repo
    rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB

    yum -y install intel-mpi-2018.4-057

mkdir -p /usr/share/Modules/modulefiles/mpi

cat << EOF >> /usr/share/Modules/modulefiles/mpi/impi-$VERSION
#%Module 1.0
#
#  Intel MPI $VERSION
#
conflict        mpi
prepend-path    PATH            /opt/intel/impi/$VERSION/intel64/bin
prepend-path    LD_LIBRARY_PATH /opt/intel/impi/$VERSION/intel64/lib
prepend-path    MANPATH         /opt/intel/impi/$VERSION/man
setenv          MPI_BIN         /opt/intel/impi/$VERSION/intel64/bin
setenv          MPI_INCLUDE     /opt/intel/impi/$VERSION/intel64/include
setenv          MPI_LIB         /opt/intel/impi/$VERSION/intel64/lib
setenv          MPI_MAN         /opt/intel/impi/$VERSION/man
setenv          MPI_HOME        /opt/intel/impi/$VERSION/intel64
EOF

    #source /opt/intel/impi/${VERSION}/bin64/mpivars.sh
}


upgrade_lis()
{
    pushd /mnt/resource
    set +e
    wget --retry-connrefused --read-timeout=10 https://aka.ms/lis
    tar xvzf lis
    pushd LISISO
    ./install.sh
    popd
    set -e
    popd
}


# check if running on HB/HC
VMSIZE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2018-04-02" | jq -r '.compute.vmSize')
VMSIZE=${VMSIZE,,}
echo "vmSize is $VMSIZE"
if [ "$VMSIZE" == "standard_hb60rs" ] || [ "$VMSIZE" == "standard_hc44rs" ]
then

    #echo 3 >/proc/sys/vm/zone_reclaim_mode
    # AMD recommended 1 - however we had issues with some application, so 3 should be used.
    #echo "vm.zone_reclaim_mode = 3" >> /etc/sysctl.conf
    #sysctl -p

    upgrade_lis
fi

ifconfig

echo "End of base image "
