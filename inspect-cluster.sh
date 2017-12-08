#!/bin/bash

source $DEMO_ROOT/$DEMO_CONFIG

printf "\n\nCluster state:\n----------------\n"
$KUBECTL get all

printf "\n\nLoad balancer config:\n----------------\n"
$KUBECTL exec haproxy-conjur-master cat /usr/local/etc/haproxy/haproxy.cfg
$KUBECTL exec haproxy-conjur-master cat /usr/local/etc/haproxy/http_servers.cfg
$KUBECTL exec haproxy-conjur-master cat /usr/local/etc/haproxy/pg_servers.cfg

printf "\n\nStateful node info:\n----------------\n"
cont_list=$($KUBECTL get pods -l name=conjur-node --no-headers \
						| awk '{print $1}')
for cname in $cont_list; do
	crole=$($KUBECTL describe pod $cname | grep "role=" \
						| awk -F "=" '{print $2}')
	cip=$($KUBECTL describe pod $cname | awk '/^IP:/ {print $2}')
	printf "%s, %s, %s\n" $cname $crole $cip
done
printf "\n\n"
