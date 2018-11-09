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
*               hard    nofile          65535
*               soft    nofile          65535
EOF

# install based packages
yum install -y epel-release
yum install -y -q nfs-utils jq htop

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

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

install_beegfs()
{
	wget -O /etc/yum.repos.d/beegfs-rhel7.repo https://www.beegfs.io/release/beegfs_7/dists/beegfs-rhel7.repo
	rpm --import https://www.beegfs.io/release/latest-stable/gpg/RPM-GPG-KEY-beegfs

	yum install -y beegfs-client beegfs-helperd beegfs-utils gcc gcc-c++
	yum install -y "kernel-devel-uname-r == $(uname -r)"

	sed -i 's/^sysMgmtdHost.*/sysMgmtdHost = localhost/g' /etc/beegfs/beegfs-client.conf
	echo "/beegfs /etc/beegfs/beegfs-client.conf" > /etc/beegfs/beegfs-mounts.conf
	
	systemctl daemon-reload
	systemctl enable beegfs-helperd.service
	systemctl enable beegfs-client.service
}

install_beegfs