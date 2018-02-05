#!/bin/bash -e
if [[ "$(ls *.deb)" == "" ]]; then
	echo
	echo "You need to have the authn-k8s.deb in this directory."
	echo "See https://github.com/conjurinc/authn-k8s"
	echo
	exit 1
fi
# builds Ubuntu client w/ conjur CLI installed but not initialized
docker build -t conjur-appliance:local -f Dockerfile .
