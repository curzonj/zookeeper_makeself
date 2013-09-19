#!/bin/sh

set -x

umount ./proc

kill -9 \$(cat $CGROUP/tasks | grep -v $MYSELF)
rmdir $CGROUP
