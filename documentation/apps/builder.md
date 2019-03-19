### Builder

- Application name = **builder**

This specific application is used to build OSS components and upload them in your application blob storage endpoint.
By default GCC 7.x, git are installed in the image.

#### Application binaries and data

By default the working directory is used for the build directory and to keep binaries. Use azcopy to upload the packaged binaries into your blob storage. The **HPC_APPS_STORAGE_ENDPOINT** will contains the endpoint value, and you must create a write SAS_KEY to the **apps** container and pass it as an argument to your build script.


#### Setup Steps
```
    ./build_image.sh -a builder
    ./create_cluster.sh -a builder
```

Create a write sas key for your apps container in your storage account.

#### Running Builders

The available build scripts are : 
    
 - run_build_openpmpi.sh : To build UCX and OpenMPI.
 - run_build_hplamd.sh   : To build AMD BLIS and HPL 2.3 for BLIS and OpenMPI. Binary stored into apps/hpl blob directory
 - run_build_stream_epyc.sh : To build Standard STREAM using GCC. Not an optimized version. Binary stored into apps/bench blob directory.
 - run_build_stream_skylake.sh : To build Standard STREAM using GCC. Not an optimized version. Binary stored into apps/bench blob directory


Example on how to run the build_openmpi  :

```
    ./run_app.sh \
        -a builder \
        -s build_openmpi \
        -n 1 -p 1 \
        -x "write_sas_key_value"
```


#### Results

