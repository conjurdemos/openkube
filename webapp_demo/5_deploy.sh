#!/bin/bash
set -eo pipefail
source $DEMO_ROOT/$DEMO_CONFIG_FILE

ssl_certificate=$(cat conjur-dev.pem)

$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT

echo Storing non-secret configuration data

# write out conjur ssl cert in configmap
$KUBECTL delete --ignore-not-found=true configmap webapp
$KUBECTL create configmap webapp \
  --from-literal=ssl_certificate="$ssl_certificate"

$KUBECTL create -f webapp.yaml
$KUBECTL create -f webapp-summon.yaml
$KUBECTL create -f webapp_dev.yaml
