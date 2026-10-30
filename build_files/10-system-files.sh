#!/usr/bin/bash
# Copies ArkadeOS files over the base image.
set -euo pipefail

cp -a "${CTX}/system_files/." /
