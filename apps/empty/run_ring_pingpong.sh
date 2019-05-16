#!/bin/bash
set -o errexit
set -o pipefail

# setup Intel MPI environment for Infiniband
source /etc/profile # so we can load modules
module load mpi/impi-2018.4.274
source $MPI_BIN/mpivars.sh

#export I_MPI_DEBUG=6
export MPI_ROOT=$I_MPI_ROOT
echo "INTERCONNECT=$INTERCONNECT"

export I_MPI_DYNAMIC_CONNECTION=0
export I_MPI_FALLBACK_DEVICE=0
export I_MPI_EAGER_THRESHOLD=1048576

if [ "$INTERCONNECT" == "ib" ]; then
    export I_MPI_FABRICS=shm:dapl
    export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
elif [ "$INTERCONNECT" == "sriov" ]; then
    export I_MPI_FABRICS=shm:ofa
    if [ "$VMSIZE" == "standard_hb60rs" ]; then
        export I_MPI_PIN_PROCS=48
    elif [ "$VMSIZE" == "standard_hc44rs" ]; then
        export I_MPI_PIN_PROCS=43
    fi
else
    export I_MPI_FABRICS=shm:tcp
fi

src=$(tail -n1 $MPI_HOSTFILE)
for line in $(<$MPI_HOSTFILE); do
    dst=$line
    mpirun -np 2 -ppn 1 -hosts $src,$dst IMB-MPI1 PingPong \
        | tee ${src}_to_${dst}_pingpong.log
    src=$dst
done

grep "524288           80" *.log | awk -F'_' '{split($4, c, " "); print $1, $3, c[5]}' > $OUTPUT_DIR/bandwidth.txt
grep " 4         1000" *.log | awk -F'_' '{split($4, c, " "); print $1, $3, c[4]}' > $OUTPUT_DIR/latency.txt
