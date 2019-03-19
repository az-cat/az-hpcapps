#!/bin/bash
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"

QEVERSION=6.3

QE_DIR=/opt/qe-omp
if [ ! -d "$QE_DIR/bin" ]; then
    echo "download QE ${QEVERSION} package"
    mkdir $QE_DIR
    pushd $QE_DIR
    PACKAGE=qe-${QEVERSION}-omp-intel-elpa.tgz
    wget -q "${HPC_APPS_STORAGE_ENDPOINT}/qe/${QEVERSION}/${PACKAGE}?${HPC_APPS_SASKEY}" -O - | tar zx
    popd
fi
