#!/usr/bin/bash
# Removes package manager state that does not belong in the image; bootc lint
# rejects content in /run and untracked files in /var.
set -euo pipefail

rm -rf /run/dnf /run/selinux-policy /var/lib/dnf
