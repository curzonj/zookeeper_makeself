#!/bin/sh
# We use sh instead of bash to be more portable

set -e
set -x

# Makeself uses a 077 umask by default
umask 022

# NOTE this script runs in the wider context, the chroot
# doesnt' happen until runit is started on the last line.

echo "$@" > opt/exhibitor_run/cmdline

grab_file=0
for element in $@
do
  case $element in
    --s3credentials)
      grab_file=1
      ;;
    --*)
      ;;
    *)
      ## We need to bring the file into the chroot at an
      ## absolute path and file the commandline
      if [ $grab_file -eq 1 ]; then
        grab_file=0

        dir=$(dirname $element)
        mkdir -p $dir
        cp $element opt/exhibitor_run/s3credentials
        sed "s@$element@/opt/exhibitor_run/s3credentials@g" opt/exhibitor_run/cmdline > opt/exhibitor_run/cmdline.new
        mv opt/exhibitor_run/cmdline.new opt/exhibitor_run/cmdline
      fi
      ;;
  esac
done

# makeself puts mode 700 on this directory by default which causes
# problems for running things as non root users
chmod 755 .

cp /etc/resolv.conf etc/

# The cgroup makes it easy to keep track of spawned processes
MYSELF=$$
CGROUP=/sys/fs/cgroup/cpu/zookeeper_$MYSELF

if [ -d /sys/fs/cgroup/cpu ]; then
  mkdir $CGROUP
  echo 0 > $CGROUP/tasks
fi

touch opt/zookeeper-3.4.5/zookeeper.out
chown nobody:nogroup opt/zookeeper-3.4.5/zookeeper.out

# Makeself tarball doesn't seem to respect ownership even as root
chown -R nobody:nogroup opt/exhibitor_run
chown -R nobody:nogroup opt/zookeeper_snapshot
chown -R nobody:nogroup opt/zookeeper_transactions
chown -R nobody:nogroup opt/zookeeper-3.4.5/conf

SOURCE_DIR=`pwd`
trap "$SOURCE_DIR/cleanup.sh $MYSELF $CGROUP" 0 1 2 3 13 15
mount -t proc proc ./proc

# Don't `exec` this because we need our traps to function
chroot ./ runsvdir -P /service
