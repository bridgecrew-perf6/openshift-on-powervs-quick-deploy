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
