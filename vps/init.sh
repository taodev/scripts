#!/bin/bash
set -eo pipefail

HOSTNAME=""
SSHPORT="2443"
while getopts ":np:" opt; do
  case $opt in
    n) HOSTNAME="$OPTARG" ;; 
		p) SSHPORT="$OPTARG" ;;
  esac
done
shift $((OPTIND-1))

# 设置主机名
if [ -n "$HOSTNAME" ]; then
  hostnamectl set-hostname "$HOSTNAME"
fi

# 修改 sshd_config
SSH_CONFIG_PATH=./sshd_config
cp -f $SSH_CONFIG_PATH $SSH_CONFIG_PATH.bak
sed -i "/Port 22/c\Port ${SSHPORT}" $SSH_CONFIG_PATH

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
