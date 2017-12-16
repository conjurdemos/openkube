#!/bin/bash 
# syncs clock in vm w/ host clock
# run this when you can't login to the conjur UI
source $DEMO_ROOT/$DEMO_CONFIG_FILE
$MINIKUBE ssh -- docker run -i --rm --privileged --pid=host debian nsenter -t 1 -m -u -n -i date -u $(date -u +%m%d%H%M%Y)
