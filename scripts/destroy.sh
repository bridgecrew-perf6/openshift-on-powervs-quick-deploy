#!/usr/bin/env bash

: '
    Copyright (C) 2021 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "bye!"
	exit 1
}

function check_connectivity() {
    
    curl --output /dev/null --silent --head --fail http://cloud.ibm.com
    if [ ! $? -eq 0 ]; then
        echo
        echo "ERROR: please, check your internet connection."
        exit
    fi
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

function destroy () {
	
	CONTAINER=$1
	OCP_VERSION=$(echo $CONTAINER | awk '{split($0,version,"_"); print version[1]}')

	$CONTAINER_RUNTIME stop $CONTAINER
	$CONTAINER_RUNTIME rm $CONTAINER
	$CONTAINER_RUNTIME run -dt --name $CONTAINER -v "$(pwd)"/$CONTAINER:/ocp4-upi-powervs --env-file "$(pwd)"/$CONTAINER/$CONTAINER-variables quay.io/powercloud/powervs-container-host:ocp-$OCP_VERSION /bin/bash
	$CONTAINER_RUNTIME exec -w /ocp4-upi-powervs -it $CONTAINER /bin/bash -c "./run-terraform.sh --destroy"
}

function run () {

	if [ -z $1 ]; then
		echo
		echo "ERROR: please, set the name of the cluster you want to destroy."
		echo "		 e.g ./destroy.sh 4.6_20201228-094723_796c2924dc"
		echo
		exit 1
	else
		check_dependencies
		check_connectivity
		destroy $1
	fi
}

run "$@"