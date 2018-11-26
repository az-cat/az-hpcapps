### OpenFOAM

The version OpenFOAM 4.x - this is not the latest version now.  This was build
with the GCC compilers and mpich-3.2 which is binary compatible with Intel MPI.

#### Building OpenFOAM

Below are instructions for building OpenFOAM.  This may have changed from when
it was originally built.  But, it shows how to build with mpich3.2 so that Intel
MPI compilers do not need to be installed.

    #
    # SETTING UP THE NODE
    #
    sudo yum -y install kernel-devel kernel-headers --disableexcludes=all
    sudo yum -y install libibverbs-utils infiniband-diags
    sudo yum -y install mpich-3.2-devel zlib-devel boost-devel gcc gcc-c++ flex screen git
    #
    # DOWNLOADING AND INSTALLING WITH MPICH-3.2
    # (binary compatible with IntelMPI)
    #
    mkdir OpenFOAM
    cd OpenFOAM
    git clone https://github.com/OpenFOAM/OpenFOAM-4.x.git
    git clone https://github.com/OpenFOAM/ThirdParty-4.x.git
    sed -i 's/=SYSTEMOPENMPI/=SYSTEMMPI/g' OpenFOAM-4.x/etc/bashrc
    export MPI_ROOT=/usr/lib64/mpich-3.2
    export MPI_ARCH_INC="-I /usr/include/mpich-3.2-x86_64"
    export MPI_ARCH_LIBS="-L /usr/lib64/mpich-3.2/lib -lmpi"
    export MPI_ARCH_FLAGS="-DMPICH_SKIP_MPICXX"
    source etc/bashrc
    unset CGAL_ARCH_PATH FOAMY_HEX_MESH
    export WM_NCOMPPROCS=32
    export PATH=/usr/lib64/mpich-3.2/bin:$PATH
    export LD_LIBRARY_PATH=/usr/lib64/mpich-3.2/lib:$LD_LIBRARY_PATH
    cd OpenFOAM-4.x
    ./Allwmake 2>&1 | tee build.log
    #
    # SET OPENFOAM TO INTELMPI
    # (you could just export all the MPI_* vars above before sourcing
    # BUT don't set the PATH/LD_LIBRARY_PATH instead
    # - this just stops OpenFOAM from complaining when sourcing bashrc)
    #
    sed -i 's/=SYSTEMMPI/=INTELMPI/g' $HOME/OpenFOAM/OpenFOAM-4.x/etc/bashrc
    for i in $(find $HOME/OpenFOAM -type d -name "mpi-system"); do
        cd $(dirname $i) && ln -s mpi-system mpi && cd -
    done
    #
    # SETTING ENV TO RUN WITH INTELMPI
    # (start a new shell)
    #
    source /opt/intel/impi/5.1.3.181/bin64/mpivars.sh
    export MPI_ROOT=$I_MPI_ROOT
    source $HOME/OpenFOAM/OpenFOAM-4.x/etc/bashrc

A binary version has been uploaded and used in the tests.

#### Application binaries and data

- upload **OpenFOAM-4.x_gcc48.tgz** file to {appstorage.storage_account}/apps/openfoam-4-x
- upload **motorbike\*.tar** benchmark files to {appstorage.storage_account}/data/openfoam-4-x

#### Setup Steps

```
    ./build_image.sh -a openfoam
    ./create_cluster.sh -a openfoam
```

#### OpenFOAM Motorbike Case

A modified verison of the OpenFOAM motorbike tutorial has been used for the test
runs.  OpenFOAM requires a separate decomposition for a different number of MPI
ranks.  The storage contains several decompositions for two different sized
cases.  The repository which contains the modified benchmark is here:

- https://github.com/OpenFOAM/OpenFOAM-Intel/tree/master/benchmarks/motorbike

*Note: This may require updates for more recent versions of OpenFOAM.*

#### Submit all tests

    for case in 20 82; do 
        for n in 2 4 8 16 32; do 
            for ppn in 16 15 14; do 
                ./run_app.sh \
                    -a openfoam \
                    -s motorbike \
                    -n ${n} -p ${ppn} \
                    -t motorbike${case}M_${n}x${ppn} \
                    -x "$case"
            done
        done
    done

#### Logging

The following data is sent to Log Analytics for the motorbike benchmark:

- model
- mesh size
- number of iterations
- total number of linear solver iterations (good for validating the same amount
  of work when scaling)
- CPU time
- Wall clock time
