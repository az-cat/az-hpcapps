#!/bin/bash
set -e
DOWNLOAD_DIR=/mnt/resource
INSTALL_DIR=/opt/ansys_inc
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPCAPPS_SASKEY="#HPC_APPS_SASKEY#"

setup_pmpi()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing Platform MPI 9.1.4               *" 
    echo "*                                                       *"
    echo "*********************************************************"
    CONTAINER="platformmpi-941"
    PACKAGE=platform_mpi-09.01.04.03r-ce.bin

    yum -y install libstdc++
    yum -y install libstdc++.i686 
    #yum install glibc.i686
    pushd $DOWNLOAD_DIR
    echo "download Platform MPI package"
    wget "${HPC_APPS_STORAGE_ENDPOINT}/${CONTAINER}/${PACKAGE}?${HPCAPPS_SASKEY}" -O ${PACKAGE}
    chmod +x ${PACKAGE}
    ./${PACKAGE} -i silent

    /opt/ibm/platform_mpi/bin/mpirun -version

    popd
}

function install_fluent()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing Fluent                           *" 
    echo "*                                                       *"
    echo "*********************************************************"
    VERSION=192
    CONTAINER="ansys-fluent-19.2"
    PACKAGE=FLUIDS_${VERSION}_LINX64.tar

    mkdir $INSTALL_DIR
    pushd $DOWNLOAD_DIR

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

    popd
}

if [ ! -d "/opt/intel/impi" ]; then
    pushd $DOWNLOAD_DIR
    setup_intel_mpi_2018
    popd
fi

if [ ! -d "/opt/ibm/platform_mpi" ]; then
    pushd $DOWNLOAD_DIR
    setup_pmpi
    popd
fi

install_fluent

