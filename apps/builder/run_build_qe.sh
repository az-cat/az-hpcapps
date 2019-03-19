#!/bin/bash
# Prerequisites : GCC 7.x
set -e

BUILD_DIR=$(pwd)
WRITE_SAS_KEY=$1
AZCOPY=/opt/azcopy/azcopy
QEVERSION=6.3
CONTAINER=qe
ELPA_VERSION=2017.11.001
ELPA_DEST=${BUILD_DIR}/elpa-omp

upload_package()
{
    blob=$1
    $AZCOPY cp $blob "$HPC_APPS_STORAGE_ENDPOINT/$CONTAINER/$QEVERSION/$blob?$WRITE_SAS_KEY"
}

build_elpa()
{
    wget -q https://elpa.mpcdf.mpg.de/html/Releases/2017.11.001/elpa-${ELPA_VERSION}.tar.gz
    tar xvf elpa-${ELPA_VERSION}.tar.gz
    pushd elpa-${ELPA_VERSION}

    export FCFLAGS="-O3 -march=skylake-avx512 -mtune=skylake-avx512 -mfma"
    export CFLAGS="-O3 -march=skylake-avx512 -mtune=skylake-avx512 -mfma  -funsafe-loop-optimizations -funsafe-math-optimizations -ftree-vect-loop-version -ftree-vectorize" 
    export SCALAPACK_LDFLAGS="-L$MKLROOT/lib/intel64 -lmkl_scalapack_lp64 -lmkl_gf_lp64 -lmkl_sequential -lmkl_core -lmkl_blacs_intelmpi_lp64 -lpthread" 
    export SCALAPACK_FCFLAGS="-I$MKLROOT/include/intel64/lp64"
    export LDFLAGS="-L${MKLROOT}/lib/intel64"
    export FC=mpif90

    mkdir ${ELPA_DEST}

    ./configure \
        --enable-option-checking=fatal \
        --enable-openmp \
        --prefix=${ELPA_DEST}

    make 

    make install

    # unset variables to avoid any conflict
    unset FCFLAGS
    unset CFLAGS
    unset SCALAPACK_LDFLAGS
    unset SCALAPACK_FCFLAGS
    unset LDFLAGS
    unset FC

    popd
    # export LDFLAGS="-L${MKLROOT}/lib/intel64"
    # export CFLAGS="-O3 -fopenmp -march=skylake-avx512 -mtune=skylake-avx512 -I$(MKLROOT)/include"
    # export CXXFLAGS="${CFLAGS}"
    # export SCALAPACK_LDFLAGS="-lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64"
    # export LIBS="-lmkl_intel_lp64 -lmkl_core -lmkl_intel_thread -liomp5"
    # ./configure --enable-avx512 --enable-openmp 
}

build_qe()
{

    PACKAGE=q-e-qe-${QEVERSION}
    wget -q https://gitlab.com/QEF/q-e/-/archive/qe-${QEVERSION}/${PACKAGE}.tar.gz
    tar -xvzf ${PACKAGE}.tar.gz
    rm ${PACKAGE}.tar.gz
    pushd ${PACKAGE}

    export BLAS_LIBS="-lmkl_intel_lp64 -lmkl_core -lmkl_intel_thread -lmkl_blacs_intelmpi_lp64"
    ELPAROOT=${ELPA_DEST}

    ./configure --enable-openmp --enable-parallel --with-scalapack=intel \
        BLAS_LIBS="${BLAS_LIBS}" \
        LAPACK_LIBS="${BLAS_LIBS}" \
        SCALAPACK_LIBS="-lmkl_scalapack_lp64" \
        FFT_LIBS="${BLAS_LIBS}" \
        CFLAGS="-O3 -fopenmp -march=skylake-avx512 -mtune=skylake-avx512" \
        FFLAGS="-O3 -g -fopenmp -march=skylake-avx512 -mtune=skylake-avx512" \
        LD_LIBS="-liomp5 ${ELPAROOT}/lib/libelpa_openmp.a" \
        --with-elpa=${ELPAROOT} \
        --with-elpa-include="-I${ELPAROOT}/include/elpa_openmp-${ELPA_VERSION}/modules" 
#        --with-elpa-lib=${ELPAROOT}/lib/libelpa_openmp.a 

    # fix generated file. See https://github.com/hfp/xconfigure/blob/master/config/qe/configure-qe-skx-omp.sh
    if [ -e ./make.inc ]; then
    INCFILE=./make.inc
    else
    INCFILE=./make.sys
    fi
    echo "INCFILE=$INCFILE"

    SED_ELPAROOT=$(echo ${ELPAROOT} | sed -e "s/\//\\\\\//g")
    sed -i \
    -e "s/-D__FFTW3/-D__DFTI/" \
    -e "s/-D__FFTW/-D__DFTI/" \
    -e "s/^IFLAGS\s\s*=\s\(..*\)/IFLAGS = -I\$(MKLROOT)\/include\/fftw -I\$(MKLROOT)\/include -I${SED_ELPAROOT}\/include\/elpa_openmp-${ELPA_VERSION}\/elpa \1/" \
    -e "s/-D__ELPA_2016/-D__ELPA_2017/" \
    -e "s/-D__ELPA_2017/-D__ELPA_2018/" \
    ${INCFILE}

    make all

    PACKAGE=qe-${QEVERSION}-omp-intel-elpa.tgz
    tar cavfh $PACKAGE bin
    upload_package $PACKAGE

    popd
}

export PATH=/opt/rh/devtoolset-7/root/bin/:$PATH

yum -y install yum-utils
yum-config-manager --add-repo https://yum.repos.intel.com/setup/intelproducts.repo
rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB

yum -y install intel-mkl-2018.4-057 intel-mpi-2018.4-057

export MANPATH=/opt/intel/impi/2018.4.274/linux/mpi/man
source /opt/intel/mkl/bin/mklvars.sh intel64
source /opt/intel/impi/2018.4.274/intel64/bin/mpivars.sh

build_elpa
build_qe

