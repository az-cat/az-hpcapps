#!/bin/bash
set -o errexit
set -o pipefail

MEMORY_GB=$1
HPL_NB=232
HPL_N=$(bc <<< "((sqrt(${MEMORY_GB}*1024^3/8))/${HPL_NB})*${HPL_NB}")

cat <<EOF >HPL.dat
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
$HPL_N        Ns
1            # of NBs
$HPL_NB          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
3            Ps
5            Qs
16.0         threshold
1            # of panel fact
2            PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
4            NBMINs (>= 1)
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
2            RFACTs (0=left, 1=Crout, 2=Right)
1            # of broadcast
2            BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1            # of lookahead depth
1            DEPTHs (>=0)
1            SWAP (0=bin-exch,1=long,2=mix)
$HPL_NB           swapping threshold
0            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
1            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF


# Use explicit process binding
export OMP_PROC_BIND=TRUE
# Have OpenMP ignore SMT siblings if SMT is enabled
export OMP_PLACES=cores

# Use 4 threads per L3 cache
cores=4
export OMP_NUM_THREADS=$cores

# DGEMM parallelization is performed at the 2nd innermost loop (IC)
export BLIS_IR_NT=1
export BLIS_JR_NT=1
export BLIS_IC_NT=$cores
export BLIS_JC_NT=1

# Launch 15 processes (one per L3 cache, two L3 per die, 4 die per socket, 2 sockets)
mpi_options="-np $PPN"

# Use vader for Byte Transfer Layer
mpi_options+=" --mca btl self,vader"

# set UCX
mpi_options+=" -mca pml ucx"

# Map processes to L3 cache
# Note if SMT is enabled, the resource list given to each process will include
# the SMT siblings! See OpenMP options above.
mpi_options+=" --map-by l3cache"

# Show bindings
mpi_options+=" --report-bindings"

#mpi_options+=" --allow-run-as-root"

# Set IB
mpi_options+=" -x UCX_NET_DEVICES=mlx5_0:1 -x UCX_IB_PKEY=$UCX_IB_PKEY"

output_file=${OUTPUT_DIR}/hpl.log
MPI_ROOT=/opt/openmpi

$MPI_ROOT/bin/mpirun $mpi_options $APP_PACKAGE_DIR/hpl/xhpl_epyc | tee ${output_file}

if [ -f "${output_file}" ]; then
    # keep input file
    cp HPL.dat ${OUTPUT_DIR}
    result_line=$(grep "WR12R2R4" ${output_file} | sed 's/  */ /g')
    gflops=$(echo $result_line | cut -d' ' -f 7)
    gflops=$(printf '%.2f' $gflops)
    hpl_time=$(echo $result_line | cut -d' ' -f 6)
    cat <<EOF >$APPLICATION.json
    {
    "bench":"hpl",
    "N": $HPL_N,
    "NB": $HPL_NB,
    "Gflops": $gflops,
    "time": $hpl_time
    }
EOF
fi



