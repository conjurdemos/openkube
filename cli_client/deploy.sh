#!/bin/bash -ex

declare CONJUR_CONTEXT=conjur
case $ORCHESTRATOR in

  kubernetes)
	declare APP_CONTEXT=minikube
	declare KUBECTL=kubectl
	;;

  openshift)
	declare APP_CONTEXT=openshift
	declare KUBECTL=oc
	oc login -u system:admin
	;;

  *)
	printf "Set ORCHESTRATOR env var to either "kubernetes" or "openshift"\n\n"
	exit -1
esac

main() {

	../etc/set_context.sh $CONJUR_CONTEXT

	echo Grabbing the conjur.pem
	ssl_certificate=$(evokecmd cat /opt/conjur/etc/ssl/ca.pem)

	../etc/set_context.sh $APP_CONTEXT

	echo Storing non-secret configuration data

	# write out conjur ssl cert in configmap
	$KUBECTL delete --ignore-not-found=true configmap cli-conjur
	$KUBECTL create configmap cli-conjur \
	  --from-literal=ssl_certificate="$ssl_certificate"

	$KUBECTL create -f cli-conjur.yaml
}

######################
evokecmd() {

  master_pod=$($KUBECTL get pod -l role=master --no-headers | awk '{ print $1 }')
  interactive=$1
  if [ $interactive = '-i' ]; then
    shift
    $KUBECTL exec -i $master_pod -- $@
  else
    $KUBECTL exec $master_pod -- $@
  fi
}

main "$@"
