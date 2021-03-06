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
apt-get --no-install-recommends -y install wget runit openjdk-7-jdk openjdk-7-jre-headless moreutils unzip 

# Because runit package gets started on install
service runsvdir stop || true

mkdir -p /service/exhibitor
mkdir -p /opt/exhibitor_run
mkdir -p /opt/zookeeper_snapshot
mkdir -p /opt/zookeeper_transactions


cat > /opt/exhibitor_run/exhibitor.defaultconfig <<EOS
zoo-cfg-extra=tickTime\=2000&initLimit\=5&syncLimit\=2
check-ms=3000
zookeeper-install-directory=/opt/zookeeper-3.4.5
zookeeper-data-directory=/opt/zookeeper_snapshot
zookeeper-log-directory=/opt/zookeeper_transactions
client-port=2181
connect-port=2888
election-port=3888
auto-manage-instances=1
auto-manage-instances-settling-period-ms=5000
observer-threshold=4
EOS

## runit service script
cat > /service/exhibitor/run <<"EOS"
#!/bin/bash
IPV4=$(ifdata -pa eth0)

exec chpst -u nobody /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java -jar /opt/exhibitor-1.5.0.jar --hostname $IPV4 --prefspath /opt/exhibitor_run/user.prefs --defaultconfig /opt/exhibitor_run/exhibitor.defaultconfig $(cat /opt/exhibitor_run/cmdline)
EOS
chmod +x /service/exhibitor/run

mkdir -p /service/exhibitor/log
mkdir -p /var/log/exhibitor

## runit logging script
# TODO change to remote syslogging and configure destination with cmdline
# options to the run.sh script. We also need forward zookeeper.out to
# remote logging.
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


# TODO we could build this jar seperately and put it in object storage
[ -f /opt/exhibitor-1.5.0.jar ] || (
  mkdir -p /opt/exhibitor

  download /opt/exhibitor http://services.gradle.org/distributions/gradle-1.5-bin.zip
  download /opt/exhibitor https://raw.github.com/Netflix/exhibitor/master/exhibitor-standalone/src/main/resources/buildscripts/standalone/gradle/build.gradle

  cd /opt/exhibitor
  unzip gradle-1.5-bin.zip
  PATH=/opt/exhibitor/gradle-1.5/bin:$PATH

  gradle jar
  mv /opt/exhibitor/build/libs/exhibitor-1.5.0.jar /opt
  rm -rf /opt/exhibitor
)

[ -d /opt/zookeeper-3.4.5 ] || (
  download /opt http://apache.osuosl.org/zookeeper/zookeeper-3.4.5/zookeeper-3.4.5.tar.gz
  tar -xzf /opt/zookeeper-3.4.5.tar.gz -C /opt
  rm /opt/zookeeper-3.4.5.tar.gz
)

apt-get -y clean

cp run.sh cleanup.sh /
chmod +x /run.sh /cleanup.sh

echo -n "./run.sh" > /command_line
