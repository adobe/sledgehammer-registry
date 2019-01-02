#!/usr/bin/env bash

# Copyright 2018 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it. If you have received this file from a source other than Adobe,
# then your use, modification, or distribution of it requires the prior
# written permission of Adobe.

# The alpine version always returns something like jq-master-v3.7.0-4757-gc31a4d0fd5
# which is bad...
# lets hope they fix it
# and fake it for the moment...

sed -e 's;-[^-]*$;;' < "./VERSION"