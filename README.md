![GitHub release (latest by date)](https://img.shields.io/github/v/release/rpsene/openshift-on-powervs-quick-deploy?style=flat-square)
![GitHub](https://img.shields.io/github/license/rpsene/openshift-on-powervs-quick-deploy?style=flat-square)
![GitHub last commit](https://img.shields.io/github/last-commit/rpsene/openshift-on-powervs-quick-deploy?style=flat-square)

This is an auxiliary automation to execute on or more setups of a default OpenShift cluster (1 bastion + 1 boot node + 3 master nodes + 2 worker nodes) at IBM Cloud on PowerVS using as base a multi-arch (amd64 and ppc64le) container image which is built with all required versions of the dependencies (i.e Terraform and its providers and IBM Cloud CLI).

The source code of the container is located **[in this repository](https://github.com/ocp-power-automation/powervs-container-host)** and the containers are stored at **[quay.io](https://quay.io/repository/powercloud/powervs-container-host)**.

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

**NOTE**: you can use the [PowerVS Actions](https://github.com/rpsene/powervs-actions) to get the necessary information to fill in the variables.

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

NOTE: [Red Hat business partners who have signed a partner agreement are eligible to receive limited quantities of free Not for Resales (NFR) software subscriptions as benefits of participating in partner programs.](https://www.redhat.com/files/other/partners/Howtoguide-createanewNFR.pdf)

## Step 3: Deploy

**NOTE:** before selecting the OCP version, ensure that you have the proper boot images set in your PowerVS instance.

```
➜  powervs-ocp-deploy git:(master) ✗ ./deploy.sh

	Please, select either 4.5 or 4.6.
	e.g: ./deploy 4.6

```

Once you start deploying, the directory structure will look like this:

```
$ tree -L 2
.
├── LICENSE
├── README.md
├── deploy.sh
├── ocp-secrets
├── powervs-clusters
│   ├── 4.6_20201222-172133_beaaf7d926
│   ├── 4.6_20201222-234956_b19837da8a
│   └── tmp-variables-e
├── run-terraform.sh
└── variables
```

You can either follow the log in the current running container or leave the container (**ctrl p + ctrl q**) and follow what is going on by exploring the content of the ```create.log``` file:

```
$ docker ps

CONTAINER ID   IMAGE                                               COMMAND       CREATED       STATUS       PORTS     NAMES
826cf13ebb99   quay.io/powercloud/powervs-container-host:ocp-4.6   "/bin/bash"   9 hours ago   Up 9 hours             4.6_20201222-234956_b19837da8a

$ CONTAINER=4.6_20201222-234956_b19837da8a

$ docker exec -w /ocp4-upi-powervs -it $CONTAINER /bin/bash -c "tail -f ./create.log"
...
```

## Step 4: Destroy

```
$ tree -L 2
.
├── LICENSE
├── README.md
├── deploy.sh
├── ocp-secrets
├── powervs-clusters
│   ├── 4.6_20201222-172133_beaaf7d926
│   ├── 4.6_20201222-234956_b19837da8a
│   └── tmp-variables-e
├── run-terraform.sh
└── variables

$ docker ps

CONTAINER ID   IMAGE                                               COMMAND       CREATED       STATUS       PORTS     NAMES
826cf13ebb99   quay.io/powercloud/powervs-container-host:ocp-4.6   "/bin/bash"   9 hours ago   Up 9 hours             4.6_20201222-234956_b19837da8a

$ CONTAINER=4.6_20201222-234956_b19837da8a

$ docker exec -w /ocp4-upi-powervs -it $CONTAINER /bin/bash -c "./run-terraform.sh --destroy; docker rm -f $CONTAINER"
```

If need be, you can follow the log of what is going on by exploring the content of the destroy.log file:

```
$ docker exec -w /ocp4-upi-powervs -it $CONTAINER /bin/bash -c "tail -f ./destroy.log"
...
```

NOTE: When you look at PowerVS UI, all resources created for this deployment will have a prefix + its function on the deployment:

 ```
 [DATE OF DEPLOYMENT]-[TIME OF DEPLOYMENT]-[RANDON HASH]-[OCP FUNCTION]
 example: 20201222-134603-966f6d5510-master-1
 ```
