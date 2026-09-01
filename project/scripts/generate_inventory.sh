#!/usr/bin/env bash
# Generates inventory/hosts.ini with WSL paths to the Vagrant SSH keys.
set -euo pipefail
cd "$(dirname "$0")/.."
project="$(pwd)"

# The Vagrantfile keeps config.ssh.insert_key = false, so the VMs share the
# stock insecure key; a per-machine key is used when one exists.
shared_key="$(ls /mnt/c/Users/*/.vagrant.d/insecure_private_keys/vagrant.key.rsa \
                 /mnt/c/Users/*/.vagrant.d/insecure_private_key 2>/dev/null | head -1)"

# Keys on /mnt/c are world-readable and ssh refuses them, so copy into $HOME.
mkdir -p "$HOME/.ansible/keys"
key_for() {
  local vm="$1" src="$project/.vagrant/machines/$1/virtualbox/private_key"
  [ -f "$src" ] || src="$shared_key"
  install -m 600 "$src" "$HOME/.ansible/keys/$vm"
  printf '%s' "$HOME/.ansible/keys/$vm"
}

mkdir -p inventory
cat > inventory/hosts.ini <<EOF
[web]
web ansible_host=192.168.57.10 ansible_ssh_private_key_file=$(key_for web)

[app]
app1 ansible_host=192.168.57.11 ansible_ssh_private_key_file=$(key_for app1)
app2 ansible_host=192.168.57.12 ansible_ssh_private_key_file=$(key_for app2)

[db_primary]
app1

[db_replica]
app2

[observability]
elk ansible_host=192.168.57.13 ansible_ssh_private_key_file=$(key_for elk)

[all:vars]
ansible_user=vagrant
ansible_become=true
ansible_timeout=60
; ControlMaster keeps one SSH connection per host alive, otherwise a
; connection-per-task run exhausts sshd MaxStartups on the small VMs and
; Ansible reports "timed out during banner exchange".
; ControlPath is deliberately left to Ansible: a literal %h here is not expanded
; by ssh and every host would share one socket.
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=120s -o ServerAliveInterval=15 -o ServerAliveCountMax=6'
EOF
echo "wrote inventory/hosts.ini"
