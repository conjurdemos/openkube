#!/bin/bash
case $ORCHESTRATOR in
  kubernetes) 	minikube ssh sudo systemctl status docker
		;;
  openshift)  	minishift ssh sudo systemctl status docker
		;;
  *)		printf "Set env var ORCHESTRATOR to either "kubernetes" or "openshift"\n\n"
esac
