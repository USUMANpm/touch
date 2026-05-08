#!/bin/bash

apt-get update

sudo useradd -u 2026 sshuser
echo "sshuser:P@ssw0rd" | sudo chpasswd
sudo usermod -aG wheel sshuser || true
grep -q "^sshuser ALL=(ALL:ALL) NOPASSWD: ALL$" /etc/sudoers || echo "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
sed -i "s/^#\?Port .*/Port 2026/" /etc/openssh/sshd_config
sed -i "s/^#\?MaxAuthTries .*/MaxAuthTries 5/" /etc/openssh/sshd_config
sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin yes/" /etc/openssh/sshd_config

grep -q "^AllowUsers sshuser$" /etc/openssh/sshd_config || echo "AllowUsers sshuser root" >> /etc/openssh/sshd_config

systemctl enable --now  sshd
systemctl restart sshd


