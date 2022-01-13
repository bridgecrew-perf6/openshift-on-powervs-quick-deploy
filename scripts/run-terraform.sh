#!/usr/bin/env bash

: '
    Copyright (C) 2020, 2021 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation. 
'

TODAY=$(date "+%Y%m%d-%H%M%S")

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "bye!"
}

function check_connectivity() {
    
    curl --output /dev/null --silent --head --fail http://github.com
	CURL_EXIT=$?
    if [ ! $CURL_EXIT -eq 0 ]; then
        echo
        echo "ERROR: please, check your internet connection."
        exit 1
    fi
}

function terraform_create (){

	curl -sL https://raw.githubusercontent.com/ocp-power-automation/openshift-install-power/master/openshift-install-powervs -o ./openshift-install-powervs
	#curl -sL https://raw.githubusercontent.com/rpsene/openshift-install-power/devel/openshift-install-powervs -o ./openshift-install-powervs

	if [ -f "openshift-install-powervs" ]; then

		chmod +x ./openshift-install-powervs

		VARS=(
		"ibmcloud_api_key = \"$IBMCLOUD_API_KEY\""
		"ibmcloud_region = \"$IBMCLOUD_REGION\""
		"ibmcloud_zone = \"$IBMCLOUD_ZONE\""
		"service_instance_id = \"$POWERVS_INSTANCE_ID\""
		"rhel_image_name = \"$BASTION_IMAGE_NAME\""
		"rhcos_image_name = \"$RHCOS_IMAGE_NAME\""
		"processor_type = \"$PROCESSOR_TYPE\""
		"system_type = \"$SYSTEM_TYPE\""
		"network_name = \"$PRIVATE_NETWORK_NAME\""
		"cluster_id = \"$CLUSTER_ID\""
		"cluster_id_prefix = \"$CLUSTET_ID_PREFIX\""
		"bastion_health_status = \"$BASTION_HEALTH\""
		"cluster_domain = \"$CLUSTER_DOMAIN\""
		"storage_type = \"$STORAGE_TYPE\""
		"volume_size = \"$STORAGE_VOLUME_SIZE\""
		"volume_shareable = \"$STORAGE_VOLUME_SHAREABLE\""
		"master_volume_size = \"$MASTER_VOLUME_SIZE\"" \
		"worker_volume_size = \"$WORKER_VOLUME_SIZE\"" \
		"setup_squid_proxy = \"$SETUP_SQUID_PROXY\"" \
		"setup_snat = \"$SETUP_SNAT\"" \
		"use_zone_info_for_names = \"$USE_ZONE_INFO_FOR_NAMES\"")
		
		#"iaas_classic_api_key = \"$IAAS_CLASSIC_API_KEY\"" \
		#au-syd     https://au-syd.iaas.cloud.ibm.com
		#br-sao     https://br-sao.iaas.cloud.ibm.com
		#ca-tor     https://ca-tor.iaas.cloud.ibm.com
		#eu-de      https://eu-de.iaas.cloud.ibm.com
		#eu-fr2     https://eu-fr2.iaas.cloud.ibm.com
		#eu-gb      https://eu-gb.iaas.cloud.ibm.com
		#jp-osa     https://jp-osa.iaas.cloud.ibm.com
		#jp-tok     https://jp-tok.iaas.cloud.ibm.com
		#us-east    https://us-east.iaas.cloud.ibm.com
		#us-south   https://us-south.iaas.cloud.ibm.com

		if [ "$USE_IBM_CLOUD_SERVICES" = true ]; then
			VARS=( "${VARS[@]}" "use_ibm_cloud_services = \"$USE_IBM_CLOUD_SERVICES\"" )
			VARS=( "${VARS[@]}" "ibm_cloud_vpc_name = \"$IBM_CLOUD_VPC_NAME\"" )
  			VARS=( "${VARS[@]}" "ibm_cloud_vpc_subnet_name = \"$IBM_CLOUD_VPC_SUBNET_NAME\"" )
            		VARS=( "${VARS[@]}" "iaas_classic_username = \"$IAAS_CLASSIC_USERNAME\"" )
            		VARS=( "${VARS[@]}" "iaas_vpc_region = \"$IAAS_VPC_REGION\"" )
   		fi

		# if the user is going to use RHEL as bastion
		if [ "$RHEL_SUBS_USERNAME" ] && [ "$RHEL_SUBS_PASSWORD" ]; then
			VARS=( "${VARS[@]}" "rhel_subscription_username = \"$RHEL_SUBS_USERNAME\"" )
			VARS=( "${VARS[@]}" "rhel_subscription_username = \"$RHEL_SUBS_PASSWORD\"" )
		fi

		# add the variables for the size of the cluster
		if [ "$CLUSTER_FLAVOR" ]; then
			SIZE=$(cat ./cluster-size/"$CLUSTER_FLAVOR")
			VARS=( "${VARS[@]}" "$SIZE" )
		fi

		# create the var.tfvars that will be used as input for the automation
		printf '%s\n' "${VARS[@]}" >> var.tfvars

		# move the pull secret to where it is expected
		mv ./data/pull-secret.txt ./

		./openshift-install-powervs create -verbose -trace -var-file ./var.tfvars | tee create.log

		OCP_INSTALL_EXIT=$?
		# check if terraform apply was successfuly executed.
		if [ "$OCP_INSTALL_EXIT" -eq 0 ]; then
			echo
			echo "SUCCESS: Terraform apply was executed successfully."
			echo
			cd ./automation || exit 1
			local BASTION_IP
			local BASTION_SSH
			BASTION_IP=$(terraform output --json | jq -r '.bastion_public_ip.value')
			BASTION_SSH=$(terraform output --json | jq -r '.bastion_ssh_command.value')
			ping -c 4 "$BASTION_IP"
			# check whether or not we can ssh into the bastion
			echo "**************************************************************"
			echo "	Trying to access the bastion via ssh..."
			$BASTION_SSH -o StrictHostKeyChecking=no -o ConnectTimeout=15 'exit'
			SSH_EXIT=$?
			if [ "$SSH_EXIT" -eq 0 ]; then
				echo
				echo "SUCCESS: we are able to ssh into the bastion."
				echo "**************************************************************"
				echo
				local BASTION_HOSTNAME
				local CLUSTER_ID
				local KUBEADMIN_PWD
				local WEBCONSOLE_URL
				local OCP_SERVER_URL

				BASTION_HOSTNAME=$($BASTION_SSH -o StrictHostKeyChecking=no -o ConnectTimeout=15 'hostname')
				CLUSTER_ID=$(terraform output --json | jq -r '.cluster_id.value')
				KUBEADMIN_PWD=$($BASTION_SSH -oStrictHostKeyChecking=no 'cat ~/openstack-upi/auth/kubeadmin-password; echo')
				WEBCONSOLE_URL=$(terraform output --json | jq -r '.web_console_url.value')
				OCP_SERVER_URL=$(terraform output --json | jq -r '.oc_server_url.value')
				# copies the authentication files from the bastion
				local AUTH_FILES="auth_files.tgz"
				$BASTION_SSH -oStrictHostKeyChecking=no 'cd ~/openstack-upi && tar -cf - * | gzip -9' > $AUTH_FILES

				mkdir -p ./"$CLUSTER_ID"-access-details

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
				"Kubeconfig: /$CLUSTER_ID-access-details/kubeconfig"
				"**************************************************************"
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

				printf '%s\n' "${ACCESS_INFO[@]}" >> ./"$CLUSTER_ID"-access-details/access-details

				mkdir -p /tmp/"$CLUSTER_ID"

				tar -xf ./auth_files.tgz --directory /tmp/"$CLUSTER_ID"

				cp -rp /tmp/"$CLUSTER_ID"/auth/* ./"$CLUSTER_ID"-access-details
				cp -rp ../create.log ./"$CLUSTER_ID"-access-details
				cp -rp ../var.tfvars ./"$CLUSTER_ID"-access-details
				#cp -rp "../$CLUSTER_ID-variables" ./"$CLUSTER_ID"-access-details
				
				mkdir -p ./"$CLUSTER_ID"-access-details/data/
				cp -rp ./data/id_rsa* ./"$CLUSTER_ID"-access-details/data/

				tar -czvf "$CLUSTER_ID"-access-details.tar ./"$CLUSTER_ID"-access-details
				
				mv ./"$CLUSTER_ID"-access-details.tar ../
				
				export CLUSTER_ID=$CLUSTER_ID

				printf '%s\n' "${ACCESS_INFO[@]}"
			else
				echo
				echo "ERROR: We are not able to ssh into the bastion."
				echo "		 Your cluster deployment failed :("
				echo "**************************************************************"
				exit 1
			fi
		else
			echo
			echo "ERROR: Terraform apply failed, aborting."
			exit 1
		fi
	else
		echo
		echo "ERROR: Could not locate $INSTALL, aborting."
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
