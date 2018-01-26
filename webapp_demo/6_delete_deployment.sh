#!/bin/bash

source $DEMO_ROOT/$DEMO_CONFIG_FILE

$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT

$KUBECTL delete --ignore-not-found=true -f webapp.yaml
$KUBECTL delete --ignore-not-found=true -f webapp_dev.yaml
$KUBECTL delete --ignore-not-found=true -f webapp-summon.yaml
$KUBECTL delete --ignore-not-found=true configmap webapp
