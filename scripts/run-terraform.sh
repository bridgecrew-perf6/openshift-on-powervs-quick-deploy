#!/usr/bin/env bash

: '
    Copyright (C) 2020 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation. 
'

TODAY=$(date "+%Y%m%d-%H%M%S")

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "bye!"
}

function check_connectivity() {
    
    curl --output /dev/null --silent --head --fail http://cloud.ibm.com
    if [ ! $? -eq 0 ]; then
        echo
        echo "ERROR: please, check your internet connection."
        exit
    fi
}

function terraform_create (){

	terraform init
	time terraform apply -auto-approve -var-file var.tfvars \
	-var ibmcloud_api_key="$IBMCLOUD_API_KEY" \
	-var ibmcloud_region="$IBMCLOUD_REGION" \
	-var ibmcloud_zone="$IBMCLOUD_ZONE" \
	-var service_instance_id="$POWERVS_INSTANCE_ID" \
	-var rhel_image_name="$BASTION_IMAGE_NAME" \
	-var rhcos_image_name="$RHCOS_IMAGE_NAME" \
	-var processor_type="$PROCESSOR_TYPE" \
	-var system_type="$SYSTEM_TYPE" \
	-var network_name="$PRIVATE_NETWORK_NAME" \
	-var rhel_subscription_username="$RHEL_SUBS_USERNAME" \
	-var rhel_subscription_password="$RHEL_SUBS_PASSWORD" \
	-var cluster_id="$CLUSTER_ID" \
	-var cluster_id_prefix="$CLUSTET_ID_PREFIX" \
	-var cluster_domain="$CLUSTER_DOMAIN" | tee create.log
	
    	local BASTION_IP=$(terraform output --json | jq -r '.bastion_public_ip.value')
    	local BASTION_SSH=$(terraform output --json | jq -r '.bastion_ssh_command.value')
    	local BASTION_HOSTNAME=$($BASTION_SSH -oStrictHostKeyChecking=no 'hostname')
    	local CLUSTER_ID=$(terraform output --json | jq -r '.cluster_id.value')
    	local KUBEADMIN_PWD=$($BASTION_SSH -oStrictHostKeyChecking=no 'cat ~/openstack-upi/auth/kubeadmin-password; echo')
    	local WEBCONSOLE_URL=$(terraform output --json | jq -r '.web_console_url.value')
    	local OCP_SERVER_URL=$(terraform output --json | jq -r '.oc_server_url.value')
	# copies the authentication files from the bastion
    	local AUTH_FILES="auth_files.tgz"
    	$BASTION_SSH -oStrictHostKeyChecking=no 'cd ~/openstack-upi && tar -cf - * | gzip -9' > $AUTH_FILES
	
	mkdir -p ./"$CLUSTER_ID"-access-details

	echo "
	CLUSTER ACCESS INFORMATION
	Cluster ID: $CLUSTER_ID
	Bastion IP: $BASTION_IP ($BASTION_HOSTNAME)
	Bastion SSH: $BASTION_SSH
	OpenShift Access (user/pwd): kubeadmin/$KUBEADMIN_PWD
	Web Console: $WEBCONSOLE_URL
	OpenShift Server URL: $OCP_SERVER_URL
	Kubeconfig: $AUTH_FILES
	" >> ./"$CLUSTER_ID"-access-details/access-details
	
	mv ./auth_files.tgz ./"$CLUSTER_ID"-access-details
	cp -rp ./create.log ./"$CLUSTER_ID"-access-details
	
	mkdir -p ./"$CLUSTER_ID"-access-details/ssh-key
	cp -rp ./data/id_rsa* ./"$CLUSTER_ID"-access-details/ssh-key

	tar -czvf "$CLUSTER_ID"-access-details.tar ./"$CLUSTER_ID"-access-details

cat << EOF
****************************************************************
  CLUSTER ACCESS INFORMATION
  Cluster ID: $CLUSTER_ID
  Bastion IP: $BASTION_IP ($BASTION_HOSTNAME)
  Bastion SSH: $BASTION_SSH
  OpenShift Access (user/pwd): kubeadmin/$KUBEADMIN_PWD
  Web Console: $WEBCONSOLE_URL
  OpenShift Server URL: $OCP_SERVER_URL
  Kubeconfig: $AUTH_FILES
****************************************************************
EOF
}

function terraform_destroy (){

	terraform init
	terraform destroy -auto-approve -var-file var.tfvars -parallelism=3 \
	-var ibmcloud_api_key="$IBMCLOUD_API_KEY" \
	-var ibmcloud_region="$IBMCLOUD_REGION" \
	-var ibmcloud_zone="$IBMCLOUD_ZONE" \
	-var service_instance_id="$POWERVS_INSTANCE_ID" \
	-var rhel_image_name="$BASTION_IMAGE_NAME" \
	-var rhcos_image_name="$RHCOS_IMAGE_NAME" \
	-var processor_type="$PROCESSOR_TYPE" \
	-var system_type="$SYSTEM_TYPE" \
	-var network_name="$PRIVATE_NETWORK_NAME" \
	-var rhel_subscription_username="$RHEL_SUBS_USERNAME" \
	-var rhel_subscription_password="$RHEL_SUBS_PASSWORD" \
	-var cluster_id="$CLUSTER_ID" \
	-var cluster_id_prefix="$CLUSTET_ID_PREFIX" \
	-var cluster_domain="$CLUSTER_DOMAIN" | tee destroy.log
}

function run (){

    check_connectivity
    if [[ "$1" == *"--destroy"* ]]; then
    	terraform_destroy
    else
    	terraform_create
    fi
}

run "$@"
