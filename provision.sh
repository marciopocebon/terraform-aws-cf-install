#!/bin/bash

# fail immediately on error
set -e

# echo "$0 $*" > ~/provision.log

fail() {
  echo "$*" >&2
  exit 1
}

# Variables passed in from terraform, see aws-vpc.tf, the "remote-exec" provisioner
AWS_KEY_ID=${1}
AWS_ACCESS_KEY=${2}
AWS_REGION=${3}
AWS_KEY=${4}
SUBNET_ID=${5}
SUBNET_PREFIX=${6}
AVAILABILITY_ZONE=${7}
ELASTIC_IP=${8}
AWS_SECURITY_GROUP=${9}
IPMASK=${10}


cd $HOME
(("$?" == "0")) ||
  fail "Could not find HOME folder, terminating install."


if [[ $DEBUG == "true" ]]; then
  set -x
fi

# Prepare the jumpbox to be able to install ruby and git-based bosh and cf repos

    sudo apt-get update -yq
    sudo apt-get install -yq aptitude
    sudo aptitude -yq install build-essential vim-nox git unzip tree \
      libxslt-dev libxslt1.1 libxslt1-dev libxml2 libxml2-dev \
      libpq-dev libmysqlclient-dev libsqlite3-dev \
      g++ gcc make libc6-dev libreadline6-dev zlib1g-dev libssl-dev libyaml-dev \
      libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake \
      libtool bison pkg-config libffi-dev cmake  openssl git zlibc

# Install RVM

if [[ ! -d "$HOME/.rvm" ]]; then
  cd $HOME
  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  curl -sSL https://get.rvm.io | bash -s stable
fi

cd $HOME

if [[ ! "$(ls -A $HOME/.rvm/environments)" ]]; then
  ~/.rvm/bin/rvm install ruby-2.1
fi

if [[ ! -d "$HOME/.rvm/environments/default" ]]; then
  ~/.rvm/bin/rvm alias create default 2.1
fi

source ~/.rvm/environments/default
source ~/.rvm/scripts/rvm

# This volume is created using terraform in aws-bosh.tf
if [[ ! -d "$HOME/workspace" ]]; then
  sudo /sbin/mkfs.ext4 /dev/xvdc
  sudo /sbin/e2label /dev/xvdc workspace
  echo 'LABEL=workspace /home/ubuntu/workspace ext4 defaults,discard 0 0' | sudo tee -a /etc/fstab
  mkdir -p /home/ubuntu/workspace
  sudo mount -a
  sudo chown -R ubuntu:ubuntu /home/ubuntu/workspace
fi

# As long as we have a large volume to work with, we'll move /tmp over there
# You can always use a bigger /tmp
if [[ ! -d "$HOME/workspace/tmp" ]]; then
  sudo rsync -avq /tmp/ /home/ubuntu/workspace/tmp/
fi

if ! [[ -L "/tmp" && -d "/tmp" ]]; then
  sudo rm -fR /tmp
  sudo ln -s /home/ubuntu/workspace/tmp /tmp
fi

echo "Install Traveling CF"
if [[ "$(cat $HOME/.bashrc | grep 'export PATH=$PATH:$HOME/bin/traveling-cf-admin')" == "" ]]; then
  curl -s https://raw.githubusercontent.com/cloudfoundry-community/traveling-cf-admin/master/scripts/installer | bash
  echo 'export PATH=$PATH:$HOME/bin/traveling-cf-admin' >> $HOME/.bashrc
  source $HOME/.bashrc
fi

if [[ ! -f "/usr/local/bin/spiff" ]]; then
  curl -sOL https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.3/spiff_linux_amd64.zip
  unzip spiff_linux_amd64.zip
  sudo mv ./spiff /usr/local/bin/spiff
  rm spiff_linux_amd64.zip
fi

echo "Install bosh init"
gem install bosh_cli

echo "Install bosh init"
sudo wget https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-0.0.70-linux-amd64 -P /usr/local/bin
sudo mv /usr/local/bin/bosh-init* /usr/local/bin/bosh-init
sudo chmod +x /usr/local/bin/bosh-init


echo "Prepare bosh init"
git clone http://github.com/s-matyukevich/bosh-micro-workspace /home/ubuntu/workspace/bosh-init
sudo mv /home/ubuntu/bosh.pem /home/ubuntu/workspace/bosh-init/bosh.pem

# This is some hackwork to get the configs right. Could be changed in the future
/bin/sed -i \
  -e "s/AWS_KEY_ID/${AWS_KEY_ID}/g" \
  -e "s/AWS_ACCESS_KEY/${AWS_ACCESS_KEY}/g" \
  -e "s/AWS_REGION/${AWS_REGION}/g" \
  -e "s/AWS_KEY/${AWS_KEY}/g" \
  -e "s/SUBNET_ID/${SUBNET_ID}/g" \
  -e "s/SUBNET_PREFIX/${SUBNET_PREFIX}/g" \
  -e "s/AVAILABILITY_ZONE/${AVAILABILITY_ZONE}/g" \
  -e "s/ELASTIC_IP/${ELASTIC_IP}/g" \
  -e "s/AWS_SECURITY_GROUP/${AWS_SECURITY_GROUP}/g" \
  -e "s/IPMASK/${IPMASK}/g" \
  workspace/bosh-init/bosh.yml

echo "Install dotfiles"
git clone --recursive http://github.com/s-matyukevich/dotfiles /home/ubuntu/dotfiles
/home/ubuntu/dotfiles/install-on-ubuntu-cloud.sh


echo "Provision script completed..."
exit 0
