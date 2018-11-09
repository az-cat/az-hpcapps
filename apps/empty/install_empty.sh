#!/bin/bash
set -e
set -o pipefail

if [[ -z "#HPC_APPS_STORAGE_ENDPOINT#" ]]; then
    echo "ERROR: HPC_APPS_STORAGE_ENDPOINT is empty"
    exit 1
fi

if [[ -z "#HPC_APPS_SASKEY#" ]]; then
    echo "ERROR: HPC_APPS_SASKEY is empty"
    exit 1
fi

setup_intel_mpi()
{
    echo "Installing Intel MPI & Tools"
    VERSION=2018.2.199
    IMPI_VERSION=l_mpi_${VERSION}
    wget -q http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12748/${IMPI_VERSION}.tgz
    tar xvf ${IMPI_VERSION}.tgz

    replace="s,ACCEPT_EULA=decline,ACCEPT_EULA=accept,g"
    sed "$replace" ./${IMPI_VERSION}/silent.cfg > ./${IMPI_VERSION}/silent-accept.cfg

    ./${IMPI_VERSION}/install.sh -s ./${IMPI_VERSION}/silent-accept.cfg

    source /opt/intel/impi/${VERSION}/bin64/mpivars.sh
}

if [ ! -d "/opt/intel/impi" ]; then
    setup_intel_mpi
fi