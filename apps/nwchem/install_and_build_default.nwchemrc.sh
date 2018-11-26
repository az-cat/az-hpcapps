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
#
