#!/bin/bash
set -eo pipefail

source $DEMO_ROOT/$DEMO_CONFIG_FILE

# directory of yaml
declare CONFIG_DIR=conjur-service

declare MASTER_POD_NAME=""
declare ADMIN_PASSWORD=Cyberark1
declare CONJUR_CLUSTER_ACCT=dev
declare CONJUR_NAMESPACE=conjur
declare CONJUR_MASTER_DNS_NAME=conjur-master.$CONJUR_NAMESPACE.svc.cluster.local
declare CONJUR_FOLLOWER_DNS_NAME=conjur-follower.$CONJUR_NAMESPACE.svc.cluster.local

##############################
##############################
# MAIN - takes no command line arguments

main() {
	startup_conjur_service
	configure_conjur_cluster
	start_load_balancer
	startup_client
	start_sync_replication
	start_followers
	print_config
	scope launch
}

##############################
##############################

startup_conjur_service() {
	./etc/set_context.sh $CONJUR_CONTEXT

			# start up conjur services from yaml
	case $ORCHESTRATOR in
		kubernetes)
			kubectl create -f $DEMO_ROOT/$CONFIG_DIR/conjur-master-headless.yaml
			;;
		openshift)
			oc create -f $DEMO_ROOT/$CONFIG_DIR/conjur-master-headless-nostateful.yaml
			;;
		*)
			printf "\n\nCase stmt error in $0.\n\n"
	esac
	sleep 2

	# get list of the master/standby candidates
	pod_list=$($KUBECTL get pods -l app=conjur-node --no-headers \
			| awk '{ print $1 }')
	# select first pod in list to be master
	MASTER_POD_NAME=$(echo $pod_list | awk '{print $1}' )
	# give containers time to get running
	echo "Waiting for pods to launch"
	sleep 5
	while [[ $($KUBECTL exec $MASTER_POD_NAME evoke role) != "blank" ]]; do
  		echo -n '.'
  		sleep 5
	done
	echo "done"
}

##############################
# Configure cluster based on role labels
# 
configure_conjur_cluster() {
	./etc/set_context.sh $CONJUR_CONTEXT

	$KUBECTL label --overwrite pod $MASTER_POD_NAME role=master

	printf "Configuring conjur-master %s...\n" $MASTER_POD_NAME
	# configure Conjur master server using evoke
	$KUBECTL exec $MASTER_POD_NAME -- evoke configure master \
		-j /etc/conjur.json \
		-h $CONJUR_MASTER_DNS_NAME \
		--master-altnames conjur-master \
		--follower-altnames conjur-follower \
		-p $ADMIN_PASSWORD \
		$CONJUR_CLUSTER_ACCT

	printf "Preparing seed files...\n"
	# prepare seed files for standbys and followers
	$KUBECTL exec $MASTER_POD_NAME evoke seed standby > $CONFIG_DIR/standby-seed.tar
	$KUBECTL exec $MASTER_POD_NAME evoke seed follower $CONJUR_FOLLOWER_DNS_NAME > $CONFIG_DIR/follower-seed.tar

	# get master IP address for standby config
	MASTER_POD_IP=$($KUBECTL describe pod $MASTER_POD_NAME | awk '/IP:/ {print $2}')

	# get list of the other pods 
	pod_list=$($KUBECTL get pods -l role=unset --no-headers \
			| awk '{ print $1 }')
	for pod_name in $pod_list; do
		printf "Configuring standby %s...\n" $pod_name
		# label pod with role
		$KUBECTL label --overwrite pod $pod_name role=standby
		$KUBECTL cp $CONFIG_DIR/standby-seed.tar $pod_name:/tmp/standby-seed.tar
		$KUBECTL exec $pod_name evoke unpack seed /tmp/standby-seed.tar
		$KUBECTL exec $pod_name -- evoke configure standby -j /etc/conjur.json -i $MASTER_POD_IP
	done

}

##########################
start_load_balancer() {
	./etc/set_context.sh $CONJUR_CONTEXT

	# start up load balancer
	$KUBECTL create -f $DEMO_ROOT/$CONFIG_DIR/haproxy-conjur-master.yaml
	sleep 5
	pushd $DEMO_ROOT/etc && ./update_haproxy.sh haproxy-conjur-master && popd
}

##########################
startup_client() {
	echo "Starting up the client Pod"

	pushd $DEMO_ROOT/build/cli_client
	./deploy.sh
	popd
}

##########################
start_sync_replication() {
	./etc/set_context.sh $CONJUR_CONTEXT

	num_standbys=$($KUBECTL get pods -l role=standby --no-headers | wc -l)
	if [ $num_standbys > 1 ]; then
		printf "Starting synchronous replication...\n"
		$KUBECTL exec $MASTER_POD_NAME -- bash -c "evoke replication sync"
	else
		printf "At least 2 standbys recommended for sync failover.\n"
	fi
}

##########################
start_followers() {
	./etc/set_context.sh $CONJUR_CONTEXT

	$KUBECTL create -f $DEMO_ROOT/$CONFIG_DIR/conjur-follower.yaml

	sleep 5		# allow pods to get running

		# get list of follower pods 
	pod_list=$($KUBECTL get pods -lrole=follower --no-headers | awk '{print $1}')
	for pod_name in $pod_list; do
		printf "Configuring follower %s...\n" $pod_name
		# label pod with role
		$KUBECTL label --overwrite pod $pod_name role=follower
		# configure follower
		$KUBECTL cp $DEMO_ROOT/$CONFIG_DIR/follower-seed.tar $pod_name:/tmp/follower-seed.tar
		$KUBECTL exec $pod_name evoke unpack seed /tmp/follower-seed.tar
		$KUBECTL exec $pod_name -- evoke configure follower -j /etc/conjur.json 
	done
}

##########################
print_config() {
	# get internal/external IP addresses
	EXTERNAL_IP=$($MINIKUBE ip)
	EXTERNAL_PORT=$($KUBECTL describe svc conjur-master | awk '/NodePort:/ {print $2 " " $3}' | awk '/https/ {print $2}' | awk -F "/" '{ print $1 }')
				# inform user of service ingresses
	printf "\n\n-----\nConjur cluster is ready. Addresses for the Conjur Master service:\n\n"
	printf "Inside the cluster:\n\t conjur-master.%s.svc.cluster.local\n" $CONJUR_CONTEXT
	printf "Outside the cluster:\n\tDNS hostname: conjur-master, IP:%s, Port:%s\n\n" $EXTERNAL_IP $EXTERNAL_PORT
}

main $@
