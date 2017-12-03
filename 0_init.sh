#!/bin/bash -x
set -eo pipefail

declare CONJUR_CONTEXT=conjur

case $ORCHESTRATOR in
  kubernetes)
	declare KUBECTL=kubectl
						# default cluster config file
	declare KUBECONFIG=~/.kube/config
	;;
  openshift)
	declare KUBECTL=oc
						# default cluster config file
	declare KUBECONFIG=~/.minishift/machines/minishift_kubeconfig
	;;
  *)
	printf "Set ORCHESTRATOR env var to either "kubernetes" or "openshift"\n\n"
	exit -1
esac

main() {
  startup_env
  create_context
}

##############################
##############################

##############################
# STEP 1 - startup environment
startup_env() {
  case $ORCHESTRATOR in

	kubernetes)
		if [[ "$(minikube status | awk '/minikube:/ {print $2}')" == "Stopped" ]]; then
			minikube start
		fi  
		eval $(minikube docker-env)
		;;


	openshift)
		if [[ "$(minishift status | awk '/Minishift:/ {print $2}')" == "Stopped" ]]; then
			minishift start \
				--memory 8192 --cpus 2 \
				--vm-driver virtualbox \
				--show-libmachine-logs 
		fi  
			  # set path to the minishift CLI and use the minishift docker environment
		eval $(minishift oc-env)
		eval $(minishift docker-env)
		;;

	*)
		printf "\ncoding error in case stmt in $0.\n\n"
		exit -1
  esac
}

##############################
create_context() {

  case $ORCHESTRATOR in

	kubernetes)
		if kubectl get namespace | grep -w $CONJUR_CONTEXT > /dev/null; then
		    echo "Namespace '$CONJUR_CONTEXT' exists. I wont create it."
		else
		    kubectl create namespace $CONJUR_CONTEXT
		fi
		kubectl config set-context $CONJUR_CONTEXT --namespace=$CONJUR_CONTEXT --cluster=minikube --user=minikube
		;;

	openshift)
		oc login -u system:admin > /dev/null
		oc project default
  		if oc projects | grep -w $CONJUR_CONTEXT > /dev/null; then
			echo "Project '$CONJUR_CONTEXT' exists, switching to it."
			oc project $CONJUR_CONTEXT > /dev/null
		else
			oc new-project $CONJUR_CONTEXT --display-name="Conjur Openshift Demo" --description="Demonstration of Conjur running in Openshift."
			sleep 2
					# add privileged security context constraint to default service account
					# this allows processes to run as root within containers in this project/namespace only
					# addition of this privilege grant was provoked by inability to unpack Conjur seed files
			oc adm policy add-scc-to-user privileged system:serviceaccount:$CONJUR_CONTEXT:default

					# HAproxy needs to be able to list master/standby pods to update its config
			oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:$CONJUR_CONTEXT:default

					# below is apparently a better, more precisely scoped privilege grant practice 
					# using a specific service account to be referenced by deployment config files.
					# its not clear if deployment needs to be running to apply patch
#			oc create serviceaccount useroot
#			oc adm policy add-scc-to-user anyuid -z useroot
#			oc patch dc/myAppNeedsRoot \
#					--patch '{"spec":{"template":{"spec":{"serviceAccountName": "useroot"}}}}'
		fi 
		;;

	*) printf "\ncoding error in case statement in $0.\n"
		exit -1
  esac
}

main $@
