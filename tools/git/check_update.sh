#!/usr/bin/env bash

alpine-version --arch x86_64 git | jq -r '.[0].version' | sed -e 's;-[^-]*$;;'