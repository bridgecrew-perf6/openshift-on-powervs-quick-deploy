This is an auxiliary automation to execute on or more setups of an OpenShift cluster at IBM Cloud on PowerVS using as base a multi-arch (amd64 and ppc64le) container image which is built with all required versions of the dependencies (i.e Terraform and its providers and IBM Cloud CLI).

The source code of the container is located **[in this repository](https://github.com/rpsene/powervs-container-host)** and the containers are stored at **[quay.io](https://quay.io/repository/powercloud/powervs-container-host)**.

## Step 0: PowerVS Preparation Checklist

- [ ] **[Create a paid IBM Cloud Account](https://cloud.ibm.com/)**.
- [ ] **[Create an API key](https://cloud.ibm.com/docs/account?topic=account-userapikey)**.
- [ ] Add a new instance of an Object Storage Service (or reuse any existing one):
	- [ ] Create a new bucket.
	- [ ] Create a new credential with HMAC enabled.
	- [ ] Create and upload (or just upload if you already have it) the required .ova images.
- [ ] Add a new instance of the Power Virtual Service.
	- [ ] Create a private network and **[open a support ticket](https://cloud.ibm.com/unifiedsupport/cases/form)** to enable connectivity between the VMs within this private network.
	- [ ] [Create the boot images](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-importing-boot-image).
	
**NOTE:** Details about the checklist steps can be found [here](https://github.com/ocp-power-automation/ocp4-upi-powervs/blob/master/docs/ocp_prereqs_powervs.md).

## Step 1: Get OpenShift Secret

1. **[Create an account at RedHat portal](https://www.redhat.com/wapps/ugc/register.html?_flowId=register-flow&_flowExecutionKey=e1s1)**
2. Go to **[bit.ly/ocp-secrets](bit.ly/ocp-secrets)** and copy the pull secret.
3. Paste the secret in the **[ocp-secrets](ocp-secrets)** file.

## Step 2: Configure the Variables

1. Install a container runtime (**[docker](https://docs.docker.com/engine/install/)** or **[podman](https://podman.io/getting-started/installation)**) and **[git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)**.
2. ```git clone https://github.ibm.com/rpsene/powervs-ocp-deploy.git; cd ./powervs-ocp-deploy```
3. Edit the **[variables](variables),** file by setting the following variables:

```
	IBMCLOUD_API_KEY=
	IBMCLOUD_REGION=
	IBMCLOUD_ZONE=
	POWERVS_INSTANCE_ID=
	BASTION_IMAGE_NAME=
	RHCOS_IMAGE_NAME=
	PROCESSOR_TYPE=shared
	SYSTEM_TYPE=s922
	PRIVATE_NETWORK_NAME=
```

**IMPORTANT:** if you are using a **RHEL** image for the bastion, you must add the following variables and its respectives values in the aforementioned file:

```
	RHEL_SUBS_USERNAME=
	RHEL_SUBS_PASSWORD=
```

## Step 3: Deploy

**NOTE:** before selecting the OCP version, ensure that you have the proper boot images set in your PowerVS instance.

```
➜  powervs-ocp-deploy git:(master) ✗ ./deploy.sh

	Please, select either 4.5 or 4.6.
	e.g: ./deploy 4.6

```

Once you start deploying, the directory structure will look like this:

```
➜  powervs-ocp-deploy git:(master) ✗ tree -L 2
.
├── README.md
├── deploy.sh
├── ocp-secrets
├── variables
├── powervs-clusters
│   └── 4.6_20201215-225150
└── run-terraform.sh
```

You can either follow the log in the current container execution or leave the container (**ctrl p + ctrl q**) and follow what is going on by exploring the content of the ```powervs-clusters/4.6_20201215-225150/create.log``` file:

```
➜  4.6_20201215-225150 git:(release-4.6) ✗ tail -f ./powervs-clusters/4.6_20201215-225150/create.log

module.prepare.ibm_pi_key.key: Creating...
module.prepare.ibm_pi_network.public_network: Creating...
module.prepare.ibm_pi_key.key: Creation complete after 2s [id=914d5b1b-9ac4-48a6-b2ec-43f4d22d0fce/20201215-225150-02b30cc1d2-keypair]
...
```

The structure of the name **4.6_20201215-213844** is ```[OCP VERSION]_[DATE OF DEPLOYMENT]_[TIME OF DEPLOYMENT]```. When you look at PowerVS UI, all resources created for this deployment will have with this prefix + its function on the deployment:

 ```
 [DATE OF DEPLOYMENT]-[TIME OF DEPLOYMENT]-[RANDON HASH]-[OCP FUNCTION]
 example: 20201215-213844-e0e76686a6-master-1
 ```

## Step 4: Destroy

```
➜  powervs-ocp-deploy git:(master) ✗ ./run-terraform.sh --destroy
```

You can follow the log of what is going on by exploring the content of the ```./powervs-clusters/4.6_20201215-225150/destroy.log``` file:

```
➜  4.6_20201215-225150 git:(release-4.6) ✗ tail -f ./powervs-clusters/4.6_20201215-225150/destroy.log
...
```
