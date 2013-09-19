#!/bin/bash

set -e
set -x

export LC_ALL=C


cat > /etc/apt/sources.list <<EOS
deb http://archive.ubuntu.com/ubuntu/ raring main restricted universe
deb http://archive.ubuntu.com/ubuntu/ raring-updates main restricted universe
deb http://archive.ubuntu.com/ubuntu/ raring-security main restricted
EOS

apt-get update
apt-get -y install wget runit openjdk-7-jdk openjdk-7-jre-headless moreutils unzip

# Because runit package gets started on install
service runsvdir stop || true

mkdir -p /service/exhibitor
mkdir -p /opt/exhibitor_run
mkdir -p /opt/zookeeper_snapshot
mkdir -p /opt/zookeeper_transactions

chown nobody:nogroup /opt/{exhibitor_run,zookeeper_snapshot,zookeeper_transactions}

cat > /opt/exhibitor_run/exhibitor.defaultconfig <<EOS
zoo-cfg-extra=tickTime\=2000
check-ms=3000
zookeeper-install-directory=/opt/zookeeper-3.4.5
zookeeper-data-directory=/opt/zookeeper_snapshot
zookeeper-log-directory=/opt/zookeeper_transactions
client-port=2181
connect-port=2888
election-port=3888
EOS

## runit service script
cat > /service/exhibitor/run <<"EOS"
#!/bin/bash
IPV4=$(ifdata -pa eth0)

exec chpst -u nobody:nogroup java -jar /opt/exhibitor-1.5.0.jar -c file --hostname $IPV4 --fsconfigdir /opt/exhibitor_run  --prefspath /opt/exhibitor_run/user.prefs --defaultconfig /opt/exhibitor_run/exhibitor.defaultconfig
EOS
chmod +x /service/exhibitor/run

mkdir -p /service/exhibitor/log
mkdir -p /var/log/exhibitor

## runit logging script
cat > /service/exhibitor/log/run <<"EOS"
#!/bin/bash

exec svlogd -t /var/log/exhibitor
EOS

chmod +x /service/exhibitor/log/run

function download() {
  path=$1
  url=$2
  file=$(basename $2)

  [ -f $path/$file ] || wget -O$path/$file $url
}

mkdir -p /opt/exhibitor

# TODO we could build this jar seperately and put it in object storage
download /opt/exhibitor http://services.gradle.org/distributions/gradle-1.5-bin.zip
download /opt/exhibitor https://raw.github.com/Netflix/exhibitor/master/exhibitor-standalone/src/main/resources/buildscripts/standalone/gradle/build.gradle

if [ ! -f /opt/exhibitor-1.5.0.jar ]; then
  (
    cd /opt/exhibitor
    unzip gradle-1.5-bin.zip
    PATH=/opt/exhibitor/gradle-1.5/bin:$PATH

    gradle jar
    mv /opt/exhibitor/build/libs/exhibitor-1.5.0.jar /opt
    rm -rf /opt/exhibitor
  )
fi

download /opt http://apache.osuosl.org/zookeeper/zookeeper-3.4.5/zookeeper-3.4.5.tar.gz
[ -d /opt/zookeeper-3.4.5 ] || tar -xzf /opt/zookeeper-3.4.5.tar.gz -C /opt

chown -R nobody:nogroup /opt/zookeeper-3.4.5/conf

apt-get -y clean

cat > /init <<"EOS"
#!/bin/bash

# The cgroup makes it easy to keep track of spawned processes
CGROUP=/sys/fs/cgroup/cpu/zookeeper_$$
mkdir CGROUP
echo 0 > $CGROUP/tasks

mount -t proc proc ./proc
exec chroot ./ runsvdir -P /service
EOS

chmod +x /init

echo -n "./init" > /command_line
