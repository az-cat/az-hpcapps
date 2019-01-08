#!/bin/bash
set -e

if [ ! -d "/opt/intel/impi" ]; then
    setup_intel_mpi_2018
fi

echo "*********************************************************"
echo "*                                                       *"
echo "*           Installing Fluent                           *" 
echo "*                                                       *"
echo "*********************************************************"

DOWNLOAD_DIR=/mnt/resource
INSTALL_DIR=/opt/ansys_inc
VERSION=192
CONTAINER="ansys-fluent-19.2"
PACKAGE=FLUIDS_${VERSION}_LINX64.tar
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPCAPPS_SASKEY="#HPC_APPS_SASKEY#"

mkdir $INSTALL_DIR
cd $DOWNLOAD_DIR

echo "download Fluent package"
wget "${HPC_APPS_STORAGE_ENDPOINT}/${CONTAINER}/${PACKAGE}?${HPCAPPS_SASKEY}" -O ${PACKAGE}
echo "untar Fluent package"
tar -xvf ${PACKAGE}

echo "Installing Package Dependencies"
yum groupinstall -y "X Window System"
yum -y install freetype motif.x86_64 mesa-libGLU-9.0.0-4.el7.x86_64

echo "Install Fluent"
./INSTALL -silent -install_dir "$INSTALL_DIR/" -fluent -nohelp -disablerss

echo "Fluent Installed"
