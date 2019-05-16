#!/bin/bash
set -e
set -o pipefail
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"

if [[ -z "#HPC_APPS_STORAGE_ENDPOINT#" ]]; then
    echo "ERROR: HPC_APPS_STORAGE_ENDPOINT is empty"
    exit 1
fi

if [[ -z "#HPC_APPS_SASKEY#" ]]; then
    echo "ERROR: HPC_APPS_SASKEY is empty"
    exit 1
fi

if [ ! -d "/opt/intel/impi/2018"* ]; then
    setup_intel_mpi_2018
fi

