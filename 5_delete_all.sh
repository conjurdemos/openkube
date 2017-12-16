#!/bin/bash 
set -o pipefail

printf "\n\nBringing down all running containers.\n"
printf "\n\n\tThis will completely destroy your currently running environment - proceed?\n\n"
select yn in "Yes" "No"; do
  case $yn in
      Yes ) break;;
      No ) exit -1;;
  esac
done

if [[ "$ORCHESTRATOR" == "" ]]; then
	printf "\nSet env var ORCHESTRATOR to either 'kubernetes' or 'openshift'.\n\n"
	exit -1
fi

source $DEMO_ROOT/$DEMO_CONFIG_FILE

declare CONFIG_DIR=conjur-service

#################
main() {
	$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT
	delete_master_all

	$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT
	delete_cli_all

	$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT
	delete_follower_all
	rm $DEMO_ROOT/$CONFIG_DIR/*.tar

	$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT
	delete_apps
	$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT

	delete_contexts
	printf "\n-----\nConjur environment purged, resources still running:\n\n"
	$KUBECTL get all --all-namespaces
}

#################
delete_master_all() {
	$KUBECTL delete --ignore-not-found=true -f $DEMO_ROOT/$CONFIG_DIR/conjur-master-solo.yaml
	$KUBECTL delete --ignore-not-found=true -f $DEMO_ROOT/$CONFIG_DIR/conjur-master-headless.yaml
	$KUBECTL delete --ignore-not-found=true -f $DEMO_ROOT/$CONFIG_DIR/conjur-master-headless-nostateful.yaml
	$KUBECTL delete pods -l app=conjur-node
	$KUBECTL delete --ignore-not-found=true -f $DEMO_ROOT/$CONFIG_DIR/haproxy-conjur-master.yaml
}

#################
delete_follower_all() {
	$KUBECTL delete --ignore-not-found=true -f $DEMO_ROOT/$CONFIG_DIR/conjur-follower.yaml
}

#################
delete_cli_all() {
	$KUBECTL delete --ignore-not-found=true -f $DEMO_ROOT/build/cli_client/cli-conjur.yaml
	$KUBECTL delete --ignore-not-found=true configmap cli-conjur
}

#################
delete_apps() {
	pushd $DEMO_ROOT/webapp_demo && ./6_delete_deployment.sh && popd
}

#################
delete_contexts() {

  case $ORCHESTRATOR in

    kubernetes)
	kubectl delete namespace $APP_CONTEXT
	kubectl delete namespace $CONJUR_CONTEXT
	printf "\n\n-----\nWaiting for %s namespace deletion to complete...\n" $CONJUR_CONTEXT
	while : ; do
		printf "..."
		if [[ "$(kubectl get namespaces| grep $CONJUR_CONTEXT)" != "" ]]; then
			sleep 5
		else
			break
		fi
	done
	printf "\n"
        ;;

    openshift)
	oc project default
	oc delete project $APP_CONTEXT
	oc delete project $CONJUR_CONTEXT
	printf "\n\n-----\nWaiting for %s project deletion to complete...\n" $CONJUR_CONTEXT
	while : ; do
		printf "..."
		if [[ "$(oc projects | grep $CONJUR_CONTEXT)" != "" ]]; then
			sleep 5
		else
			break
		fi
	done
	printf "\n"
        ;;

    *)
        printf "error in case stmt in $0\n\n"
        exit -1

  esac
}

main $@
