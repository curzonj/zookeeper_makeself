#!/bin/bash

set -e
set -x

export LC_ALL=C

dpkg -i chef*.deb
/opt/chef/bin/chef-solo -c `pwd`/chef_solo.rb -l debug

apt-get -y purge chef
apt-get -y clean

echo -n "pwd" > /command_line
