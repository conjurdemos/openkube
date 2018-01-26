#!/bin/bash
source $DEMO_ROOT/$DEMO_CONFIG_FILE

conjur authn logout >> /dev/null
conjur authn login
./load_policy.sh k8s_apps.yml
conjur authn logout >> /dev/null

source ./evokecmd.sh

$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT 

webservice=conjur/authn-k8s/minikube/webapp
echo "Initializing the CA certificate and key for webservice:$webservice"
evokecmd conjur-plugin-service authn-k8s rake ca:initialize[$webservice]

