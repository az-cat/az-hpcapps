### Empty

- Application name = **empty**

This image is an empty baseline that includes a set of diagnostics scripts for checking :
- network latency and bandwith using Intel IMB-MPI1 pingpong test
- memory bandwidth using STREAM 

#### Application binaries and data

Intel MPI is installed by default and contains the IMP-MPI1 benchmark.

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


Example on how to run the ring ping pong test over 16 nodes :

```
    ./run_app.sh \
        -a empty \
        -s ring_pingpong.sh \
        -n 16 -p 1 
```


#### Results

