# SCS / POC / Gardener

![gardener logo](https://gardener.cloud/images/logo.svg)

## Overview

All relevant steps for a setup and installation is located here. Credentials are located on `scs-secrets` repository.


## Links:

- Homepage Gardener
  https://gardener.cloud/
- Documentation
  https://gardener.cloud/documentation/home
- Setup landscape via garden-setup (needs a installed kubernetes cluster)
  https://github.com/gardener/garden-setup


## Lab Setup

- Provider: Openstack (Betacloud)
- Project: SCS (shared Kubermatic/Rancher/Gardener Project)
- Terraform (v0.13.0+)


## history and steps:

- Setup and prepare Base Kubernetes Cluster
  ```bash=
  # enter installation directory 
  cd installation
  
  # all used tools are installed and running
  direnv allow
  
  # create file secrets.d/scs-kubermatic-openrc.sh via gopass and
  # add credetials to your current terminal session
  gopass show scs-secrets/common/betacloud-scs-openrc.sh > ./secure.d/betacloud-scs-openrc.sh
  source ./secure.d/betacloud-scs-openrc.sh
  
  # start an ssh-agent and add the ssh private-key
  # for the password see secrets repo
  ssh-add ./work/poc-gardener
  
  # start the terraforming, use a predefinied terrafrom vars settings
  # at IaaS Level
  ln -s ./work/terraform.tfvars-bc-scs-kubermatic ./terrafrom.tfvars
  
  terraform init openstack
  terraform plan openstack
  terrafrom apply -auto-approve openstack
  
  # create file ./secure.d/acre.yml
  gopass show scs-secrets/poc-gardener/acre.yaml > ./secure.d/acre.yaml
  
  # create file for CloudControllerManager (ccm) for OpenStack
  gopass show scs-secrets/poc-gardener/k8s-secret-ccm-openstack.yaml > secure.d/secret-ccm.yaml
  
  scp -r ./assets/ ./secure.d/*.yaml $(terraform output username)@$(terraform output jumphost):
  ```


- On the Jumphost 
  ```bash=
  # Connect to the jumphost
  ssh -A -l $(terraform output username) $(terraform output jumphost)
  
  # start setup
  # 
  sh assets/setup.sh
  
  # get status of our kubernetes nodes and pods
  kubectl get nodes --output wide
  kubectl get pods --all-namespaces

  cd $HOME/landscape/
 
  # this the latest commit at the time of writing
  git checkout 7a87b3c0f50c4251e0d27423bc4202e81cc1c9c9
  sed -i '18s/^/#/' components/etcd/cluster/component.yaml
  sed -i '91,98s/^/#/' components/etcd/cluster/deployment.yaml

  # get the components 
  sow order -A

  # deploy all components
  sow deploy -A

  # get gardener webinterface url
  sow url
  ```

## findings and specials

- please use semver version for the MachineImage, since the SeedCluster cannot be deployed:
  ```
  # acre.yaml
  ...
  
            extensionConfig:
              machineImages:
                  - name: ubuntu
                    versions:
                      - image: Ubuntu 18.04 -> "imageName from Glance"
                        version: "2020" -> "1.0.0"
            machineImages:
              - name: ubuntu
                versions:
                  - version: "2020" -> "1.0.0" 
   ```  

- SeedCluster cannot be deployed:
  - VolumeQuota at IaaS Level, check OpenStack volumes, quota - maybe delete unused ones
  - LBaaS Service needed

