#!/bin/bash
set -e

UCX_VER=1.4.0
OPEMMPI_VER=4.0.0
BUILD_DIR=$(pwd)
INSTALL_DIR=/opt
SAS_KEY=$1
AZCOPY=/opt/azcopy/azcopy
CONTAINER=openmpi

upload_package()
{
    blob=$1
    $AZCOPY cp $blob "$HPC_APPS_STORAGE_ENDPOINT/$CONTAINER/$blob?$SAS_KEY"
}

build_openucx()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Compiling & Installing Open UCX             *" 
    echo "*                                                       *"
    echo "*********************************************************"

    yum install -y numactl-devel.x86_64
    pushd $BUILD_DIR
    wget https://github.com/openucx/ucx/releases/download/v$UCX_VER/ucx-$UCX_VER.tar.gz
    tar xzf ucx-$UCX_VER.tar.gz
    cd ucx-$UCX_VER

    ./contrib/configure-release --prefix=/$INSTALL_DIR/ucx

    make -j 16
    make install

    popd

    pushd $INSTALL_DIR
    PACKAGE=ucx-$UCX_VER.tgz
    tar cavf $PACKAGE ucx
    upload_package $PACKAGE
    popd
}

# install Open MPI
# you need to install openucx first
build_openmpi()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Compiling & Installing Open MPI             *" 
    echo "*                                                       *"
    echo "*********************************************************"

    yum install -y hwloc hwloc-devel libevent-devel
    pushd $BUILD_DIR
    wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-$OPEMMPI_VER.tar.gz
    tar -xvf openmpi-$OPEMMPI_VER.tar.gz
    cd openmpi-$OPEMMPI_VER
    ./configure --with-ucx=/$INSTALL_DIR/ucx --prefix=/$INSTALL_DIR/openmpi

    make -j 16
    make install
    popd

    pushd $INSTALL_DIR
    PACKAGE=openmpi-$OPEMMPI_VER.tgz
    tar cavf $PACKAGE openmpi
    upload_package $PACKAGE
    popd
}

export PATH=/opt/rh/devtoolset-7/root/bin/:$PATH
build_openucx
build_openmpi

