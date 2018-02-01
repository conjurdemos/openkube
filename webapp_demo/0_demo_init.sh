#!/bin/bash
set -eo pipefail

source $DEMO_ROOT/$DEMO_CONFIG_FILE

main() {
	$DEMO_ROOT/etc/set_context.sh $CONJUR_CONTEXT
	initialize_host_conjur_cli

	$DEMO_ROOT/etc/set_context.sh $APP_CONTEXT
	initialize_users
	build_app
	scope launch		# launch weave scope

	conjur authn logout
}

##########################
initialize_host_conjur_cli() {
	master_pod_name=$($KUBECTL get pods -l app=conjur-node -l role=master --no-headers | awk '{ print $1 }')
	kubectl cp "$master_pod_name:/opt/conjur/etc/ssl/ca.pem" ./conjur-dev.pem

	# get external IP addresses
	EXTERNAL_PORT=$($KUBECTL describe svc conjur-master | awk '/NodePort:/ {print $2 " " $3}' | awk '/https/ {print $2}' | awk -F "/" '{ print $1 }')
	CONJUR_MASTER=

	cat << CONJURRC > conjurrc
appliance_url: https://conjur-master:$EXTERNAL_PORT/api
plugins: [ policy ]
account: dev
cert_file: $PWD/conjur-dev.pem
CONJURRC

	export CONJURRC=$(pwd)/conjurrc
	echo "export CONJURRC=$(pwd)/conjurrc" >> $DEMO_ROOT/$DEMO_CONFIG_FILE
	conjur authn login -u admin -p Cyberark1
	conjur bootstrap
}

##########################
initialize_users() {
	# create demo users, all passwords are foo
	conjur policy load --as-group=security_admin policy/users-policy.yml | tee up-out.json
	ted_pwd=$(cat up-out.json | jq -r '."dev:user:ted"')
	bob_pwd=$(cat up-out.json | jq -r '."dev:user:bob"')
	alice_pwd=$(cat up-out.json | jq -r '."dev:user:alice"')
	carol_pwd=$(cat up-out.json | jq -r '."dev:user:carol"')
	rm up-out.json
	conjur authn login -u ted -p $ted_pwd
	echo "Teds password is foo"
	conjur user update_password << END
foo
foo
END
	conjur authn login -u bob -p $bob_pwd
	echo "Bobs password is foo"
	conjur user update_password << END
foo
foo
END
	conjur authn login -u alice -p $alice_pwd
	echo "Alice password is foo"
	conjur user update_password << END
foo
foo
END
	conjur authn login -u carol -p $carol_pwd
	echo "Carols password is foo"
	conjur user update_password << END
foo
foo
END
}

##########################
build_app() {
	cd build
	./build.sh
	cd ..
}

main $@
