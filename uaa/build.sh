#!/bin/bash

echo "**********************************************"
echo "            build gnatsd                      "
echo "**********************************************"

homedir=/home/vcap
export PATH=/var/vcap/packages/ruby/bin:$PATH
export RUBY_PATH=/var/vcap/packages/ruby:$RUBY_PATH

#----------------------- git init -----------------------
if [ ! -d /var/vcap ]; then
    sudo mkdir -p /var/vcap
    sudo chown vcap:vcap /var/vcap
fi

if [ ! -d $homedir/cf-release ]; then
    echo "No cf-release dir exit,Please updtae first." >> errors.txt
    exit 1
fi

pushd $homedir/cf-release
cd src/uaa
git submodule update --init
popd

mkdir -p /var/vcap/packages/uaa
mkdir -p /home/vcap/uaa

BUILD_DIR=/home/vcap/build
mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/uaa

pushd $BUILD_DIR

if [ ! -d $BUILD_DIR/cf-registrar-bundle-for-identity ]; then
    cp -a $homedir/cf-release/src/cf-registrar-bundle-for-identity $BUILD_DIR
fi

if [ ! -f $BUILD_DIR/maven/apache-maven-3.1.1-bin.tar.gz ]; then
    mkdir -p $BUILD_DIR/maven/
    wget http://192.168.201.128:9090/packages/maven/apache-maven-3.1.1-bin.tar.gz
    mv apache-maven-3.1.1-bin.tar.gz $BUILD_DIR/maven/apache-maven-3.1.1-bin.tar.gz
fi

if [ ! -f $BUILD_DIR/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz ]; then
    wget http://192.168.201.128:9090/packages/uaa/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
fi

if [ ! -f $BUILD_DIR/openjdk-1.7.0_51.tar.gz ]; then
    wget http://192.168.201.128:9090/packages/uaa/openjdk-1.7.0_51.tar.gz
fi

if [ ! -f $BUILD_DIR/apache-tomcat-7.0.52.tar.gz ]; then
    wget http://192.168.201.128:9090/packages/uaa/apache-tomcat-7.0.52.tar.gz
fi

if [ ! -f ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war ]; then
    wget http://192.168.201.128:9090/packages/uaa/cloudfoundry-identity-varz-1.0.2.war
    mv cloudfoundry-identity-varz-1.0.2.war ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war
fi

popd

#-------------------------- uaa prepare -----------------------------
#registrar information
cd ${BUILD_DIR}/cf-registrar-bundle-for-identity

bundle package --all

#unpack Maven
cd ${BUILD_DIR}
tar zxvf maven/apache-maven-3.1.1-bin.tar.gz
export MAVEN_HOME=${BUILD_DIR}/apache-maven-3.1.1

# Make sure we can see uname
export PATH=$PATH:/bin:/usr/bin

#unpack Java - we support Mac OS 64bit and Linux 64bit otherwise we require JAVA_HOME to point to JDK
if [ `uname` = "Darwin" ]; then
  mkdir -p java
  cd java
  tar zxvf ../uaa/openjdk-1.7.0-u40-unofficial-macosx-x86_64-bundle.tgz --exclude="._*"
  export JAVA_HOME=${BUILD_DIR}/java/Contents/Home
elif [ `uname` = "Linux" ]; then
  mkdir -p java
  cd java
  tar zxvf $BUILD_DIR/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
  export JAVA_HOME=${BUILD_DIR}/java
else
  if [ ! -d $JAVA_HOME ]; then
    echo "JAVA_HOME properly set is required for non Linux/Darwin builds."
    exit 1
  fi	
fi

#setup Java and Maven paths
export PATH=$MAVEN_HOME/bin:$JAVA_HOME/bin:$PATH

#Maven options for building
export MAVEN_OPTS='-Xmx1g -XX:MaxPermSize=512m'

#build cloud foundry war
cd $homedir/cf-release/src/uaa
mvn clean
mvn -U -e -B package -DskipTests=true -Ddot.git.directory=/home/vcap/cf-release/src/uaa/.git
cp uaa/target/cloudfoundry-identity-uaa-*.war ${BUILD_DIR}/uaa/cloudfoundry-identity-uaa.war

#remove build resources
mvn clean

#clean up - so we don't transfer files we don't need
#cd ${BUILD_DIR}
#rm -rf apache-maven*
#rm -rf java
#rm -rf maven
#rm -rf uaa/openjdk-1.7.0-u40-unofficial-linux-amd64.tgz
#rm -rf uaa/openjdk-1.7.0-u40-unofficial-macosx-x86_64-bundle.tgz

#--------------------------------- uaa installing.....---------------

pushd /var/vcap/packages

mkdir -p /var/vcap/packages/uaa

cd /var/vcap/packages/uaa
rm -fr /var/vcap/packages/uaa/*

mkdir -p  jdk
tar zxvf $BUILD_DIR/openjdk-1.7.0_51.tar.gz -C jdk

cd /var/vcap/packages/uaa

tar zxvf $BUILD_DIR/apache-tomcat-7.0.52.tar.gz

mv apache-tomcat-7.0.52 tomcat

cd tomcat
rm -rf webapps/*
cp -a ${BUILD_DIR}/uaa/cloudfoundry-identity-uaa.war webapps/ROOT.war
cp -a ${BUILD_DIR}/uaa/cloudfoundry-identity-varz-1.0.2.war webapps/varz.war

cd /var/vcap/packages/uaa
cp -a ${BUILD_DIR}/cf-registrar-bundle-for-identity vcap-common
cd vcap-common
#/var/vcap/packages/ruby/bin/bundle package --all
/var/vcap/packages/ruby/bin/bundle install --binstubs --deployment --local --without=development test

pushd /var/vcap/packages
tar -zcvf uaa.tar.gz uaa

curl -F "action=/upload/build" -F "uploadfile=@uaa.tar.gz" http://192.168.201.128:9090/upload/build

rm -fr uaa.tar.gz
popd

popd

echo "UAA build success!!"
