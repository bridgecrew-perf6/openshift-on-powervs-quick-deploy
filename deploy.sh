#!/usr/bin/env bash

: '
    Copyright (C) 2020 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "bye!"
}

function check_dependencies() {

	if command -v "podman" &> /dev/null; then
	   echo "Setting podman as container runtime..."
	   export CONTAINER_RUNTIME="podman"
	elif command -v "docker" &> /dev/null; then
	   echo "Setting docker as container runtime..."
	   export CONTAINER_RUNTIME="docker"
	else
	   echo "ERROR: please, install either podman or docker!"
	   exit
	fi
}

function check_variables() {

	INPUT=$1

	while IFS= read -r line; do
		VAR=$(echo "$line" | awk '{split($0,var,"="); print var[1]}')
		VALUE=$(echo "$line" | awk '{split($0,var,"="); print var[2]}')

		if [ -z $VALUE ]; then
	  		echo
	   		echo "ERROR: $VAR is not set."
	   		echo "      check the $INPUT file and try again."
	   		echo
	   		exit
		fi
	done < "$INPUT"
}

function check_connectivity() {
    
    curl --output /dev/null --silent --head --fail http://github.com
    if [ ! $? -eq 0 ]; then
        echo
        echo "ERROR: please, check your internet connection."
        exit
    fi
}

function configure() {

	OCP_VERSION=$1

	if [ -s ./ocp-secrets ]; then

		mkdir -p ./powervs-clusters; cd ./powervs-clusters

		git clone --single-branch --branch release-"$OCP_VERSION" \
		https://github.com/ocp-power-automation/ocp4-upi-powervs.git $OCP_VERSION"_"$TODAY"_"$SUFIX

		ssh-keygen -t rsa -b 4096 -N '' -f ./$OCP_VERSION"_"$TODAY"_"$SUFIX/data/id_rsa

		cat ../ocp-secrets >> ./$OCP_VERSION"_"$TODAY"_"$SUFIX/data/pull-secret.txt

		cp -rp ../scripts/run-terraform.sh ./$OCP_VERSION"_"$TODAY"_"$SUFIX
		cp -rp ../scripts/cluster-access-information.sh ./$OCP_VERSION"_"$TODAY"_"$SUFIX
	else
		echo
		echo "ERROR: ensure you added the OpenShift Secrets at ./ocp-secrets"	
		echo "       you can get it from bit.ly/ocp-secrets"
		echo
		exit
	fi
}

function create_container (){

	local OCP_VERSION=$1
	local CONTAINER_NAME=$OCP_VERSION"_"$TODAY"_"$SUFIX
	local PREFIX=$(echo "ocp-"$OCP_VERSION"-"$TODAY | tr -d .)

	cp -rp ../variables ./tmp-variables

	sed -i -e "s/sufix/$SUFIX/g" ./tmp-variables
	sed -i -e "s/prefix/$PREFIX/g" ./tmp-variables

	mv ./tmp-variables ./$OCP_VERSION"_"$TODAY"_"$SUFIX/$CONTAINER_NAME-variables

	# starts the base container with the basic set of env vars
	$CONTAINER_RUNTIME run -dt --name $CONTAINER_NAME \
	-v "$(pwd)"/$OCP_VERSION"_"$TODAY"_"$SUFIX:/ocp4-upi-powervs --env-file ./$OCP_VERSION"_"$TODAY"_"$SUFIX/$CONTAINER_NAME-variables \
	quay.io/powercloud/powervs-container-host:ocp-$OCP_VERSION /bin/bash

	echo "*********************************************************************************"
	echo "NOTE: the installation is running from within the container named $CONTAINER_NAME"
	echo "*********************************************************************************"

	# execute the TF deployment from within the container
	$CONTAINER_RUNTIME exec -it -w /ocp4-upi-powervs $CONTAINER_NAME bash -c "./run-terraform.sh"
}

function run (){

	OCP_VERSIONS=("4.5", "4.6")

	if [ -z $1 ]; then
		echo
		echo "ERROR: please, select one of the supported versions: ${OCP_VERSIONS[@]}."
		echo "       e.g: ./deploy 4.6"
		echo
		exit 1
	elif [[ ! " ${OCP_VERSIONS[@]} " =~ " ${1} " ]]; then
		echo
		echo "ERROR: this version of OpenShift ($1) is not supported."
		echo "       pick one of the following: ${OCP_VERSIONS[@]}."
		echo
		exit 1
	else
		export TODAY=$(date "+%Y%m%d-%H%M%S")
		export SUFIX=$(openssl rand -hex 5)
		check_dependencies
		check_variables ./variables
		check_connectivity
		configure $1
		create_container $1
	fi
}

run "$@"
