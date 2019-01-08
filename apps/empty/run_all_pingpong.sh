#!/bin/bash
set -o errexit
set -o pipefail

# setup Intel MPI environment for Infiniband
source /opt/intel/impi/*/bin64/mpivars.sh
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
    export I_MPI_PIN_PROCESSOR_LIST=48
else
    export I_MPI_FABRICS=shm:tcp
fi

nbhosts=$(cat $MPI_HOSTFILE | wc -l)
echo $nbhosts
i=0
sortednodes=$(sort $MPI_HOSTFILE)
for src in $sortednodes; do
    nodes=$(($nbhosts-$i))
    nodelist=$(sort $MPI_HOSTFILE | tail -n${nodes})
    for line in $nodelist; do
        dst=$line
        if [ "$src" != "$dst" ]; then
            mpirun -np 2 -ppn 1 -hosts $src,$dst IMB-MPI1 -msglog 1:2 PingPong > ${src}_to_${dst}_pingpong.log
            mpirun -np 2 -ppn 1 -hosts $src,$dst IMB-MPI1 -msglog 18:19 PingPong >> ${src}_to_${dst}_pingpong.log
        fi
    done
    i=$(($i+1))
done

grep "524288           80" *.log | awk -F'_' '{split($4, c, " "); print $1, $3, c[5]}' > $OUTPUT_DIR/bandwidth.txt
grep " 4         1000" *.log | awk -F'_' '{split($4, c, " "); print $1, $3, c[4]}' > $OUTPUT_DIR/latency.txt
