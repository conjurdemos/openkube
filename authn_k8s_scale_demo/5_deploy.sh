#!/bin/bash -e

                        # context is a namespace in k8s, project in openshift
declare CONJUR_CONTEXT=conjur

case $ORCHESTRATOR in
  kubernetes)
        declare KUBECTL=kubectl
	declare CLUSTER_CONTEXT=minikube
        eval $(minikube docker-env)
        ;;
  openshift)
        declare KUBECTL=oc
	declare CLUSTER_CONTEXT=openshift
        eval $(minishift oc-env)
        eval $(minishift docker-env)
        ;;
  *)
        printf "Set ORCHESTRATOR env var to either "kubernetes" or "openshift"\n\n"
        exit -1
esac

../etc/set_context.sh $CONJUR_CONTEXT

conjur authn logout >> /dev/null
conjur authn login

source ./evokecmd.sh

../etc/set_context.sh $CONJUR_CONTEXT

echo Grabbing the conjur.pem
ssl_certificate=$(evokecmd cat /opt/conjur/etc/ssl/ca.pem)

../etc/set_context.sh $CLUSTER_CONTEXT

echo Storing non-secret configuration data

# write out conjur ssl cert in configmap
$KUBECTL delete --ignore-not-found=true configmap webapp
$KUBECTL create configmap webapp \
  --from-literal=ssl_certificate="$ssl_certificate"

export CLIENT_API_KEY=$(conjur host rotate_api_key -h conjur/authn-k8s/minikube/default/client)
echo Environment token: $CLIENT_API_KEY

# save client API key as k8s secret
$KUBECTL delete --ignore-not-found=true secret conjur-client-api-key
$KUBECTL create secret generic conjur-client-api-key --from-literal "api-key=$CLIENT_API_KEY"

$KUBECTL create -f webapp.yaml
$KUBECTL create -f webapp-summon.yaml
