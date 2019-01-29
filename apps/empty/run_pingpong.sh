#!/bin/bash
set -o errexit
set -o pipefail

# setup Intel MPI environment for Infiniband
source /opt/intel/impi/*/bin64/mpivars.sh
export I_MPI_DEBUG=6
export MPI_ROOT=$I_MPI_ROOT
export I_MPI_STATS=ipm
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

LOGFILE=${OUTPUT_DIR}/pingpong.log
mpirun -np 2 -ppn 1 -hosts $MPI_HOSTLIST IMB-MPI1 PingPong \
    | tee ${LOGFILE}

bandwidth=$(grep "524288           80" ${LOGFILE} | sed 's/  */ /g' | cut -d' ' -f 5)
latency=$(grep " 4         1000" ${LOGFILE} | sed 's/  */ /g' | cut -d' ' -f 4)

cat <<EOF >$APPLICATION.json
{
"MPI": "IntelMPI",
"app": "IMB-MPI1",
"test": "PingPong",
"latency": "$latency",
"bandwidth": "$bandwidth",
"ic": "$INTERCONNECT"
}
EOF

