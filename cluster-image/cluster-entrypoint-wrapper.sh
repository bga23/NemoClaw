#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# cluster-entrypoint-wrapper.sh — Wraps the original k3s entrypoint.
#
# Forks the TLS bootstrap script in the background, then exec's the original
# entrypoint (which ultimately exec's k3s server). The bootstrap waits for
# the k3s API to become ready before creating secrets.

# Fork bootstrap into background
/usr/local/bin/cluster-bootstrap.sh > /var/log/openshell-bootstrap.log 2>&1 &
echo "Started TLS bootstrap (PID=$!)"

# Hand off to the original entrypoint
exec /usr/local/bin/cluster-entrypoint-original.sh "$@"
