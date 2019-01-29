# Add application specific settings
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"

if [ ! -d "/opt/azcopy" ]; then
    mkdir /opt/azcopy
    cd /opt/azcopy
    wget "https://aka.ms/downloadazcopy-v10-linux" -O azcopy.tgz
    tar xvf azcopy.tgz --strip-components=1
fi

