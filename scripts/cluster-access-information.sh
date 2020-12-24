#!/usr/bin/env bash

: '
    Copyright (C) 2020 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

function check_dependencies() {

	local DEPENDENCIES=(terraform jq)
	for dep in "${DEPENDENCIES[@]}"
	do
		if ! command -v $dep &> /dev/null; then
				echo "ERROR: $dep could not be found."
				exit 1
		fi
	done
}

function run() {

	check_dependencies

	BASTION_IP=$(terraform output --json | jq -r '.bastion_public_ip.value')
	BASTION_SSH=$(terraform output --json | jq -r '.bastion_ssh_command.value')
	BASTION_HOSTNAME=$($BASTION_SSH -oStrictHostKeyChecking=no 'hostname')
	CLUSTER_ID=$(terraform output --json | jq -r '.cluster_id.value')
	KUBEADMIN_PWD=$($BASTION_SSH -oStrictHostKeyChecking=no 'cat ~/openstack-upi/auth/kubeadmin-password; echo')
	WEBCONSOLE_URL=$(terraform output --json | jq -r '.web_console_url.value')
	OCP_SERVER_URL=$(terraform output --json | jq -r '.oc_server_url.value')

cat << EOF
****************************************************************

  CLUSTER ACCESS INFORMATION

  Cluster ID: $CLUSTER_ID
  Bastion IP: $BASTION_IP ($BASTION_HOSTNAME)
  Bastion SSH: $BASTION_SSH
  OpenShift Access (user/pwd): kubeadmin/$KUBEADMIN_PWD
  Web Console: $WEBCONSOLE_URL
  OpenShift Server URL: $OCP_SERVER_URL

****************************************************************
EOF
}

run "$@"
