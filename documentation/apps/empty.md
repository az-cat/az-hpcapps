### Empty

- Application name = **empty**

This image is an empty baseline that includes a set of diagnostics scripts for checking :
- network latency and bandwith using Intel IMB-MPI1 pingpong test
- memory bandwidth using STREAM 

#### Application binaries and data

Intel MPI is installed by default and contains the IMP-MPI1 benchmark.

For STREAM :
- for AMD   : run the **build_stream_epyc** case in the **builder** application to build and upload streams in your storage account
- for Intel : Download the MLC tool from the Intel website and upload the mlc_v3.6.tgz into _apps/bench/mlc_v3.6.tgz_ blob of your storage account

For HPL :
- for AMD : run the **build_hplamd** case in the **builder** application to build Linpack and store it in your storage account

#### Setup Steps
```
    ./build_image.sh -a empty
    ./create_cluster.sh -a empty
```

#### Running Benchmarks

The available benchmark scripts are : 
    
 - run_pingpong.sh : to test latency and bandwidth between 2 nodes, results are in **stdout.txt**.
 - run_ring_pingpong.sh : to test latency and bandwdith across a set of nodes in a ring way (1 to 1 connection only). The results are in the **OUTPUT/latency.txt** and **OUTPUT/bandwidth.txt** files.
 - run_all_pingpong.sh : to test latency and bandwidth across a set of nodes, testing all possible connections.  The results are in the **OUTPUT/latency.txt** and **OUTPUT/bandwidth.txt** files.
 - run_allreduce.sh : To test MPI_Allreduce collective operations across a set of nodes for 8 and 16 bytes messages. The results are stored into the **OUTPUT/allreduce.log** file.
 - run_stream.sh : To run the standard Stream memory benchmark. 
 - run_single_hpl_epyc.sh : To run single node HPL on EPYC machines. input parameter needed is the memory size in GB. 


Example on how to run the ring ping pong test over 16 nodes :

```
    ./run_app.sh \
        -a empty \
        -s ring_pingpong.sh \
        -n 16 -p 1 
```

For running single HPL using 64 GB of memory for the problem size :

```
    ./run_app.sh \
        -a empty \
        -s single_hpl_epyc.sh \
        -n 1 -p 1 -x 64
```


#### Results

