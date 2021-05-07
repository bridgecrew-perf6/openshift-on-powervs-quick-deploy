#!/usr/bin/env bash

: '
    Copyright (C) 2020, 2021 IBM Corporation
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
	   exit 1
	fi
}

function check_variables() {

	INPUT=$1

	while IFS= read -r line; do
		VAR=$(echo "$line" | awk '{split($0,var,"="); print var[1]}')
		VALUE=$(echo "$line" | awk '{split($0,var,"="); print var[2]}')

		if [ -z "$VALUE" ]; then
	  		echo
	   		echo "ERROR: $VAR is not set."
	   		echo "      check the $INPUT file and try again."
	   		echo
	   		exit 1
		fi
	done < "$INPUT"
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

function configure() {

	OCP_VERSION=$1

	if [ -s "$(pwd)"/files/ocp-secrets ]; then

		mkdir -p ./powervs-clusters; cd ./powervs-clusters || exit

		DIR=$(echo "ocp-""$OCP_VERSION""-""$SUFIX" | tr -d .)
		mkdir -p ./"$DIR"
		mkdir -p ./"$DIR"/data
		mkdir -p ./"$DIR"/scripts
		mkdir -p ./"$DIR"/cluster-size/

		cat ../files/ocp-secrets >> ./"$DIR"/data/pull-secret.txt
		cp -rp ../scripts/run-terraform.sh ./"$DIR"/scripts
		cp -rp ../scripts/cluster-access-information.sh ./"$DIR"/scripts
		cp -rp ../files/cluster-size/* ./"$DIR"/cluster-size/
	else
		echo
		echo "ERROR: ensure you added the OpenShift Secrets at ./ocp-secrets"	
		echo "       you can get it from bit.ly/ocp-secrets"
		echo
		exit 1
	fi
}

function create_container (){
	
	local CONTAINER_NAME
	local PREFIX
	local DIR
	local OCP_VERSION=$1

	CONTAINER_NAME=$(echo "ocp-$OCP_VERSION-$SUFIX" | tr -d .)
	PREFIX=$(echo "ocp-$OCP_VERSION" | tr -d .)
	DIR=$(echo "ocp-$OCP_VERSION-$SUFIX" | tr -d .)

	cp -rp ../files/variables ./tmp-variables

	sed -i -e "s/sufix/$SUFIX/g" ./tmp-variables
	sed -i -e "s/prefix/$PREFIX/g" ./tmp-variables

	mv ./tmp-variables ./"$DIR"/data/"$CONTAINER_NAME"-variables

	# starts the base container with the basic set of env vars
	$CONTAINER_RUNTIME run -dt --name "$CONTAINER_NAME" \
	-v "$(pwd)"/"$DIR":/ocp4-upi-powervs -e RELEASE_VER="$OCP_VERSION" --env-file ./"$DIR"/data/"$CONTAINER_NAME"-variables \
	quay.io/powercloud/powervs-container-host:ocp-"$OCP_VERSION" /bin/bash

	echo "*********************************************************************************"
	echo "NOTE: the installation is running from within the container named $CONTAINER_NAME"
	echo "Cluster ID: $PREFIX-$SUFIX 						       " 	 			
	echo "*********************************************************************************"

	# execute the TF deployment from within the container
	$CONTAINER_RUNTIME exec --tty -w /ocp4-upi-powervs "$CONTAINER_NAME" bash -c "./scripts/run-terraform.sh"
}

function run (){

	OCP_VERSIONS=("4.5" "4.6" "4.7")

	if [ -z "$1" ]; then
		echo
		echo "ERROR: Please, select one of the supported versions: ${OCP_VERSIONS[*]}."
		echo "       e.g: ./deploy 4.7"
		echo
		exit 1
	elif [[ ! " ${OCP_VERSIONS[*]} " =~ ${1} ]]; then
		echo
		echo "ERROR: This version of OpenShift ($1) is not supported."
		echo "       Supported versions are: ${OCP_VERSIONS[*]}."
		echo
		exit 1
	else
		TODAY=$(date "+%Y%m%d")
		SUFIX=$(openssl rand -hex 3)
		export TODAY
		export SUFIX
		check_dependencies
		check_variables "$(pwd)"/files/variables
		check_connectivity
		configure "$1"
		create_container "$1"
	fi
}

run "$@"
