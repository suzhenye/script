#!/bin/bash

export GOROOT=/home/vcap/go
export GOARCH=amd64
export GOBIN=$GOROOT/bin
export PATH=.:$PATH:$GOBIN
export GOOS=linux
export PATH=/home/vcap/etcdctl/bin:$PATH
export GOPATH=/home/vcap/etcdctl

pushd /home/vcap/

git clone https://github.com/coreos/etcdctl
cd etcdctl
git checkout 6dcd7c2e57
git submodule update --init

popd

#-------------------- etcdctl install -----------------------

pushd /home/vcap/etcdctl

./build

popd

