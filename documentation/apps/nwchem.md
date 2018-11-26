### NWChem

nwchem is an open source high-performance computational chemistry package.
This version was build with the GCC/gfortran 4.8.5 compilers and Intel MPI 5.1.3.223.

#### Building nwchem

Below are instructions for building nwchem. 

    #
    # SETTING UP THE NODE
    #
    sudo yum install "Development tools"

    #
    # DOWNLOADING AND INSTALLING Intel MPI 5.1.3.223
    # 
    #

    Install trial version Intel mpi version 5.1.3.223 (with compiler wrappers)

    tar xvf l_mpi_p_5.1.3.223.solitairetheme8
    install.sh
    source /opt/intel/impi/*/bin64/mpivars.sh
 
    #
    # BUILD NWCHEM
    #
    The following script was created (build_nwchem.sh).

    	#!/bin/bash
	export NWCHEM_TOP=/home/hpcuser/nwchem-6.8
	export NWCHEM_TARGET=LINUX64
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
	cd $NWCHEM_TOP/src
	echo "start make nwchecm_config, `date`"
	make nw_chem_config NWCHEM_MODULES="all python"
	echo "end make nwchem_config, `date`"
	#
	echo "start make, `date`"
	make FC=gfortran
	echo "end make, `date`"

    ./build_nwchem.sh 2>&1 | tee  build_nwchem.log

Created install script (called install_nwchem.sh)
This create installs nwchem in $INSTALL_DIR and creates a system default default.nwchemrc file
(which identifies the location of nwchem data and libraries)


#!/bin/bash
#
NWCHEM_TOP=/home/hpcuser/nwchem-6.8
NWCHEM_TARGET=LINUX64
INSTALL_DIR=/home/hpcuser/NWChem
#
mkdir $INSTALL_DIR
mkdir $INSTALL_DIR/bin
mkdir $INSTALL_DIR/data
#
cp $NWCHEM_TOP/bin/${NWCHEM_TARGET}/nwchem $INSTALL_DIR/bin
cd $INSTALL_DIR/bin
chmod 755 nwchem
#
cd $NWCHEM_TOP/src/basis
cp -r libraries $INSTALL_DIR/data
cd $NWCHEM_TOP/src/
cp -r data $INSTALL_DIR
cd $NWCHEM_TOP/src/nwpw
cp -r libraryps $INSTALL_DIR/data
#
DEFAULTNWCHEMRC=default.nwchemrc
echo "nwchem_basis_library $INSTALL_DIR/data/libraries/" > $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "nwchem_nwpw_library $INSTALL_DIR/data/libraryps/" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "ffield amber" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "amber_1 $INSTALL_DIR/data/amber_s/" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "amber_2 $INSTALL_DIR/data/amber_q/" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "amber_3 $INSTALL_DIR/data/amber_x/" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "amber_4 $INSTALL_DIR/data/amber_u/" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "spce    $INSTALL_DIR/data/solvents/spce.rst" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "charmm_s $INSTALL_DIR/data/charmm_s/" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC
echo "charmm_x $INSTALL_DIR/data/charmm_x/" >> $INSTALL_DIR/data/$DEFAULTNWCHEMRC


./install_nwchem.sh

#### Application binaries and data

- upload **nwchem-6.8-x_gcc485.tgz** file to {appstorage.storage_account}/apps/nwchem-6.8-x
- upload **h2o_freq.tar** benchmark file to {appstorage.storage_account}/data/nwchem-6.8-x

#### nwchem H2o model

A h2o model from nwchem documentation has been provided for testing purposes.

- http://www.nwchem-sw.org/index.php/Release66:Getting_Started


#### Submit all tests

    for n in 2 4 8 16 32; do 
        for ppn in 16 15 14; do 
            ./run_app.sh \
               -a nwchem \
               -s h2o_freq \
               -n ${n} -p ${ppn} \
               -t h2o_freq_${n}x${ppn} \
        done
    done

#### Logging

The following data is sent to Log Analytics from the h2o_freq benchmark:

- model
- CPU time
- Wall clock time
- memory

