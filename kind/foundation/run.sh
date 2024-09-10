#!/bin/bash
set -ex

docker build .
docker run -it --rm --net=host -v /run:/run --privileged $(docker build -q .)
