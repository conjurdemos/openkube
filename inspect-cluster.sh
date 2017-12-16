#!/bin/bash

source $DEMO_ROOT/$DEMO_CONFIG_FILE

$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT
printf "\n\n%s context state:\n----------------\n" $APP_CONTEXT
$KUBECTL get all

$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT
printf "\n\n%s context state:\n----------------\n" $CONJUR_CONTEXT
$KUBECTL get all

printf "\n\nLoad balancer config:\n----------------\n"
$KUBECTL exec haproxy-conjur-master cat /usr/local/etc/haproxy/haproxy.cfg

printf "\n\nStateful node info:\n----------------\n"
cont_list=$($KUBECTL get pods -l app=conjur-node --no-headers \
						| awk '{print $1}')
for cname in $cont_list; do
	crole=$($KUBECTL describe pod $cname | grep "role=" \
						| awk -F "=" '{print $2}')
	cip=$($KUBECTL describe pod $cname | awk '/^IP:/ {print $2}')
	printf "%s, %s, %s\n" $cname $crole $cip
done
printf "\n\n"
