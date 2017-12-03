#!/bin/bash

                        # context is a namespace in k8s, project in openshift
declare CONJUR_CONTEXT=conjur

case $ORCHESTRATOR in

  kubernetes)
        declare KUBECTL=kubectl
        declare APP_CONTEXT=minikube
        eval $(minikube docker-env)
        ;;

  openshift)
        declare KUBECTL=oc
        declare APP_CONTEXT=openshift
        eval $(minishift oc-env)
        eval $(minishift docker-env)
        ;;

  *)
        printf "Set ORCHESTRATOR env var to either "kubernetes" or "openshift"\n\n"
        exit -1
esac

../etc/set_context.sh $APP_CONTEXT

$KUBECTL delete --ignore-not-found=true -f webapp.yaml
$KUBECTL delete --ignore-not-found=true -f webapp-summon.yaml
$KUBECTL delete --ignore-not-found=true configmap webapp
