#!/bin/bash -e
set -o pipefail

source $DEMO_ROOT/$DEMO_CONFIG_FILE

conjur authn logout >> /dev/null
conjur authn login


new_pwd=$(openssl rand -hex 12)
error_msg=$(conjur variable values add db/password $new_pwd 2>&1 >/dev/null)
if [[ "$error_msg" = "" ]]; then
	echo $(date +%X) "New db password is:" $new_pwd
else
	echo $error_msg
fi
