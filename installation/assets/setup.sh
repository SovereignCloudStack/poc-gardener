#!/usr/bin/env bash

##    desc: minimal setup for an jumphost/gardner
##  author: Thorsten Schifferdecker <schifferdecker@b1-systems.de>
## license: ASL-2.0

## vars
KUBECONFIG="$HOME/landscape/kubeconfig.yaml"
HOST="$(hostname -s)"
MASTER="${HOST%j*t}master"
KUBECTL_VERSION="v1.18.8"
KUBECTL_BIN="$HOME/bin/kubectl"
GARDENER_SETUP_VERSION=""2.2.1"
## main

# create home for binaries and gardener landscape
mkdir $HOME/bin $HOME/landscape

# get the kubeconfig
ssh ${MASTER} 'sudo cat /etc/rancher/k3s/k3s.yaml' > $KUBECONFIG

# install the kubernetes-cli
curl https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -Lo $HOME/bin/kubectl \
  && sudo chmod +x ${KUBECTL_BIN}

# setup our base kubernetes cluster
${KUBECTL_BIN} --kubeconfig ${KUBECONFIG} config set clusters.default.server https://${MASTER}:6443

# the gardener sow util, need an installed and running docker
git clone https://github.com/gardener/sow.git ${HOME}/sow

# the "crop" aka garden-setup and prepare the acre
git clone --single-branch --branch ${GARDENER_SETUP_VERSION} https://github.com/gardener/garden-setup.git ${HOME}/landscape/crop
cp $HOME/acre.yaml $HOME/landscape/acre.yaml

# todo: fix bucket creation
# workaround, disable etcd-backup deps
sed -i '18s/^/#/' $HOME/landscape/crop/components/etcd/cluster/component.yaml
sed -i '91,98s/^/#/' $HOME/landscape/crop/components/etcd/cluster/deployment.yaml
mv $HOME/landscape/crop/components/etcd/backupinfra $HOME/landscape/disabled-crop-components-etcd-backupinfra 

# make the usage more handy-candy ;)
echo '# this files is maintend - please dont add some stuff' > .bash_aliases
echo 'export PATH=$PATH:$HOME/bin:$HOME/sow/docker/bin' >> .bash_aliases
echo 'export KUBECONFIG=$HOME/landscape/kubeconfig.yaml' >> .bash_aliases
echo 'alias k=kubectl' >> .bash_aliases

# bash-completion for kubectl
${KUBECTL_BIN} completion bash | sed 's# kubectl$# k kubectl#1' >> .bash_aliases

# deploy all relevant Kubernetes Resources
${KUBECTL_BIN} --kubeconfig ${KUBECONFIG} apply -f $HOME/secret-ccm.yaml -f /$HOME/assets/manifests/ -R --namespace kube-system

# eof
