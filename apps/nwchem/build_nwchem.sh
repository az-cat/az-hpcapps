#!/bin/bash
export NWCHEM_TOP=/home/hpcuser/nwchem-6.8
export NWCHEM_TARGET=LINUX64
#export ARMCI_NETWORK=MPI-MT
export USE_MPI=y
export USE_MPIF=y
export USE_MPIF4=y
export USE_NOIO=TRUE
export LIB_DEFINES="_DDFLT_TOT_MEM=10000000000"
export USE_PYTHONCONFIG=y
export PYTHONHOME=/usr
export PYTHONVERSION=2.7
export USE_INTERNALBLAS=y
#
which mpif90
mpif90 -show
#
cd $NWCHEM_TOP/src
make clean
echo "start make nwchecm_config, `date`"
make nw_chem_config NWCHEM_MODULES="all python"
echo "end make nwchem_config, `date`"
#
echo "start make, `date`"
make FC=gfortran
echo "end make, `date`"
