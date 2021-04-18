#!/bin/bash
# ############################################################################################
# File: ........: InstallUtilities.sh
# Language .....: bash
# Author .......: Sacha Dubois, VMware
# Description ..: Tanzu Demo Hub - Installation utilities on Jump Host
# ############################################################################################

#https://docs.python-guide.org/dev/virtualenvs/

export PIVNET_TOKEN=$1
#LOC=$(locale 2>/dev/null | grep LC_CTYPE | sed 's/"//g' | awk -F= '{ print $2 }') 
export LC_ALL=en_US.UTF-8
#export LC_ALL="$LOC"

[ -d /usr/share/X11/locale/en_US.UTF-8 ] && export LC_ALL=en_US.UTF-8

installSnap() {
  PKG=$1
  OPT=$2
  
  echo "=> Install Package ($PKG)"
  snap list $PKG > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    cnt=0
    snap install $PKG $OPT > /dev/null 2>&1; ret=$?
    while [ $ret -ne 0 -a $cnt -lt 3 ]; do
      snap install $PKG $OPT> /dev/null 2>&1; ret=$?
      sleep 30
      let cnt=cnt+1
    done
    
    if [ $ret -ne 0 ]; then
      echo "ERROR: failed to install package $PKG"
      echo "       => snap install $PKG $PKG"
      exit 1
    fi
  fi
}


installPackage() {
  PKG=$1

  echo "=> Install Package ($PKG)"
  dpkg -s $PKG > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    apt install $PKG -y > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "ERROR: failed to install package $PKG"
      echo "       => apt install $PKG -y"
      exit 1
    fi
  fi
}

sudo 2>/dev/null  mkdir -p /usr/local /usr/local/bin

echo "Install Software on Jumphost"
installPackage snapd
installPackage curl

if [ ! -x /usr/bin/az ]; then 
  # Download and install the Microsoft signing key
  curl -qsL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor 2>/dev/null | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

  # Add the Azure CLI software repository (skip this step on ARM64 Linux distributions)
  AZ_REPO=$(lsb_release -cs)
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list > /dev/null
  apt-get update > /dev/null

  installPackage azure-cli

  #echo "=> Install AZ CLI"
  #curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash > /dev/null 2>&1
fi
exit 1

if [ ! -x /usr/bin/certbot ]; then 
  snap install core; sudo snap refresh core
  snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
fi
 
echo "=> Install Certbot Plugin certbot-dns-route53"
snap set certbot trust-plugin-with-root=ok
installPackage zip
installSnap certbot-dns-route53
echo "   ---------------------------------------------------------------------------------------------------------------"
certbot plugins 2>/dev/null | \
   awk 'BEGIN{h="Certbot Plugins:"}{ if($1 == "*"){ a=$2 }; if ($1 == "Description:"){ printf("  %-17s %-12s %s\n",h,a,$0);h="" }}' | \
   sed 's/Description://g'
echo "   ---------------------------------------------------------------------------------------------------------------"

# --- INSTALL PACKAGTES ---
installPackage zip
installPackage awscli
installSnap kubectl --classic
installPackage jq

#if [ ! -x /usr/bin/zipinfo ]; then
#  echo "=> Install ZIP"
#  installPackage zip
#fi

#if [ ! -x /usr/bin/aws ]; then 
#  installPackage awscli
#    
#  #echo "=> Install AWS CLI"
#  #curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" 2>/dev/null
#  #unzip -q awscli-bundle.zip 
#  #./awscli-bundle/install -i /usr/local/aws -b /usr/bin/aws
#fi

#if [ ! -x /usr/bin/kubectl ]; then 
#  installSnap kubectl --classic
#
#  #echo "=> Install Kubectl"
#  #curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" > /dev/null 2>&1
#  #chmod +x ./kubectl
#  #mv ./kubectl /usr/local/bin/kubectl
#fi

#if [ ! -x /usr/bin/jq ]; then 
#  echo "=> Install JQ"
#  installPackage jq
#fi

if [ ! -x /usr/local/bin/pivnet ]; then 
  echo "=> Installing Pivnet"
  wget -q -O pivnet github.com/pivotal-cf/pivnet-cli/releases/download/v0.0.55/pivnet-linux-amd64-0.0.55 && chmod a+x pivnet && sudo mv pivnet /usr/local/bin
fi

if [ ! -x /snap/bin/helm ]; then 
  echo "=> Installing Helm Utility"
  installPackage helm --classic
  [ ! -s /usr/bin/helm ] && sudo ln -s /snap/bin/helm /usr/bin/helm
fi

if [ ! -x /snap/bin/yq ]; then
  wget -q https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
fi

touch  /jump_software_installed
exit 0

