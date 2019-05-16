#!/bin/bash
set -e

DOWNLOAD_DIR=/mnt/resource
INSTALL_DIR=/opt/esi-group
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

mkdir -p /usr/share/Modules/modulefiles/mpi

cat << EOF >> /usr/share/Modules/modulefiles/mpi/pmpi
#%Module 1.0
#
#  Platform MPI
#
conflict        mpi
prepend-path    PATH            /opt/ibm/platform_mpi/bin/
prepend-path    LD_LIBRARY_PATH /opt/ibm/platform_mpi/lib
prepend-path    MANPATH         /opt/ibm/platform_mpi/man
setenv          MPI_BIN         /opt/ibm/platform_mpi/bin
setenv          MPI_INCLUDE     /opt/ibm/platform_mpi/include
setenv          MPI_LIB         /opt/ibm/platform_mpi/lib
setenv          MPI_MAN         /opt/ibm/platform_mpi/man
setenv          MPI_HOME        /opt/ibm/platform_mpi
EOF

    /opt/ibm/platform_mpi/bin/mpirun -version

    popd
}

if [ ! -d "/opt/ibm/platform_mpi" ]; then
    pushd $DOWNLOAD_DIR
    setup_pmpi
    popd
fi

if [ ! -d "/opt/intel/impi/2018"* ]; then
    setup_intel_mpi_2018
fi

mkdir -p $INSTALL_DIR
pushd $DOWNLOAD_DIR

PACKAGE=VPSolution-2017.0.2_Solvers_Linux-Intel64.tar.bz2
wget "${HPC_APPS_STORAGE_ENDPOINT}/esi/${PACKAGE}?${HPCAPPS_SASKEY}" -O ${PACKAGE}
tar -xvf ${PACKAGE} -C $INSTALL_DIR

PACKAGE=VPSolution-2018.01_DMP+SMP-Solvers_Linux-Intel64.tar.bz2
wget "${HPC_APPS_STORAGE_ENDPOINT}/esi/${PACKAGE}?${HPCAPPS_SASKEY}" -O ${PACKAGE}
tar -xvf ${PACKAGE} -C $INSTALL_DIR

PACKAGE=mpm_master.171124.3-linux-x64-intel.tar.gz
wget "${HPC_APPS_STORAGE_ENDPOINT}/esi/${PACKAGE}?${HPCAPPS_SASKEY}" -O ${PACKAGE}
tar -xvf ${PACKAGE} -C $INSTALL_DIR/pamcrash_safe/2018.01/Linux_x86_64/lib/

popd