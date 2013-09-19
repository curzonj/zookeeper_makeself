#!/bin/bash

set -e
set -x

export LC_ALL=C


cat > /etc/apt/sources.list <<EOS
deb http://archive.ubuntu.com/ubuntu/ raring main restricted universe
deb http://archive.ubuntu.com/ubuntu/ raring-updates main restricted universe
deb http://archive.ubuntu.com/ubuntu/ raring-security main restricted
EOS

## TODO java requires /proc to be mounted in order to run, but that could be
## fixed the the path to all it's libraries were added to /etc/ld.so.conf.d/

apt-get update
apt-get -y install wget runit openjdk-7-jdk openjdk-7-jre-headless

# Because runit package gets started on install
service runsvdir stop || true

mkdir -p /service/exhibitor

cat > /service/exhibitor/run <<EOS
#!/bin/bash

java -jar /opt/exhibitor-1.5.0.jar -c file
EOS
chmod +x /service/exhibitor/run

function download() {
  path=$1
  url=$2
  file=$(basename $2)

  [ -f $path/$file ] || wget -O$path/$file $url
}

mkdir -p /opt/exhibitor

download /opt/exhibitor http://services.gradle.org/distributions/gradle-1.5-bin.zip
download /opt/exhibitor https://raw.github.com/Netflix/exhibitor/master/exhibitor-standalone/src/main/resources/buildscripts/standalone/gradle/build.gradle

if [ ! -f /opt/exhibitor-1.5.0.jar ]; then
  (
    cd /opt/exhibitor
    unzip gradle-1.5-bin.zip
    PATH=/opt/exhibitor/gradle-1.5/bin:$PATH

    gradle jar
    mv /opt/exhibitor/build/libs/exhibitor-1.5.0.jar /opt
    #rm -rf /opt/exhibitor
  )
fi

#download /opt /opt/zookeeper.jar http://apache.osuosl.org/zookeeper/zookeeper-3.4.5/zookeeper-3.4.5.tar.gz

apt-get -y clean

echo -n "pwd" > /command_line
