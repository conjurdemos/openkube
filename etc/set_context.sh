#!/bin/bash
set -eo pipefail

# general utility for switching projects/namespaces/contexts in k8s & openshift
# expects exactly 1 argument - either a namespace or project name.

if [[ $# != 1 ]]; then
	printf "Error in %s/%s - expecting 1 arg.\n" $(pwd) $0
	exit -1
fi

case $ORCHESTRATOR in

    kubernetes)
        kubectl config use-context $1
        ;;

    openshift)
        oc login -u system:admin > /dev/null
        oc project $1 > /dev/null
        ;;

    *)
        printf "\nerror in $0\n\n"
	printf "set ORCHESTRATOR env var to either "kubernetes" or "openshift".\n\n"
esac


