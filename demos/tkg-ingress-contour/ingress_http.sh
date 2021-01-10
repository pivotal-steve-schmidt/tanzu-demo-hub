#!/bin/bash
# ============================================================================================
# File: ........: ingress_http.sh
# Language .....: bash
# Author .......: Sacha Dubois, VMware
# --------------------------------------------------------------------------------------------
# Description ..: Deploy the TKG Management Cluster on Azure
# ============================================================================================

export TDH_TKGWC_NAME=tdh-1
export NAMESPACE="contour-ingress-demo"
export TANZU_DEMO_HUB=$(cd "$(pwd)/$(dirname $0)/../../"; pwd)
export TDHPATH=$(cd "$(pwd)/$(dirname $0)/../../"; pwd)
export TDHDEMO=${TDHPATH}/demos/$NAMESPACE
export DOMAIN=${AWS_HOSTED_DNS_DOMAIN}

listDeployments() {
  printf "%-30s %-8s %-15s %-20s %-5s %s\n" "DEPLOYMENT" "CLOUD" "REGION" "MGMT-CLUSTER" "PLAN" "CONFIGURATION"
  echo "----------------------------------------------------------------------------------------------------------------"

  for deployment in $(ls -1 ${TDHPATH}/deployments/tkgmc*.cfg); do
    PCF_TILE_PKS_VERSION=""
    PCF_TILE_PAS_VERSION=""

    . $deployment

    dep=$(basename $deployment)

    if [ "$PCF_TILE_PKS_VERSION" != "" ]; then
      TILE="PKS $PCF_TILE_PKS_VERSION"
    else
      TILE="PAS $PCF_TILE_PAS_VERSION"
    fi

    printf "%-30s %-8s %-15s %-20s %-5s %s\n" $dep $TDH_TKGMC_INFRASTRUCTURE $TDH_TKGMC_REGION $TDH_TKGMC_NAME \
           $TDH_TKGMC_PLAN "$TDH_TKGMC_CONFIG"
  done

  echo "----------------------------------------------------------------------------------------------------------------"
}

if [ -f $TANZU_DEMO_HUB/functions ]; then
  . $TANZU_DEMO_HUB/functions
else
  echo "ERROR: can ont find ${TANZU_DEMO_HUB}/functions"; exit 1
fi

# Created by /usr/local/bin/figlet
clear
echo '                  _____ _  ______   ___                                               '
echo '                 |_   _| |/ / ___| |_ _|_ __   __ _ _ __ ___  ___ ___                 '
echo '                   | | |   / |  _   | ||  _ \ / _  |  __/ _ \/ __/ __|                '
echo '                   | | |   \ |_| |  | || | | | (_| | | |  __/\__ \__ \                '
echo '                   |_| |_|\_\____| |___|_| |_|\__  |_|  \___||___/___/                '
echo '                                              |___/                                   '
echo '                                                                                      '
echo '          ----------------------------------------------------------------------------'
echo '              Contour Ingress Example with Domain and Context based Routing           '
echo '                               by Sacha Dubois, VMware Inc                            '
echo '          ----------------------------------------------------------------------------'
echo '                                                                                      '

# --- CHECK ENVIRONMENT VARIABLES ---
if [ -f ~/.tanzu-demo-hub.cfg ]; then
  . ~/.tanzu-demo-hub.cfg
fi

if [ "${TKG_CONFIG}" == "" ]; then
  echo "ERROR: environment variable TKG_CONFIG has not been set"; exit
fi

if [ "${KUBECONFIG}" == "" ]; then
  echo "ERROR: environment variable KUBECONFIG has not been set"; exit
fi

K8S_CONTEXT_CURRENT=$(kubectl config current-context)
if [ "${K8S_CONTEXT_CURRENT}" != "${TDH_TKGWC_NAME}-admin@${TDH_TKGWC_NAME}" ]; then 
  kubectl config use-context ${TDH_TKGWC_NAME}-admin@${TDH_TKGWC_NAME}
fi

# --- CHECK CLUSTER ---
stt=$(tkg get cluster $TDH_TKGWC_NAME -o json | jq -r --arg key $TDH_TKGWC_NAME '.[] | select(.name == $key).status')                            
if [ "${stt}" != "running" ]; then
  echo "ERROR: tkg cluster is not in 'running' status"
  echo "       => tkg get cluster $TDH_TKGWC_NAME --config=$TDHPATH/config/$TDH_TKGMC_CONFIG"; exit
fi

kubectl get namespace $NAMESPACE > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "ERROR: Namespace '$NAMESPACE' already exist"
  echo "       => kubectl delete namespace $NAMESPACE"
  exit 1
fi

if [ "${TKG_DEPLOYMENT}" == "" ]; then 
  listDeployments
  echo ""
  echo "ERROR: environment variable TKG_DEPLOYMENT not set. Pleae choose one from the list"
  echo "       => export TKG_DEPLOYMENT=<DEPLOYMENT>"
fi

if [ -f ${TDHPATH}/deployments/$TKG_DEPLOYMENT ]; then
  . ${TDHPATH}/deployments/$TKG_DEPLOYMENT

  DOMAIN="apps-${TDH_TKGWC_NAME}.${TDH_TKGMC_ENVNAME}.${AWS_HOSTED_DNS_DOMAIN}"
else
  echo "ERROR: can not find ${TDHPATH}/deployments/$TKG_DEPLOYMENT"; exit
fi

TKG_EXTENSIONS=${TDHPATH}/extensions/tkg-extensions-v1.2.0+vmware.1

# --- PREPARATION ---
cat files/http-ingress.yaml | sed -e "s/DNS_DOMAIN/$DOMAIN/g" -e "s/NAMESPACE/$NAMESPACE/g" > /tmp/http-ingress.yaml

prtHead "Create seperate namespace to host the Ingress Demo"
execCmd "kubectl create namespace $NAMESPACE"

prtHead "Create deployment for the ingress tesing app"
execCmd "kubectl create deployment echoserver-1 --image=datamanos/echoserver --port=8080 -n $NAMESPACE"
execCmd "kubectl create deployment echoserver-2 --image=datamanos/echoserver --port=8080 -n $NAMESPACE"
execCmd "kubectl get pods -n $NAMESPACE"

prtHead "Create two service (echoserver-1 and echoserver-2) for the ingress tesing app"
execCmd "kubectl expose deployment echoserver-1 --port=8080 -n $NAMESPACE"
execCmd "kubectl expose deployment echoserver-2 --port=8080 -n $NAMESPACE"
execCmd "kubectl get svc,pods -n $NAMESPACE"

prtHead "Create the ingress route with context based routing"
execCmd "cat /tmp/http-ingress.yaml"
execCmd "kubectl create -f /tmp/http-ingress.yaml"
execCmd "kubectl get ingress,svc,pods -n $NAMESPACE"

prtHead "Open WebBrowser and verify the deployment"
echo "     # --- Context Based Routing"
echo "     => curl http://echoserver.${DOMAIN}/foo"
echo "     => curl http://echoserver.${DOMAIN}/bar"
echo "     # --- Domain Based Routing"
echo "     => curl http://echoserver1.$DOMAIN"
echo "     => curl http://echoserver2.$DOMAIN"
echo ""

exit

#nginxdemos/hello
#TDH_TKGWC_NAME=tanzu-demo-hub
#K8S_CONTEXT=tanzu-demo-hub-admin@tanzu-demo-hub
#TKG_DEPLOYMENT=tkgmc-dev-azure-westeurope.cfg
#TDH_TKGMC_CONFIG=tkgmc-dev-azure-westeurope.yaml
#TKG_WC_CLUSTER=tkg-tanzu-demo-hub.cfg

  841  docker run -p 8888:80 shomika17/animals
  842  docker run -p 8887:80 shomika17/animals:latest
  843  docker run shomika17/animals:latest
  844  docker run -p 8887:80 bersling/animals
  845  docker run -p 8887:80 kritouf/animals
  846  docker run -p 8887:80 testingmky9394/docker-whale
  847  docker run -p 8887:80 amithrr/fortuneteller
  848  docker run -p 8887:80 paulbouwer/hello-kubernetes:1.8
  849  docker run -p 8887:8080 paulbouwer/hello-kubernetes:1.8
  863  docker run -p 8888:8080 gcr.io/google-samples/hello-app:1.0

export TDH_DEPLOYMENT_ENV_NAME="Azure"
export TKG_CONFIG=/Users/sdubois/workspace/tanzu-demo-hub/config/tkgmc-azure-westeurope.yaml





