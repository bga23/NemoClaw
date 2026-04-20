#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# cluster-bootstrap.sh — Self-contained TLS bootstrap for the OpenShell cluster.
#
# Runs as a background process alongside k3s. Waits for the k3s API, then
# creates the four TLS/HMAC secrets that the openshell StatefulSet requires.
# Without these secrets the pod volumes cannot mount and the container never
# becomes healthy.
#
# Secrets created:
#   openshell-server-tls         — server TLS cert + key  (kubernetes.io/tls)
#   openshell-server-client-ca   — CA cert for client verification (Opaque, key: ca.crt)
#   openshell-client-tls         — client cert + key for mTLS (kubernetes.io/tls)
#   openshell-ssh-handshake      — HMAC key for SSH handshake (Opaque, key: secret)
#
# Idempotent — skips if all four secrets already exist.

set -eu

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

NAMESPACE="openshell"
CA_DAYS=3650
CERT_DAYS=3650

log() { echo "[bootstrap] $*"; }

# ---------------------------------------------------------------------------
# Wait for k3s API server
# ---------------------------------------------------------------------------
log "Waiting for k3s API server..."
attempts=0
while ! kubectl get --raw='/readyz' >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 120 ]; then
        log "ERROR: k3s API not ready after 120 attempts, giving up"
        exit 1
    fi
    sleep 2
done
log "k3s API ready"

# ---------------------------------------------------------------------------
# Ensure namespace exists
# ---------------------------------------------------------------------------
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Idempotent: skip if bootstrap already completed
# ---------------------------------------------------------------------------
if kubectl -n "$NAMESPACE" get secret openshell-server-tls >/dev/null 2>&1 \
   && kubectl -n "$NAMESPACE" get secret openshell-server-client-ca >/dev/null 2>&1 \
   && kubectl -n "$NAMESPACE" get secret openshell-client-tls >/dev/null 2>&1 \
   && kubectl -n "$NAMESPACE" get secret openshell-ssh-handshake >/dev/null 2>&1; then
    log "All secrets already exist — bootstrap skipped"
    exit 0
fi

log "Creating TLS certificates and secrets..."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# 1. Generate CA (4096-bit RSA)
# ---------------------------------------------------------------------------
openssl genrsa -out "$WORK/ca.key" 4096 2>/dev/null
openssl req -new -x509 -days "$CA_DAYS" -key "$WORK/ca.key" \
    -out "$WORK/ca.crt" -subj "/CN=openshell-ca" 2>/dev/null
log "CA generated"

# ---------------------------------------------------------------------------
# 2. Server certificate with SANs
# ---------------------------------------------------------------------------
cat > "$WORK/server.cnf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = openshell

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = openshell
DNS.2 = openshell.openshell
DNS.3 = openshell.openshell.svc
DNS.4 = openshell.openshell.svc.cluster.local
DNS.5 = localhost
IP.1 = 127.0.0.1
EOF

openssl genrsa -out "$WORK/server.key" 4096 2>/dev/null
openssl req -new -key "$WORK/server.key" \
    -out "$WORK/server.csr" -config "$WORK/server.cnf" 2>/dev/null
openssl x509 -req -days "$CERT_DAYS" \
    -in "$WORK/server.csr" -CA "$WORK/ca.crt" -CAkey "$WORK/ca.key" \
    -CAcreateserial -out "$WORK/server.crt" \
    -extensions v3_req -extfile "$WORK/server.cnf" 2>/dev/null
log "Server cert generated"

# ---------------------------------------------------------------------------
# 3. Client certificate for mTLS
# ---------------------------------------------------------------------------
cat > "$WORK/client.cnf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = openshell-client

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

openssl genrsa -out "$WORK/client.key" 4096 2>/dev/null
openssl req -new -key "$WORK/client.key" \
    -out "$WORK/client.csr" -config "$WORK/client.cnf" 2>/dev/null
openssl x509 -req -days "$CERT_DAYS" \
    -in "$WORK/client.csr" -CA "$WORK/ca.crt" -CAkey "$WORK/ca.key" \
    -CAcreateserial -out "$WORK/client.crt" \
    -extensions v3_req -extfile "$WORK/client.cnf" 2>/dev/null
log "Client cert generated"

# ---------------------------------------------------------------------------
# 4. SSH handshake HMAC secret (32 bytes hex-encoded)
# ---------------------------------------------------------------------------
SSH_SECRET=$(openssl rand -hex 32)

# ---------------------------------------------------------------------------
# 5. Create Kubernetes secrets
# ---------------------------------------------------------------------------

# Server TLS (type: kubernetes.io/tls → keys: tls.crt, tls.key)
kubectl -n "$NAMESPACE" create secret tls openshell-server-tls \
    --cert="$WORK/server.crt" --key="$WORK/server.key" \
    2>/dev/null || log "openshell-server-tls already exists"

# Client CA — must use key "ca.crt" because the Helm chart mounts this at
# /etc/openshell-tls/client-ca/ and the server reads ca.crt from that path
kubectl -n "$NAMESPACE" create secret generic openshell-server-client-ca \
    --from-file=ca.crt="$WORK/ca.crt" \
    2>/dev/null || log "openshell-server-client-ca already exists"

# Client TLS (type: kubernetes.io/tls → keys: tls.crt, tls.key)
kubectl -n "$NAMESPACE" create secret tls openshell-client-tls \
    --cert="$WORK/client.crt" --key="$WORK/client.key" \
    2>/dev/null || log "openshell-client-tls already exists"

# SSH handshake (type: Opaque → key: secret)
kubectl -n "$NAMESPACE" create secret generic openshell-ssh-handshake \
    --from-literal=secret="$SSH_SECRET" \
    2>/dev/null || log "openshell-ssh-handshake already exists"

log "All secrets created successfully"

# ---------------------------------------------------------------------------
# 6. Wait for StatefulSet to become ready
# ---------------------------------------------------------------------------
log "Waiting for openshell StatefulSet to become ready..."
attempts=0
while ! kubectl -n "$NAMESPACE" wait --for=jsonpath='{.status.readyReplicas}'=1 \
    statefulset/openshell --timeout=5s >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 60 ]; then
        log "WARNING: StatefulSet not ready after 5 minutes"
        exit 0
    fi
    sleep 5
done

log "Bootstrap complete — openshell is ready"
