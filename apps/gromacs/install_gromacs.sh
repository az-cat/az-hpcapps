#!/bin/bash
WORKING_DIR=/mnt/resource
GMX_VERSION=2018.1
INSTALL_DIR=/opt/gromacs-${GMX_VERSION}

cd ${WORKING_DIR}

setup_build_tools()
{
    echo "Installing Development tools"
    #yum update -y
    #yum groupinstall -y 'Development Tools'

    # setup CMAKE
    echo "Installing CMAKE"
    wget -q http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/c/cmake3-3.6.3-1.el7.x86_64.rpm
    wget -q http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
    rpm -Uvh epel-release*rpm
    yum install cmake3 -y
    ln -s /usr/bin/cmake3 /usr/bin/cmake

    # setup GCC 7.2
    echo "Installing GCC 7.2"
    yum install centos-release-scl-rh -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc-c++ -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc-gfortran -y  

}

setup_intel_mpi()
{
    echo "Installing Intel MPI & Tools"
    VERSION=2018.2.199
    IMPI_VERSION=l_mpi_${VERSION}
    wget -q http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12748/${IMPI_VERSION}.tgz
    tar xvf ${IMPI_VERSION}.tgz

    replace="s,ACCEPT_EULA=decline,ACCEPT_EULA=accept,g"
    sed "$replace" ./${IMPI_VERSION}/silent.cfg > ./${IMPI_VERSION}/silent-accept.cfg

    ./${IMPI_VERSION}/install.sh -s ./${IMPI_VERSION}/silent-accept.cfg

    source /opt/intel/impi/${VERSION}/bin64/mpivars.sh
}

get_gromacs()
{
    echo "Get Gromacs"
    wget -q http://ftp.gromacs.org/pub/gromacs/gromacs-${GMX_VERSION}.tar.gz
    tar xvf gromacs-${GMX_VERSION}.tar.gz
}

build_gromacs()
{
    echo "Build Gromacs"
    cd gromacs-${GMX_VERSION}
    mkdir build
    cd build
    cmake \
            -DBUILD_SHARED_LIBS=off \
            -DBUILD_TESTING=off \
            -DREGRESSIONTEST_DOWNLOAD=OFF \
            -DCMAKE_C_COMPILER=`which mpicc` \
            -DCMAKE_CXX_COMPILER=`which mpicxx` \
            -DGMX_BUILD_OWN_FFTW=on \
            -DGMX_DOUBLE=off \
            -DGMX_EXTERNAL_BLAS=off \
            -DGMX_EXTERNAL_LAPACK=off \
            -DGMX_FFT_LIBRARY=fftw3 \
            -DGMX_GPU=off \
            -DGMX_MPI=on \
            -DGMX_OPENMP=on \
            -DGMX_X11=off \
            -DCMAKE_EXE_LINKER_FLAGS="-zmuldefs " \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
            ..

    make -j 8
    make install
}

setup_build_tools
setup_intel_mpi
get_gromacs

export PATH=/opt/rh/devtoolset-7/root/bin/:$PATH

build_gromacs


