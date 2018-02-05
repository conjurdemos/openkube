#!/bin/bash

source $DEMO_ROOT/$DEMO_CONFIG_FILE

$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT

source ./evokecmd.sh

echo Grabbing the conjur.pem
ssl_certificate=$(evokecmd cat /opt/conjur/etc/ssl/ca.pem)

$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT

echo Storing non-secret configuration data

# write out conjur ssl cert in configmap
$KUBECTL delete --ignore-not-found=true configmap webapp
$KUBECTL create configmap webapp \
  --from-literal=ssl_certificate="$ssl_certificate"

$KUBECTL create -f webapp_dev.yaml
