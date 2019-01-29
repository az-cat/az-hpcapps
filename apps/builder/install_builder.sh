#!/bin/bash
setup_gcc()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing latest GCC 7.x                   *" 
    echo "*                                                       *"
    echo "*********************************************************"

    yum install centos-release-scl-rh -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc-c++ -y
    yum --enablerepo=centos-sclo-rh-testing install devtoolset-7-gcc-gfortran -y  

}

setup_gcc

yum install -y git


