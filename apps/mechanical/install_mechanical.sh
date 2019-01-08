#!/bin/bash
set -e

if [ ! -d "/opt/intel/impi" ]; then
    setup_intel_mpi_2018
fi

DOWNLOAD_DIR=/mnt/resource
INSTALL_DIR=/opt/ansys_inc
VERSION=192
PACKAGE=STRUCTURES_${VERSION}_LINX64.tar
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPCAPPS_SASKEY="#HPC_APPS_SASKEY#"

mkdir $INSTALL_DIR
cd $DOWNLOAD_DIR

wget "${HPC_APPS_STORAGE_ENDPOINT}/ansys-mech-19-2/${PACKAGE}?${HPCAPPS_SASKEY}" -O ${PACKAGE}
tar -xvf ${PACKAGE}

echo "Installing Package Dependencies"
yum groupinstall -y "X Window System"
yum -y install freetype motif.x86_64 mesa-libGLU-9.0.0-4.el7.x86_64

./INSTALL -silent -install_dir "$INSTALL_DIR/" -mechapdl -nohelp
