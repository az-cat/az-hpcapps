#!/bin/bash
set -e

install_openucx()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Compiling & Installing Open UCX             *" 
    echo "*                                                       *"
    echo "*********************************************************"

    yum install -y numactl-devel.x86_64
    pushd /mnt/resource
    wget https://github.com/openucx/ucx/releases/download/v1.4.0/ucx-1.4.0.tar.gz
    tar xzf ucx-1.4.0.tar.gz
    cd ucx-1.4.0

    ./contrib/configure-release --prefix=/opt/ucx

    make -j 16
    make install

    popd
}

# install Open MPI
# you need to install openucx first
install_openmpi()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Compiling & Installing Open MPI             *" 
    echo "*                                                       *"
    echo "*********************************************************"

    yum install -y hwloc hwloc-devel libevent-devel
    pushd /mnt/resource
    wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.0.tar.gz
    tar -xvf openmpi-4.0.0.tar.gz
    cd openmpi-4.0.0
    ./configure --with-ucx=/opt/ucx --prefix=/opt/openmpi

    make -j 16
    make install
    popd
}

setup_gcc()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing latest GCC 7.x                   *" 
    echo "*                                                       *"
    echo "*********************************************************"

    yum install centos-release-scl-rh -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc-c++ -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc-gfortran -y  

    export PATH=/opt/rh/devtoolset-7/root/bin/:$PATH
}

setup_gcc
install_openucx
install_openmpi

