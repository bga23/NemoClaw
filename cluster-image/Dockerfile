# SPDX-License-Identifier: Apache-2.0
#
# Fixed OpenShell cluster image with self-contained TLS bootstrap.
#
# The upstream ghcr.io/nvidia/openshell/cluster image requires an external
# CLI (openshell gateway start) to create the mTLS secrets that the internal
# Helm-deployed StatefulSet needs. When that CLI step hangs or fails, the
# container never becomes healthy.
#
# This image adds a lightweight bootstrap script that runs in the background
# alongside k3s and creates the required secrets automatically, making the
# container fully self-contained.
#
# Build:
#   docker build --build-arg BASE_TAG=0.0.26 -t ghcr.io/bga23/nemoclaw/cluster:0.0.26 .
#
ARG BASE_TAG=0.0.26
FROM ghcr.io/nvidia/openshell/cluster:${BASE_TAG}

# Preserve the original entrypoint
RUN mv /usr/local/bin/cluster-entrypoint.sh /usr/local/bin/cluster-entrypoint-original.sh

# Add bootstrap script (generates CA + server/client TLS certs + SSH HMAC key)
COPY cluster-bootstrap.sh /usr/local/bin/cluster-bootstrap.sh
RUN chmod +x /usr/local/bin/cluster-bootstrap.sh

# Replace entrypoint with wrapper that forks bootstrap before exec'ing k3s
COPY cluster-entrypoint-wrapper.sh /usr/local/bin/cluster-entrypoint.sh
RUN chmod +x /usr/local/bin/cluster-entrypoint.sh
