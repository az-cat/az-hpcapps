#!/bin/bash
set -e

DOWNLOAD_DIR=/mnt/resource
INSTALL_DIR=/opt/ansys_inc
PACKAGE=FLUIDS_182_LINX64.tar
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPCAPPS_SASKEY="#HPC_APPS_SASKEY#"

mkdir $INSTALL_DIR
cd $DOWNLOAD_DIR

wget "${HPC_APPS_STORAGE_ENDPOINT}/ansys-fluent-18/${PACKAGE}?${HPCAPPS_SASKEY}" -O ${PACKAGE}
tar -xvf ${PACKAGE}

yum -y install freetype 

echo "Installing Package Dependencies"
yum groupinstall -y "X Window System"
yum -y install motif.x86_64
yum -y install mesa-libGLU-9.0.0-4.el7.x86_64

#yum -y update

./INSTALL -silent -install_dir "$INSTALL_DIR/" -fluent -nohelp
