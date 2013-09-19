#!/bin/bash

set -e
set -x

# Makeself uses a 077 umask by default
umask 022

# NOTE this script runs in the wider context, the chroot
# doesnt' happen until runit is started on the last line.

echo "$@" > opt/exhibitor_run/cmdline

# makeself puts mode 700 on this directory by default which causes
# problems for running things as non root users
chmod 755 .

cp /etc/resolv.conf etc/

# The cgroup makes it easy to keep track of spawned processes
MYSELF=$$
CGROUP=/sys/fs/cgroup/cpu/zookeeper_$MYSELF
mkdir $CGROUP
echo 0 > $CGROUP/tasks

trap "kill -9 \$(cat $CGROUP/tasks | grep -v $MYSELF); umount ./proc" 0 1 2 3 13 15
mount -t proc proc ./proc

touch opt/zookeeper-3.4.5/zookeeper.out
chown nobody:nogroup opt/zookeeper-3.4.5/zookeeper.out

# Makeself tarball doesn't seem to respect ownership even as root
chown -R nobody:nogroup opt/{exhibitor_run,zookeeper_snapshot,zookeeper_transactions}
chown -R nobody:nogroup opt/zookeeper-3.4.5/conf

# Don't `exec` this because we need our traps to function
chroot ./ runsvdir -P /service
