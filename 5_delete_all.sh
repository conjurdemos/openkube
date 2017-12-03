#!/bin/bash 
set -o pipefail

declare CONJUR_CONTEXT=conjur
case $ORCHESTRATOR in

  kubernetes)
        declare KUBECTL=kubectl
	declare APP_CONTEXT=minikube
        ;;

  openshift)
        declare KUBECTL=oc
	declare APP_CONTEXT=openshift
        ;;

  *)
        printf "Set ORCHESTRATOR env var to either \"kubernetes\" or \"openshift\"\n\n"
        exit -1
esac

#################
main() {
	./etc/set_context.sh $CONJUR_CONTEXT
	delete_follower_all
	delete_webapp_all
	delete_master_all
	rm ./conjur-service/*.tar

	./etc/set_context.sh $APP_CONTEXT
	delete_cli_all
	delete_contexts
}

#################
delete_webapp_all() {
	$KUBECTL delete --ignore-not-found=true -f ./authn_k8s_scale_demo/webapp.yaml
	$KUBECTL delete replicaset -lapp=webapp
	$KUBECTL delete pods -lapp=webapp
}

#################
delete_master_all() {
	$KUBECTL delete --ignore-not-found=true -f ./conjur-service/conjur-master-solo.yaml
	$KUBECTL delete --ignore-not-found=true -f ./conjur-service/conjur-master-headless.yaml
	$KUBECTL delete --ignore-not-found=true -f ./conjur-service/haproxy-conjur-master.yaml
}

#################
delete_follower_all() {
	$KUBECTL delete --ignore-not-found=true -f ./conjur-service/conjur-follower.yaml
}

#################
delete_cli_all() {
	$KUBECTL delete --ignore-not-found=true -f ./cli_client/cli-conjur.yaml
	$KUBECTL delete --ignore-not-found=true configmap cli-conjur
}

#################
delete_contexts() {

		# will want to delete any APP_CONTEXTs if created, currently using cluster name

  case $ORCHESTRATOR in

    kubernetes)
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
