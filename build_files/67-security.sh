#!/usr/bin/bash
# Security and privacy (T024): firewall on with the ArkadeOS zone, no
# telemetry (Fedora's countme off; Firefox and Plasma settings in system_files).
set -euo pipefail

systemctl enable firewalld.service
sed -i 's/^DefaultZone=.*/DefaultZone=ArkadeOS/' /etc/firewalld/firewalld.conf
grep -qx DefaultZone=ArkadeOS /etc/firewalld/firewalld.conf
firewall-offline-cmd --check-config

sed -i 's/^countme=1/countme=0/' /etc/yum.repos.d/*.repo
if grep -l '^countme=1' /etc/yum.repos.d/*.repo; then exit 1; fi
