#!/bin/bash

HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"

yum install -y gcc-gfortran
cd /opt
wget $HPC_APPS_STORAGE_ENDPOINT/nwchem-6.8-x/nwchem-6.8-x_gcc485.tgz?$HPC_APPS_SASKEY -O - | tar zx

