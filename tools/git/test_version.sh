#!/usr/bin/env bash

docker run --rm -it "${1}" --version | sed -e 's/git version //'