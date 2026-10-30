#!/usr/bin/bash
# Copies ArkadeOS files over the base image. Runs after 40-remove.sh: a removed
# package takes its files with it, and some of ours (/etc/xdg/kdeglobals)
# replace files that such a package owned.
set -euo pipefail

cp -a "${CTX}/system_files/." /
