#!/bin/bash
fluent_case=$1

echo "downloading case ${fluent_case}..."
wget "${STORAGE_ENDPOINT}/ansys-fluent-benchmarks/${fluent_case}.tar?${SAS_KEY}" -O - | tar x

source /opt/intel/impi/*/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT

export I_MPI_FABRICS=shm:dapl
export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
export I_MPI_DYNAMIC_CONNECTION=0
export I_MPI_FALLBACK_DEVICE=0

cat <<EOF >run_fluent.jou
(set! checkpoint/check-filename "./SaveData")
(set! checkpoint/exit-filename "./StopFluent")
/file/set-batch-options
no
yes
no
f r-c-d bench/fluent/v6/${fluent_case}/cas_dat/${fluent_case}.cas.gz
par lat
par band
s iterate 100
par timer usage
exit y
EOF

export PATH=/opt/ansys_inc/v182/fluent/bin:$PATH
export ANSYSLMD_LICENSE_FILE=1055@${LICENSE_SERVER}

fluent 3d -g -mpi=intel -pib.dapl -pcheck -env -ssh -t${CORES} -cnf="$MPI_HOSTLIST" -i run_fluent.jou

