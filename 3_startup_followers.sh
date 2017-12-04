#!/bin/bash -x
set -eo pipefail

source $DEMO_ROOT/$DEMO_CONFIG_FILE
declare CONFIG_DIR=conjur-service

main() {
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

main $@
