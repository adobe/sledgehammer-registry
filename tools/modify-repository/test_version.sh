#!/usr/bin/env bash

# This simple script has no real version....
sed -e 's;-[^-]*$;;' < "./VERSION"
# docker run --rm -it "${1}" --version | sed -e 's/git version //'