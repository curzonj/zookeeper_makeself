#!/bin/bash

set -e
set -x

export LC_ALL=C

apt-get -y clean

echo -n "pwd" > /command_line
