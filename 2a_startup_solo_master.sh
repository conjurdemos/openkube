#!/bin/bash
set -eo pipefail

source $DEMO_ROOT/$DEMO_CONFIG_FILE

# directory of yaml
declare CONFIG_DIR=./conjur-service

declare MASTER_POD_NAME=conjur-master
declare ADMIN_PASSWORD=Cyberark1
declare CONJUR_CLUSTER_ACCT=dev
declare CONJUR_CONTEXT=conjur
declare CONJUR_MASTER_DNS_NAME=conjur-master.$CONJUR_CONTEXT.svc.cluster.local
declare CONJUR_FOLLOWER_DNS_NAME=conjur-follower.$CONJUR_CONTEXT.svc.cluster.local

##############################
##############################
# MAIN - takes no command line arguments

main() {
  startup_master
  configure_master
  startup_client
  print_config
}

##############################
##############################


##############################
startup_master() {

  ./etc/set_context.sh $CONJUR_CONTEXT

  # start up conjur services from yaml
  $KUBECTL create -f $CONFIG_DIR/conjur-master-solo.yaml

  # give containers time to get running
  echo "Waiting for conjur-master to launch"
  sleep 5
  while [[ $($KUBECTL exec conjur-master evoke role) != "blank" ]]; do
    echo -n '.'
    sleep 5
  done
  echo "done"
}

##############################
configure_master() {
  ./etc/set_context.sh $CONJUR_CONTEXT

  printf "Configuring solo %s...\n" $MASTER_POD_NAME
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
}

##########################
startup_client() {
  echo "Starting up the client Pod"

  pushd cli_client
  ./deploy.sh
  popd

  ./etc/set_context.sh $CONJUR_CONTEXT
}

##########################
print_config() {
        # get internal/external IP addresses
        EXTERNAL_IP=$($MINIKUBE ip)
        EXTERNAL_PORT=$($KUBECTL describe svc conjur-master | awk '/NodePort:/ {print $2 " " $3}' | awk '/https/ {print $2}' | awk -F "/" '{ print $1 }')
                                # inform user of service ingresses
        printf "\n\n-----\nConjur cluster is ready. Addresses for the Conjur Master service:\n"
        printf "\nInside the cluster: conjur-master.%s.svc.cluster.local\n" $CONJUR_CONTEXT
        printf "\nOutside the cluster: DNS hostname: conjur-master, IP:%s, Port:%s\n\n" $EXTERNAL_IP $EXTERNAL_PORT
}

main "$@"
