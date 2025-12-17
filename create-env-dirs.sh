#!/bin/bash

set -euo pipefail

# Configuration
CLUSTER_LIST_URL="https://raw.githubusercontent.com/worlds-io/control-plane/refs/heads/main/cluster.list?token=GHSAT0AAAAAADRLFX6LEFXZDBPH6JKBIASO2KCYYBQ"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${BASE_DIR}/env"
TEMPLATE_DIR="${ENV_DIR}/dev-eus-core"

# Validate template directory exists
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: Template directory not found: $TEMPLATE_DIR"
  exit 1
fi

echo "Fetching cluster list from: $CLUSTER_LIST_URL"
CLUSTERS=$(curl -s "$CLUSTER_LIST_URL" | grep -v '^#' | grep -v '^$' | sort -u)

if [[ -z "$CLUSTERS" ]]; then
  echo "Error: No clusters found in cluster.list"
  exit 1
fi

echo "Found clusters:"
echo "$CLUSTERS"
echo ""

# Process each cluster
while IFS= read -r cluster_name; do
  # Skip empty lines and comments
  [[ -z "$cluster_name" ]] && continue
  [[ "$cluster_name" =~ ^# ]] && continue
  
  cluster_name=$(echo "$cluster_name" | xargs)  # trim whitespace
  
  TARGET_DIR="${ENV_DIR}/${cluster_name}"
  
  # Create directory structure
  if [[ -d "$TARGET_DIR" ]]; then
    echo "⚠️  Directory already exists: $TARGET_DIR (skipping)"
    continue
  fi
  
  echo "📁 Creating: $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  
  # Copy template files
  echo "   Copying files from template..."
  cp -r "${TEMPLATE_DIR}"/* "$TARGET_DIR/" 2>/dev/null || true
  
  # Update namespace in kustomization.yaml
  if [[ -f "$TARGET_DIR/kustomization.yaml" ]]; then
    # Replace the namespace value with the cluster name
    # Convert cluster name to valid k8s namespace format (lowercase, hyphens)
    namespace="guestbook-simple-${cluster_name}"
    
    sed -i.bak "s/namespace: .*/namespace: $namespace/" "$TARGET_DIR/kustomization.yaml"
    rm -f "$TARGET_DIR/kustomization.yaml.bak"
    
    echo "   ✓ Updated namespace to: $namespace"
  fi
done <<< "$CLUSTERS"

echo ""
echo "✅ Complete! Created env directories:"
find "$ENV_DIR" -maxdepth 1 -type d ! -name env | sort
