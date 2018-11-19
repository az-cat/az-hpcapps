### NAMD

A recompilation was necessary in order to use Intel MPI which is currently the only supported MPI distribution on our HPC VMs with Infiniband that we have on Azure.

No licence is required for the software although the Intel compiler is required to build the same version we have used.

#### Building

The "NAMD_2.10_Source" was used to build the version of NAMD that was run.  The source code was obtained from this page: 

- http://www.ks.uiuc.edu/Development/Download/download.cgi?PackageName=NAMD

The build machine require the Intel compilers to be installed and the following files were added/amended to use the Intel compiler and MKL for FFTW3 support:

**arch/Linux-x86_64-icc-mkl.arch**

    NAMD_ARCH = Linux-x86_64
    CHARMARCH = mpi-linux-x86_64
    FLOATOPTS = -ip -xAVX
    CXX = icpc -std=c++11 -I$(MKLROOT)/include/fftw
    CXXOPTS = -static-intel -O2 $(FLOATOPTS)
    CXXNOALIASOPTS = -O2 -fno-alias $(FLOATOPTS)
    CXXCOLVAROPTS = -O2 -ip
    CC = icc
    COPTS = -static-intel -O2 $(FLOATOPTS)

**arch/Linux-x86_64.fftw3**

	FFTDIR=$(MKLROOT)
	FFTINCL=-I$(FFTDIR)/include/fftw
	FFTLIB=-mkl
	FFTFLAGS=-DNAMD_FFTW -DNAMD_FFTW_3
	FFT=$(FFTINCL) $(FFTFLAGS)


To build NAMD: 

    cd NAMD_2.10_Source
    tar xf charm-6.6.1.tar
    cd charm-6.6.1
    MPICXX=mpiicpc ./build charm++ mpi-linux-x86_64 --with-production
    ./config Linux-x86_64-icc-mkl --charm-arch mpi-linux-x86_64 --with-fftw3

The binary is statically linked into a single executable.  This has been put in the `apps` container in storage.

#### Submit all tests

    for n in 1 2 4 8 16 32; do 
        for ppn in 14 16; do 
            ./run_app.sh \
                -a namd \
                -s namd \
                -n ${n} -p ${ppn} \
                -t stmv_${n}x${ppn}
        done
    done

#### Results

The following metrics are stored to Log Analytics:

- Clock time
- CPU time
- Memory usage

The following query can be used:

    namd_CL 
    | where model_s == "stmv" 
    | summarize percentile(todouble(cpu_time_s), 99) by Nodes_s, ppn_s
    | order by toint(Nodes_s) asc
    | render timechart 


