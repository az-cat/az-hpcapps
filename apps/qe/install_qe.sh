#!/bin/bash
set -e

HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"
QEVERSION=6.3
CONTAINER=qe

yum -y install yum-utils libgfortran4 git

yum-config-manager --add-repo https://yum.repos.intel.com/mkl/setup/intel-mkl.repo
yum-config-manager --add-repo https://yum.repos.intel.com/mpi/setup/intel-mpi.repo

rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB

yum -y install intel-mkl-2018.4-057 intel-mpi-2018.4-057

QE_DIR=/opt/qe-omp
if [ ! -d "$QE_DIR/bin" ]; then
    echo "download QE ${QEVERSION} package"
    mkdir $QE_DIR
    pushd $QE_DIR
    PACKAGE=qe-${QEVERSION}-omp-intel-elpa.tgz
    wget -q "${HPC_APPS_STORAGE_ENDPOINT}/qe/${QEVERSION}/${PACKAGE}?${HPC_APPS_SASKEY}" -O - | tar zx
    popd
fi

# Get Benchmark files
pushd /opt
git clone https://github.com/QEF/benchmarks.git 