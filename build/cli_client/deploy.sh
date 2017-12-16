#!/bin/bash
set -eo pipefail

source $DEMO_ROOT/$DEMO_CONFIG_FILE

main() {

	$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT

	echo Grabbing the conjur.pem
	ssl_certificate=$(evokecmd cat /opt/conjur/etc/ssl/ca.pem)

	$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT

	echo Storing non-secret configuration data

	# write out conjur ssl cert in configmap
	$KUBECTL delete --ignore-not-found=true configmap cli-conjur
	$KUBECTL create configmap cli-conjur \
	  --from-literal=ssl_certificate="$ssl_certificate"

	$KUBECTL create -f cli-conjur.yaml
}

######################
evokecmd() {

  pod_list=$($KUBECTL get pod -l app=conjur-node --no-headers | awk '{ print $1 }')
  for pod_name in $pod_list; do
	crole=$($KUBECTL exec $pod_name  -- sh -c "evoke role")
	if [[ $crole == master ]]; then
  		master_pod=$pod_name
		break
	fi
  done
  interactive=$1
  if [ $interactive = '-i' ]; then
    shift
    $KUBECTL exec -i $master_pod -- $@
  else
    $KUBECTL exec $master_pod -- $@
  fi
}

main $@
