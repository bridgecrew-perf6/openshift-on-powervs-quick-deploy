#!/usr/bin/env bash

: '
    Copyright (C) 2020,2021 IBM Corporation
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
        exit 1
    fi
}

function terraform_create (){

	terraform init
	# check if Terraform was initiaded successfully.
	if [ $? -eq 0 ]; then
		echo
		echo "SUCCESS: Terraform was initiated successfully."
		echo

		# run Terraform apply
		time terraform apply -auto-approve -var-file var.tfvars \
		-var-file compute-vars/"$CLUSTER_FLAVOR".tfvars \
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
		-var bastion_health_status="$BASTION_HEALTH" \
		-var cluster_domain="$CLUSTER_DOMAIN" | tee create.log

		# check if terraform apply was successfuly executed.
		if [ $? -eq 0 ]; then
			echo
			echo "SUCCESS: Terraform apply was executed successfully."
			echo

			local BASTION_IP=$(terraform output --json | jq -r '.bastion_public_ip.value')
			local BASTION_SSH=$(terraform output --json | jq -r '.bastion_ssh_command.value')

			# check whether or not we can ssh into the bastion
			$BASTION_SSH -oStrictHostKeyChecking=no 'exit'
			if [ $? -eq 0 ]; then
				echo
				echo "SUCCESS: we are able to ssh into the bastion."
				echo

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
					Cluster Size: $CLUSTER_FLAVOR
					Bastion IP: $BASTION_IP ($BASTION_HOSTNAME)
					Bastion SSH: $BASTION_SSH
					OpenShift Access (user/pwd): kubeadmin/$KUBEADMIN_PWD
					Web Console: $WEBCONSOLE_URL
					OpenShift Server URL: $OCP_SERVER_URL
					Kubeconfig: $AUTH_FILES
					****************************
					IBM Cloud Region=$IBMCLOUD_REGION
					IBM Cloud Zone=$IBMCLOUD_ZONE
					PowerVS ID=$POWERVS_INSTANCE_ID
					Bastion Image=$BASTION_IMAGE_NAME
					RedHat CoreOS Image=$RHCOS_IMAGE_NAME
					Processor Type=$PROCESSOR_TYPE
					System Model=$SYSTEM_TYPE
					Private Network Name=$PRIVATE_NETWORK_NAME
				" >> ./"$CLUSTER_ID"-access-details/access-details

				mv ./auth_files.tgz ./"$CLUSTER_ID"-access-details
				cp -rp ./create.log ./"$CLUSTER_ID"-access-details
				cp -rp ./$CLUSTER_ID-variables ./"$CLUSTER_ID"-access-details
				
				mkdir -p ./"$CLUSTER_ID"-access-details/ssh-key
				cp -rp ./data/id_rsa* ./"$CLUSTER_ID"-access-details/ssh-key

				tar -czvf "$CLUSTER_ID"-access-details.tar ./"$CLUSTER_ID"-access-details
				
				cp -rp ./"$CLUSTER_ID"-access-details.tar ../../../

				ACCESS_INFO=(
				"**************************************************************"
				"CLUSTER ACCESS INFORMATION"
				"Cluster Size: $CLUSTER_FLAVOR"
				"Cluster ID: $CLUSTER_ID"
				"Bastion IP: $BASTION_IP ($BASTION_HOSTNAME)"
				"Bastion SSH: $BASTION_SSH"
				"OpenShift Access (user/pwd): kubeadmin/$KUBEADMIN_PWD"
				"Web Console: $WEBCONSOLE_URL"
				"OpenShift Server URL: $OCP_SERVER_URL"
				"Kubeconfig: $AUTH_FILES"
				"***********************"
				"IBM Cloud Region=$IBMCLOUD_REGION"
				"IBM Cloud Zone=$IBMCLOUD_ZONE"
				"PowerVS ID=$POWERVS_INSTANCE_ID"
				"Bastion Image=$BASTION_IMAGE_NAME"
				"RedHat CoreOS Image=$RHCOS_IMAGE_NAME"
				"Processor Type=$PROCESSOR_TYPE"
				"System Model=$SYSTEM_TYPE"
				"Private Network Name=$PRIVATE_NETWORK_NAME"
				"**************************************************************"
				)
				printf '%s\n' "${ACCESS_INFO[@]}"
			else
				echo
				echo "ERROR: we are not able to ssh into the bastion."
				echo "		 your cluster deployment failed!"
				exit 1
			fi
		else
			echo
			echo "ERROR: Terraform apply failed."
			exit 1
		fi
	else
		echo
		echo "ERROR: Terraform init failed."
		exit 1
	fi
}

function terraform_destroy (){

	terraform init
	terraform destroy -auto-approve -var-file var.tfvars -parallelism=3 \
	-var-file compute-vars/"$CLUSTER_FLAVOR".tfvars \
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
