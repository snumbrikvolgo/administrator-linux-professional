#!/usr/bin/env bash
# Generates inventory/hosts.ini with WSL paths to the Vagrant SSH keys.
set -euo pipefail
cd "$(dirname "$0")/.."
project="$(pwd)"

# WSL in NAT mode cannot route to VirtualBox host-only networks when Windows
# forwarding is disabled.  Run the Windows OpenSSH client from WSL instead;
# it can reach Vagrant's localhost port forwards without elevation.
windows_project="$(wslpath -w "$project" | tr '\\' '/')"
windows_ssh='/mnt/c/Windows/System32/OpenSSH/ssh.exe'

key_for() {
  local vm="$1"
  printf '%s/.vagrant/machines/%s/virtualbox/private_key' "$windows_project" "$vm"
}

mkdir -p inventory
cat > inventory/hosts.ini <<EOF
[frontend]
web ansible_host=127.0.0.1 ansible_port=50001 ansible_ssh_private_key_file=$(key_for web)

[app]
app1 ansible_host=127.0.0.1 ansible_port=50100 ansible_ssh_private_key_file=$(key_for app1)
app2 ansible_host=127.0.0.1 ansible_port=50400 ansible_ssh_private_key_file=$(key_for app2)

[db_primary]
app1

[db_replica]
app2

[observability]
elk ansible_host=127.0.0.1 ansible_port=50500 ansible_ssh_private_key_file=$(key_for elk)

[all:vars]
ansible_user=vagrant
ansible_become=true
ansible_timeout=60
ansible_ssh_executable=$windows_ssh
; Windows OpenSSH cannot use Ansible's Linux ControlPath, therefore SSH
; multiplexing is intentionally disabled.
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ServerAliveInterval=15 -o ServerAliveCountMax=6'
EOF
echo "wrote inventory/hosts.ini"
