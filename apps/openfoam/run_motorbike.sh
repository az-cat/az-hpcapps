#!/bin/sh
NCELLS=$1

WORKING_DIR=$(pwd)

source /opt/intel/impi/*/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT
source /opt/OpenFOAM/OpenFOAM-4.x/etc/bashrc

cd $SHARED_DIR

echo "Downloading from: $STORAGE_ENDPOINT/openfoam-4-x/motorbike${NCELLS}M_${NODES}x${PPN}.tar?$SAS_KEY"
wget -q "$STORAGE_ENDPOINT/openfoam-4-x/motorbike${NCELLS}M_${NODES}x${PPN}.tar?$SAS_KEY" -O - | tar x

cd motorbike${NCELLS}M_${NODES}x${PPN}

mpirun \
    -genv I_MPI_FABRICS shm:dapl \
    -genv I_MPI_DAPL_PROVIDER ofa-v2-ib0 \
    -genv I_MPI_DYNAMIC_CONNECTION 0 \
    -genv I_MPI_DAPL_TRANSLATION_CACHE 0 \
    -np $CORES \
    -ppn $PPN \
    -hostfile $MPI_HOSTFILE \
    potentialFoam -parallel \
    > $OUTPUT_DIR/potentialFoam.log

mpirun \
    -genv I_MPI_FABRICS shm:dapl \
    -genv I_MPI_DAPL_PROVIDER ofa-v2-ib0 \
    -genv I_MPI_DYNAMIC_CONNECTION 0 \
    -genv I_MPI_DAPL_TRANSLATION_CACHE 0 \
    -np $CORES \
    -ppn $PPN \
    -hostfile $MPI_HOSTFILE \
    simpleFoam -parallel \
    > $OUTPUT_DIR/simpleFoam.log

fname=$OUTPUT_DIR/simpleFoam.log
num_iter=$(grep ExecutionTime $fname | wc -l)
tot_lin_iter=$(echo $(grep Iterations $fname | grep -o '[^ ]*$' | tr '\n' '+')0 | bc)
cpu_beg=$(grep ExecutionTime $fname | head -n1 | cut -d' ' -f3)
cpu_end=$(grep ExecutionTime $fname | tail -n1 | cut -d' ' -f3)
cpu_dur=$(bc <<< "$cpu_end - $cpu_beg")
clk_beg=$(grep ExecutionTime $fname | head -n1 | cut -d' ' -f8)
clk_end=$(grep ExecutionTime $fname | tail -n1 | cut -d' ' -f8)
clk_dur=$(bc <<< "$clk_end - $clk_beg")

cd $WORKING_DIR

cat <<EOF >$APPLICATION.json
{
"model": "motorbike",
"size": "$NCELLS",
"iterations": "$num_iter",
"total_linear_solver_iterations": "$tot_lin_iter",
"cpu_time": "$cpu_dur",
"clock_time": "$clk_dur"
}
EOF
