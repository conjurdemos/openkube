#!/bin/bash
source $DEMO_ROOT/$DEMO_CONFIG_FILE

conjur authn logout >> /dev/null
conjur authn login 
./load_policy.sh authn_k8s.yml
conjur authn logout >> /dev/null
