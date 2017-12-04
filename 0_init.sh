#!/bin/bash 
set -eo pipefail

case $ORCHESTRATOR in
  kubernetes) ;;
  openshift) ;;
  *)
	printf "Set ORCHESTRATOR env var to either "kubernetes" or "openshift"\n\n"
	exit -1
esac

declare DEMO_CONFIG_FILE=openkube.conf
declare CONJUR_CONTEXT=conjur	# namespace/project for Conjur
declare APP_CONTEXT=webapp	# namespace/project for demo app

main() {
  startup_env
  create_demo_config_file
  source ./$DEMO_CONFIG_FILE
  create_contexts
  printf "\n\n-----\nNow execute this command to setup your demo environment:\n"
  printf "\n\tsource ./%s\n\n" $DEMO_CONFIG_FILE
}

#############################
create_demo_config_file() {

  rm -f $DEMO_CONFIG_FILE
  touch $DEMO_CONFIG_FILE
  echo "export DEMO_ROOT=$(pwd)" >> $DEMO_CONFIG_FILE
  echo "export DEMO_CONFIG_FILE=$DEMO_CONFIG_FILE" >> $DEMO_CONFIG_FILE
  echo "export CONJUR_CONTEXT=$CONJUR_CONTEXT" >> $DEMO_CONFIG_FILE
  echo "export APP_CONTEXT=$APP_CONTEXT" >> $DEMO_CONFIG_FILE

  case $ORCHESTRATOR in
    kubernetes)
	echo "export ORCHESTATOR=kubernetes" >> $DEMO_CONFIG_FILE
	echo "export MINIKUBE=minikube" >> $DEMO_CONFIG_FILE

	echo "export KUBECTL=kubectl" >> $DEMO_CONFIG_FILE
						# default cluster config file
	echo "export KUBECONFIG=~/.kube/config" >> $DEMO_CONFIG_FILE
	minikube docker-env >> $DEMO_CONFIG_FILE
	;;

    openshift)
	echo "export ORCHESTATOR=openshift" >> $DEMO_CONFIG_FILE
	echo "export MINIKUBE=minishift" >> $DEMO_CONFIG_FILE

	echo "export KUBECTL=oc" >> $DEMO_CONFIG_FILE
						# default cluster config file
	echo "export KUBECONFIG=~/.minishift/machines/minishift_kubeconfig" >> $DEMO_CONFIG_FILE
	minishift oc-env >> $DEMO_CONFIG_FILE
	minishift docker-env >> $DEMO_CONFIG_FILE
	;;

    *)
	printf "Set ORCHESTRATOR env var to either "kubernetes" or "openshift"\n\n"
	exit -1
  esac
}


##############################
startup_env() {
  case $ORCHESTRATOR in

	kubernetes)
		if [[ "$(minikube status | awk '/minikube:/ {print $2}')" != "Running" ]]; then
			minikube start --memory 8192 
		fi  
		eval $(minikube docker-env)
		;;


	openshift)
		if [[ "$(minishift status | awk '/Minishift:/ {print $2}')" != "Running" ]]; then
			minishift start --memory 8192 --vm-driver virtualbox --show-libmachine-logs  
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
create_contexts() {

  case $ORCHESTRATOR in

	kubernetes)
							# create context for apps
		if kubectl get namespace | grep -w $APP_CONTEXT > /dev/null; then
		    echo "Namespace '$APP_CONTEXT' exists. I wont create it."
		else
		    kubectl create namespace $APP_CONTEXT
		fi
		kubectl config set-context $APP_CONTEXT --namespace=$APP_CONTEXT --cluster=minikube --user=minikube

							# create context for conjur
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
			oc new-project $CONJUR_CONTEXT --display-name="Conjur Openshift" --description="Demonstration of Conjur running in Openshift."
			sleep 2
					# add anyuid security context constraint to default service account
					# this allows processes to run as root within containers in this project/namespace only
					# addition of this privilege grant was provoked by inability to unpack Conjur seed files
			oc adm policy add-scc-to-user anyuid -z default

					# HAproxy needs to be able to list master/standby pods to update its config
			oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:$CONJUR_CONTEXT:default

					# below is apparently a better, more precisely scoped privilege grant practice 
					# using a specific service account to be referenced by deployment config files.
#			oc create serviceaccount useroot
#			oc adm policy add-scc-to-user anyuid -z useroot
#			oc patch dc/myAppNeedsRoot \
#					--patch '{"spec":{"template":{"spec":{"serviceAccountName": "useroot"}}}}'
		fi 

  		if oc projects | grep -w $APP_CONTEXT > /dev/null; then
			echo "Project '$APP_CONTEXT' exists, not going to create it."
		else
			oc new-project $APP_CONTEXT --display-name="Conjur webapp application" --description="For demonstration of Conjur container authentication and secrets retrieval."
					# add anyuid security context constraint to default service account
					# this allows processes to run as root within containers in this project/namespace only
					# addition of this grant was provoked by webapp authenticators inability to mkdir
			oc adm policy add-scc-to-user anyuid -z default
		fi
		;;

	*) printf "\ncoding error in case statement in $0.\n"
		exit -1
  esac
}

main $@
