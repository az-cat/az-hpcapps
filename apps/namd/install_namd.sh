#!/bin/bash
if [ ! -d "/opt/intel/impi" ]; then
    setup_intel_mpi_2018
fi

HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"

mkdir -p /opt/namd2.10
wget -q "$HPC_APPS_STORAGE_ENDPOINT/namd-2-10/namd2?$HPC_APPS_SASKEY" -O /opt/namd2.10/namd2
chmod +x /opt/namd2.10/namd2
