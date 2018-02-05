#!/bin/bash
set -eo pipefail
printf "\nThis script will delete any minishift and minikube VMs and their config files.\n"
printf "\n\n\tDo you want to proceed?\n"
select yn in "Yes" "No"; do
  case $yn in
      Yes ) break;;
      No ) exit -1;;
  esac
done
minishift delete
rm -rf ~/.minishift
minikube delete
rm -rf ~/.minikube ~/.kube
