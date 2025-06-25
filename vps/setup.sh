#!/bin/bash
set -eo pipefail

HOSTNAME=""
SSHPORT="2443"
INSTALL_DOCKER=0
YES=0
while getopts ":n:p:dy" opt; do
  case $opt in
    n) HOSTNAME="$OPTARG" ;; 
		p) SSHPORT="$OPTARG" ;;
		d) INSTALL_DOCKER=1 ;;
		y) YES=1 ;;
  esac
done
shift $((OPTIND-1))

# 设置主机名
if [ -n "$HOSTNAME" ]; then
  hostnamectl set-hostname "$HOSTNAME"
fi

setup_ssh() {
	echo "ssh-port: ${SSHPORT}"

	if [ $YES -ne 1 ]; then
		read -p "是否修改 ssh 端口 (y/N)? " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			return
		fi
	fi

	# 修改 sshd_config
	SSH_CONFIG_PATH=/etc/ssh/sshd_config
	cp -f $SSH_CONFIG_PATH $SSH_CONFIG_PATH.bak
	sed -i "/#Port/c\Port ${SSHPORT}" $SSH_CONFIG_PATH

	sed -i '/ssh_host_rsa_key/c\#HostKey /etc/ssh/ssh_host_rsa_key' $SSH_CONFIG_PATH
	sed -i '/ssh_host_ecdsa_key/c\#HostKey /etc/ssh/ssh_host_ecdsa_key' $SSH_CONFIG_PATH
	sed -i '/ssh_host_ed25519_key/c\HostKey /etc/ssh/ssh_host_ed25519_key' $SSH_CONFIG_PATH

	sed -i '/#PermitRootLogin/c\PermitRootLogin yes' $SSH_CONFIG_PATH
	sed -i '/#PasswordAuthentication/c\PasswordAuthentication no' $SSH_CONFIG_PATH

	sed -i '/#AllowTcpForwarding/c\AllowTcpForwarding yes' $SSH_CONFIG_PATH
	sed -i '/#GatewayPorts/c\GatewayPorts yes' $SSH_CONFIG_PATH
	sed -i '/#TCPKeepAlive/c\TCPKeepAlive yes' $SSH_CONFIG_PATH
	sed -i '/#ClientAliveInterval/c\ClientAliveInterval 60' $SSH_CONFIG_PATH
	sed -i '/#ClientAliveCountMax/c\ClientAliveCountMax 10' $SSH_CONFIG_PATH

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
			ubuntu|debian)
				echo "restart ssh"
				systemctl restart ssh ;;
			centos|alinux|rocky|almalinux)
				echo "restart sshd"
				systemctl restart sshd ;;
			*)
				echo "Unknown OS: $ID"
				;;
		esac
	else
		echo "/etc/os-release not found"
	fi
}

setup_ssh

install_docker_ubuntu() {
	# 安装 docker
	# Add Docker's official GPG key:
	apt-get update
	apt-get install ca-certificates curl -y
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
		$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
		tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt-get update

	apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
	apt-get clean all

	systemctl enable docker
	systemctl start docker
}

install_docker_centos() {
	dnf -y install dnf-plugins-core
	dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	dnf clean all

	systemctl enable docker
	systemctl start docker
}

install_docker_alinux() {
	dnf config-manager --add-repo=https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	dnf -y update 
	dnf -y install dnf-plugin-releasever-adapter --repo alinux3-plus

	dnf -y install dnf-plugins-core
	dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	dnf clean all

	systemctl enable docker
	systemctl start docker
}

install_docker() {
	if [ $INSTALL_DOCKER -ne 1 ]; then
		echo "skip install docker"
		return
	fi

	if [ $YES -ne 1 ]; then
		read -p "是否安装 Docker (y/N)? " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			return
		fi
	fi

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
			ubuntu|debian)
				install_docker_ubuntu
				;;
			centos|rocky|almalinux)
				install_docker_centos
				;;
			alinux)
				install_docker_alinux
				;;
			*)
				echo "Unknown OS: $ID"
				;;
		esac
	else
		echo "/etc/os-release not found"
	fi
}

install_docker