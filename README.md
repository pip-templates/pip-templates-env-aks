# Overview

This is a built-in module to environment [pip-templates-env-master](https://github.com/pip-templates/pip-templates-env-master). 
This module stores scripts for management azure kubernetes environment.

# Usage

- Download this repository
- Copy *kubernetes* folder to master template
- Add content of *.ps1.add* files to correspondent files from master template
- Add content of *config/config.k8s.json.add* to json config file from master template and set the required values

### Azure cloud environment

Cloud installation specifics:
* If you install kubernetes cluster multiple times with same name, then script can ask you to edit *~/.kube/config* file. Example of warning message:

```
-----------------------------------------------
If You see this message, please, open your kube config file ~/.kube/config and remove cluster and context with name: piptemplates-stage-kubernetes
After that press ENTER to continue...:
```

You should open this file and delete all information related to cluster name (cluster, context and user). This step required because AKS installation merged local kube config adding there new created cluster credentials.

* To allow kubernetes load balancer services assign public IP you need manualy on azure portal execute next steps:
1) Open Virtual networks
2) Select kubernetes virtual network, default name is piptemplates-k8s-stg-vnet 
3) Go to Subnets and select kubernetes cluster subnet, default name is piptemplates-k8s-stg-subnet
4) Click on Manage users
5) Select tab Role assignments
6) Click on Add button and select Add role assignment
7) Select Role - Network Contributor
8) On the input for name or email eddress type *Piptemplates* - this is the name of service principal application, used for creation AKS
9) Click on sudgested application and click Save

# Config parameters

Config variables description

| Variable | Default value | Description |
|----|----|---|
| environment.type | cloud | Type of the environment |
| environment.name | pip-cloud-demo | Name of the environment. Will be used for resources names |
| environment.version | 1.0.0 | Version of the environment |
| az.region | eastus | Azure region where resources will be created |
| az.resource_group | piptemplates-stage-east-us | Azure resource group name |
| az.subscription | piptemplates-DI | Azure subscription name |
| az.sp_app_id | secret | Azure service principal application id. Security recomendation - do not upload real value to repository, store config file localy |
| az.sp_password | secret | Azure service principal password. Security recomendation - do not upload real value to repository, store config file localy |
| k8s.deployment_group_name | piptemplates-stage-kubernetes-deployment | Kubernetes azure deployment name |
| k8s.name | piptemplates-stage-kubernetes | Kubernetes cluster name |
| k8s.version | 1.12.7 | Kubernetes cluster version |
| k8s.master_count | 1 | Kubernetes cluster count master nodes |
| k8s.agent_count | 2 | Kubernetes cluster count worker nodes |
| k8s.dns_name_prefix | piptemplates-stage- | Kubernetes cluster dns prefix |
| k8s.agent_vm_size | Standard_D2_v2 | Kubernetes cluster azure virtual machines size |
| k8s.admin_user | piptemplatesadmin | Kubernetes cluster username for azure virtual machines |
| k8s.vnet_name | piptemplates-k8s-stg-vnet | Kubernetes cluster azure virtual network name |
| k8s.vnet_address_cidr | 172.19.16.0/20 | Kubernetes cluster azure virtual network address pool |
| k8s.subnet_name | piptemplates-k8s-stg-subnet | Kubernetes cluster azure subnet name |
| k8s.subnet_address_cidr | 172.19.16.0/20 | Kubernetes cluster azure subnet address pool |
| k8s.service_cidr | 10.0.0.0/16 | Kubernetes service local address pool |
| k8s.dns_service_ip | 10.0.0.10 | Kubernetes dns service local ip |
| k8s.docker_bridge_cidr | 172.17.0.1/16 | Kubernetes docker bridge address pool. This addresses should be included to *k8s.vnet_address_cidr* |
| k8s.ssh.keygen_enable | false | Switch for creation new ssh keys. If set to *true* - then new ssh keys in home directory will be created, if set to *false* you should set *ssh_path* and *ssh_private_key_path* |
| k8s.ssh.path | ./config/id_rsa.pub | Path to id_rsa.pub used for ssh to azure virtual machines |
| k8s.ssh.private_key_path | ./config/id_rsa | Path to id_rsa used for ssh to azure virtual machines |
| cr.deployment_name | piptemplates-container-registry-deployment | Azure private container registry deployment name |
| cr.name | piptemplatesregistry | Azure private container registry name. Use this for docker login as username |
| cr.sku | Basic | Azure private container registry SKU |
| cr.admin_enabled | true | Set to *true* to create private azure container registry |

# Known issues

* Cloud kubernetes installation failed with error `orchestratorProfile.OrchestratorVersion is invalid`
Fixed by upgrading kubernetes version in cloud config `k8s.version` variable. Old value *1.12.5* return error, new value *1.12.7* works fine
