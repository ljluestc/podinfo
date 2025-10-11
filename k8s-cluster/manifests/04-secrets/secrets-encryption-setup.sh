#!/bin/bash
# Script to configure secrets encryption at rest

echo "Setting up secrets encryption at rest..."

# Generate encryption keys
KEY1=$(head -c 32 /dev/urandom | base64)
KEY2=$(head -c 32 /dev/urandom | base64)

# Create encryption configuration
cat <<EOF > /etc/kubernetes/encryption-config-generated.yaml
---
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $KEY1
            - name: key2
              secret: $KEY2
      - identity: {}
EOF

echo "Encryption configuration created at /etc/kubernetes/encryption-config-generated.yaml"
echo "Update kube-apiserver manifest to use this configuration"
echo "Add: --encryption-provider-config=/etc/kubernetes/encryption-config-generated.yaml"

# Restart API server (if using static pods)
# kubectl -n kube-system delete pod -l component=kube-apiserver

# Encrypt existing secrets
echo "To encrypt existing secrets, run:"
echo "kubectl get secrets --all-namespaces -o json | kubectl replace -f -"
