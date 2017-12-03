#!/bin/bash -e
set -o pipefail

			# minishift RAM should be at least 2GB < VM RAM
MINIKUBE_VM_RAM=6144

main() {
	install_docker
	install_vbox
	install_jq
	install_minishift
	install_openshift_cli
	install_kubectl
	install_conjur_cli
	start_minishift
	configure_env
}

install_docker() {
	echo "Installing Docker..."
		# Note we do not start docker here.
		# We will use the docker env in the minishift VM.
	curl -o docker-ce.rpm https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.06.2.ce-1.el7.centos.x86_64.rpm

	sudo yum install -y docker-ce.rpm
	rm docker-ce.rpm
		# add user to docker group to run docker w/o sudo
	sudo sed -i "/^docker:/ s/$/ $(whoami)/" /etc/group
}

install_vbox() {
	echo "Installing VirtualBox..."
	curl -L -o vbox.rpm http://download.virtualbox.org/virtualbox/5.1.26/VirtualBox-5.1-5.1.26_117224_el7-1.x86_64.rpm
	sudo yum install -y vbox.rpm
	rm vbox.rpm
}

install_jq() {
	echo "Installing jq..."
	curl -LO https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64

	chmod a+x jq-linux64
	sudo mv jq-linux64 /usr/local/bin/jq
}

install_kubectl() {
	echo "Installing kubectl..."
	curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	sudo mv ./kubectl /usr/local/bin/kubectl
}

install_minishift() {
	echo "Installing Minishift..."
	printf "\n\n NOT IMPLEMENTED YET!\n\n"
#	chmod +x minishift 
#	sudo mv minishift /usr/local/bin/
}

install_minishift_cli() {
	echo "Installing Minishift CLI..."
	printf "\n\n NOT IMPLEMENTED YET!\n\n"
}

install_conjur_cli() {
	curl -o conjur.rpm -L https://github.com/cyberark/conjur-cli/releases/download/v5.4.0/conjur-5.4.0-1.el6.x86_64.rpm \
  && sudo rpm -i conjur.rpm \
  && rm conjur.rpm
}

start_minishift() {
	minishift config set memory $MINIKUBE_VM_RAM
	minishift start --vm-driver virtualbox
}

configure_env() {
	echo "Configuring environment..."
	sudo chmod a+w /etc/bashrc
	sudo echo PATH=\$PATH:/usr/local/bin >> /etc/bashrc
	sudo chmod go-w /etc/bashrc
	. ~/.bashrc
                        # add conjur master as alias for mk
        sudo chmod a+w /etc/hosts
        mk_ip=$(minishift ip)
        echo "$mk_ip    conjur-master" >> /etc/hosts
        sudo chmod go-w /etc/hosts

	echo "There is no docker daemon started, you will use the"
	echo "minishift docker environment. issue this command:" 
	echo "	eval $(minishift docker-env)"
}

main $@
