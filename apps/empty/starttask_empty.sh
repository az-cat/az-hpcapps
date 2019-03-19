# Add application specific settings
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"

if [ "$VMSIZE" == "standard_hb60rs" ]
then
    # Install OpenMPI
    if [ ! -d "/opt/openmpi" ]; then
        echo "download OpenMPI 4.0.x package"
        pushd /opt
        PACKAGE=openmpi-4.0.0.tgz
        wget -q "${HPC_APPS_STORAGE_ENDPOINT}/openmpi/${PACKAGE}?${HPC_APPS_SASKEY}" -O - | tar zx

        yum install -y hwloc

        popd
    fi
fi
