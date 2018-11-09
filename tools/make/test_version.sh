#!/usr/bin/env bash

docker run --rm -it sledgehammers/make make --version | grep "GNU Make" | sed -e 's/GNU Make //g'