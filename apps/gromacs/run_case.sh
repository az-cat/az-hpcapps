#!/bin/bash
package=$1.tar.gz
casename=$2

GMX_VERSION=2018.1
INSTALL_DIR=/opt/gromacs-${GMX_VERSION}
OUTPUT_FILE=${OUTPUT_DIR}/gromacs.log
NSTEPS=10000
NTOMP=1

echo "downloading case $2 from ${package}..."
wget -q "${STORAGE_ENDPOINT}/gromacs/${package}?${SAS_KEY}" -O ${package}
tar xvf ${package} -C $SHARED_DIR

source /opt/intel/impi/*/bin64/mpivars.sh
if [ "$INTERCONNECT" == "ib" ]; then
    export I_MPI_FABRICS=shm:dapl
    export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
    export I_MPI_DYNAMIC_CONNECTION=0
    export I_MPI_FALLBACK_DEVICE=0
    export I_MPI_DAPL_TRANSLATION_CACHE=0
else
    export I_MPI_FABRICS=shm:tcp
fi
export I_MPI_STATS=ipm

mpirun \
    -ppn $PPN -np $CORES --hostfile $MPI_HOSTFILE \
    ${INSTALL_DIR}/bin/gmx_mpi mdrun \
    -s $SHARED_DIR/${casename} -maxh 1.00 -resethway -noconfout -nsteps ${NSTEPS} -g ${OUTPUT_FILE} -ntomp ${NTOMP} -pin on -cpt -1


if [ -f "${OUTPUT_FILE}" ]; then
    total_wall_time=$(grep "Time:" ${OUTPUT_FILE} | awk -F ' ' '{print $3}')
    total_cpu_time=$(grep "Time:" ${OUTPUT_FILE} | awk -F ' ' '{print $2}')
    ns_per_day=$(grep "Performance:" ${OUTPUT_FILE} | awk -F ' ' '{print $2}')
    hour_per_ns=$(grep "Performance:" ${OUTPUT_FILE} | awk -F ' ' '{print $3}')

    cat <<EOF >$APPLICATION.json
    {
    "version": "$GMX_VERSION",
    "model": "$casename",
    "total_wall_time": $total_wall_time,
    "total_cpu_time": $total_cpu_time,
    "ns_per_day": $ns_per_day,
    "hour_per_ns": $hour_per_ns,
    "nsteps": $NSTEPS,
    "ntomp": $NTOMP
    }
EOF
fi
