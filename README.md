# Overview
Scriptable environments introduce “infrastructure as a code” into devops practices. They allow to:

* Have controllable and verifiable environment structure
* Quickly spin up fully-functional environments in minutes
* Minimize differences between environments
* Provide developers with environment to run and test their components integrated into the final system and expand their area of responsibilities

# Syntax
All sripts have one required parameter - *$ConfigPath*. This is the path to config, path can be absolute or relative. 

**Examples of installing aks**
Relative path example:
`
./cloud/install_k8s.ps1 ./config/cloud_config.json
`
Absolute path example:
`
~/pip-templates-env-azureaks/cloud/install_k8s.ps1 ~/pip-templates-env-azureaks/config/cloud_config.json
`

**Example delete script**
`
./cloud/destroy_k8s.ps1 ./config/cloud_config.json
`

Also you can install environment using single script:
`
./create_env.ps1 ./config/cloud_config.json
`

Delete whole environment:
`
./delete_env.ps1 ./config/cloud_config.json
`

If you have any problem with not installed tools - use `install_prereq_` script for you type of operation system.

# Project structure
| Folder | Description |
|----|----|
| Cloud | Scripts related to management cloud environment. | 
| Common | Scrits common for different evnironments. Currently have script for install/delete platform services for cloud or local environments. | 
| Config | Config files for scripts. Store *example* configs for each environment, recomendation is not change this files with actual values, set actual values in duplicate config files without *example* in name. Also stores *resources* files, created automaticaly. | 
| Lib | Scripts with support functions like working with configs, templates etc. | 
| Temp | Folder for storing automaticaly created temporary files. | 
| Templates | Folder for storing templates, such as kubernetes yml files, az resource manager json files, ansible playbooks, etc. | 
| Test | Script for testing created environment using ansible and comparing results to expected values. | 

### Cloud environment

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
8) On the input for name or email eddress type *Nebula* - this is the name of service principal application, used for creation AKS
9) Click on sudgested application and click Save

* After AKS installation vm used for kubernetes cluster is closed from intertet. If you want to ssh to those instances first you must run `./cloud/open_ports.ps1` to open ssh access via public virtual machine ip, then you can connect to virtual machine and after everything is done - close ssh access `./cloud/close_ports.ps1`

* Cloud env config parameters

| Variable | Default value | Description |
|----|----|---|
| env_type | cloud | Type of environment |
| az_region | eastus | Azure region where resources will be created |
| az_resource_group | piptemplates-stage-east-us | Azure resource group name |
| az_subscription | piptemplates-DI | Azure subscription name |
| az_sp_app_id | secret | Azure service principal application id. Security recomendation - do not upload real value to repository, store config file localy |
| az_sp_password | secret | Azure service principal password. Security recomendation - do not upload real value to repository, store config file localy |
| k8s_deployment_group_name | piptemplates-stage-kubernetes-deployment | Kubernetes azure deployment name |
| k8s_name | piptemplates-stage-kubernetes | Kubernetes cluster name |
| k8s_version | 1.12.7 | Kubernetes cluster version |
| k8s_master_count | 1 | Kubernetes cluster count master nodes |
| k8s_agent_count | 2 | Kubernetes cluster count worker nodes |
| k8s_dns_name_prefix | piptemplates-stage- | Kubernetes cluster dns prefix |
| k8s_agent_vm_size | Standard_D2_v2 | Kubernetes cluster azure virtual machines size |
| k8s_admin_user | piptemplatesadmin | Kubernetes cluster username for azure virtual machines |
| k8s_vnet_name | piptemplates-k8s-stg-vnet | Kubernetes cluster azure virtual network name |
| k8s_vnet_address_cidr | 172.19.16.0/20 | Kubernetes cluster azure virtual network address pool |
| k8s_subnet_name | piptemplates-k8s-stg-subnet | Kubernetes cluster azure subnet name |
| k8s_subnet_address_cidr | 172.19.16.0/20 | Kubernetes cluster azure subnet address pool |
| k8s_service_cidr | 10.0.0.0/16 | Kubernetes service local address pool |
| k8s_dns_service_ip | 10.0.0.10 | Kubernetes dns service local ip |
| k8s_docker_bridge_cidr | 172.17.0.1/16 | Kubernetes docker bridge address pool. This addresses should be included to *k8s_vnet_address_cidr* |
| ssh_keygen_enable | false | Switch for creation new ssh keys. If set to *true* - then new ssh keys in home directory will be created, if set to *false* you should set *ssh_path* and *ssh_private_key_path* |
| ssh_path | ./config/id_rsa.pub | Path to id_rsa.pub used for ssh to azure virtual machines |
| ssh_private_key_path | ./config/id_rsa | Path to id_rsa used for ssh to azure virtual machines |
| container_registry_deployment_name | piptemplates-container-registry-deployment | Azure private container registry deployment name |
| container_registry_name | piptemplatesregistry | Azure private container registry name. Use this for docker login as username |
| container_registry_sku | Basic | Azure private container registry SKU |
| container_registry_admin_enabled | true | Set to *true* to create private azure container registry |
| mgmt_win_vm_deployment_name | piptemplates-mgmt-win-vm-deployment | Azure management station deployment name |
| mgmt_win_vm_name | piptemplates-mgmt-win-vm | Azure management station virtual machine name |
| mgmt_win_vm_user | piptemplatesadmin | Azure management station username. Use this for connect to instance |
| mgmt_win_vm_password | piptemplatesadmin2019# | Azure management station password. Use this for connect to instance |
| mgmt_win_vm_vm_size | Standard_DS1_v2 | Azure management station virtual machine size |
| mgmt_win_vm_vnet_name | piptemplates-mgmt-vm-vnet | Azure management station virtual network name |
| mgmt_win_vm_subnet_name | piptemplates-mgmt-vm-subnet | Azure management station subnet name |
| mgmt_win_vm_nsg_name | piptemplates-mgmt-vm-nsg | Azure management station network security group name |
| mgmt_win_vm_nic_name | piptemplates-mgmt-vm-nic | Azure management station network interface name |
| mgmt_win_vm_disk_name | piptemplates-mgmt-vm-disk | Azure management station disk name |
| mgmt_win_vm_pub_ip_name | piptemplates-mgmt-vm-ip | Azure management station public ip name |

# Testing enviroment
To test created environment after installation you can use script in *test* folder:
`
./test/test_instances.ps1 ./config/test_config.json
`
You have to create test config  before running *test_instances* script.
* Test config parameters

| Variable | Default value | Description |
|----|----|---| 
| username | piptemplatesadmin | Instance username |
| ssh_private_key_path | ./config/id_rsa | Path to private key used for ssh |
| nodes_ips | ["40.121.104.231", "40.121.133.1", "40.121.133.132"] | Public IP's of testing instances |

# Known issues

* Cloud kubernetes installation failed with error `orchestratorProfile.OrchestratorVersion is invalid`
Fixed by upgrading kubernetes version in cloud config `k8s_version` variable. Old value *1.12.5* return error, new value *1.12.7* works fine
