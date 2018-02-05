#!/bin/bash
set -eo pipefail

# Edit the line below with the path to the Conjur appliance image tarfile
CONJUR_APPLIANCE_TAR=~/conjur-install-images/conjur-appliance-4.9.12.0.tar

# after running this script, the demo will run w/o internet access

source $DEMO_ROOT/$DEMO_CONFIG_FILE

main() {
	if [[ ! "$SKIP_LOAD_AND_TAG_IMAGE" == "true" ]]; then
		load_conjur_image
		tag_conjur_image
	fi
	build_appliance_image	# adds authn_k8s service to appliance
	build_haproxy_image
	build_cli_client_image
	build_demo_app_image
	install_weavescope
}

##########################
load_conjur_image() {
	if [[ "$CONJUR_APPLIANCE_TAR" == "" ]]; then
		echo "Edit load_conjur_image() to point to point to set CONJUR_APPLIANCE_TARFILE w/ the path to your conjur-appliance tarfile."
		exit
	fi
	docker load -i $CONJUR_APPLIANCE_TAR
}

tag_conjur_image() {
	# tags image regardless if it was loaded or pulled
	IMAGE_NAME=$(docker images | awk '/conjur-appliance/ { print $1":"$2; exit}')
	docker tag $IMAGE_NAME conjur-appliance:4.9-stable
}

##########################
build_appliance_image() {
# Assumptions:
# - conjur-appliance:4.9-stable exists in the Minikube Docker engine.
# - You have the artifact "conjur-authn-k8s_${AUTHN_K8S_VERSION}_amd64.deb" in the conjur_server_build directory.

	pushd $DEMO_ROOT/build/conjur_server_build
	./build.sh
	popd
}

##########################
build_haproxy_image() {
	pushd $DEMO_ROOT/build/haproxy
	./build.sh
	popd
}

##########################
build_cli_client_image() {
	pushd $DEMO_ROOT/build/cli_client/build
	./build.sh
	popd
}

##########################
build_demo_app_image() {
        pushd $DEMO_ROOT/webapp_demo/build
        ./build.sh
        popd
}

##########################
install_weavescope() {
        # setup weave scope for visualization
        weave_image=$(docker images | awk '/weave/ {print $1}')
        if [[ "$weave_image" == "" ]]; then
                sudo curl -L git.io/scope -o /usr/local/bin/scope
		chmod a+x /usr/local/bin/scope
        fi
}

main $@
