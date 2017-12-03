#!/bin/bash -x
set -eo pipefail

declare CONFIG_DIR=./conjur-service

case $ORCHESTRATOR in
  kubernetes)
	declare KUBECTL=kubectl
	;;
  openshift)
	declare KUBECTL=oc
	;;
  *)
	printf "Set ORCHESTRATOR env var to either "kubernetes" or "openshift"\n\n"
	exit -1
esac

declare CONJUR_CONTEXT=conjur

main() {
	./etc/set_context.sh $CONJUR_CONTEXT

	$KUBECTL create -f $CONFIG_DIR/conjur-follower.yaml
exit
	sleep 5		# allow pods to get running

         # get list of follower pods 
        pod_list=$($KUBECTL get pods -lrole=follower --no-headers | awk '{print $1}')
        for pod_name in $pod_list; do
                printf "Configuring follower %s...\n" $pod_name
                # label pod with role
                $KUBECTL label --overwrite pod $pod_name role=follower
                # configure follower
                $KUBECTL cp $CONFIG_DIR/follower-seed.tar $pod_name:/tmp/follower-seed.tar
                $KUBECTL exec $pod_name evoke unpack seed /tmp/follower-seed.tar
                $KUBECTL exec $pod_name -- evoke configure follower -j /etc/conjur.json 
	done
}

main $@
