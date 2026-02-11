#!/bin/bash
# K8s Extra Backup - Fast Version
# Skips kubelet (AI models already in /data/K8s)

EXTERNAL="/mnt/passport"
BACKUP_EXTRA="$EXTERNAL/backup_extra_$(date +%Y%m%d_%H%M%S)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}===================================================================${NC}"
echo -e "${GREEN}   K8s Extra Backup - Fast Version${NC}"
echo -e "${GREEN}===================================================================${NC}"
echo ""
echo "Will backup:"
echo "  ✓ etcd (K8s cluster database) - CRITICAL"
echo "  ✓ Helm chart values"
echo "  ✓ K8s resource manifests"
echo ""
echo "Skipped:"
echo "  ⊘ kubelet (contains 266GB AI models already in /data/K8s)"
echo ""
echo "AI models are already backed up via:"
echo "  - /data/K8s/ (NFS PVs)"
echo "  - Main backup will cover this"
echo ""

if [ ! -d "$EXTERNAL" ]; then
    echo "ERROR: External drive not mounted"
    exit 1
fi

read -p "Proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

mkdir -p "$BACKUP_EXTRA"/{etcd,helm-values,k8s-resources}
echo -e "${GREEN}✓ Created: $BACKUP_EXTRA${NC}"
echo ""

START=$(date +%s)

#================================================================
# 1. etcd
#================================================================
echo -e "${YELLOW}[1/3] Backing up etcd...${NC}"
rsync -avX rsu-login:/var/lib/etcd/ "$BACKUP_EXTRA/etcd/" 2>&1 | tail -5
SIZE=$(du -sh "$BACKUP_EXTRA/etcd" | awk '{print $1}')
echo -e "${GREEN}✓ etcd: $SIZE${NC}"
echo ""

#================================================================
# 2. Helm values
#================================================================
echo -e "${YELLOW}[2/3] Exporting Helm values...${NC}"

declare -A CHARTS=(
    ["kube-prometheus-stack"]="prometheus"
    ["open-webui-uat01"]="uat01-restricted"
    ["open-webui-uat03"]="uat03-restricted"
    ["network-operator"]="network-operator"
    ["gpu-operator"]="gpu-operator"
    ["nfs-provisioner"]="default"
)

COUNT=0
for name in "${!CHARTS[@]}"; do
    ns="${CHARTS[$name]}"
    if helm get values "$name" -n "$ns" > "$BACKUP_EXTRA/helm-values/${name}.yaml" 2>/dev/null; then
        echo "  ✓ $name"
        ((COUNT++))
    fi
done

echo -e "${GREEN}✓ Helm: $COUNT charts${NC}"
echo ""

#================================================================
# 3. K8s resources
#================================================================
echo -e "${YELLOW}[3/3] Exporting K8s resources...${NC}"

kubectl get all --all-namespaces -o yaml > "$BACKUP_EXTRA/k8s-resources/all-resources.yaml" 2>/dev/null && echo "  ✓ all-resources.yaml"
kubectl get cm,secrets --all-namespaces -o yaml > "$BACKUP_EXTRA/k8s-resources/configs-secrets.yaml" 2>/dev/null && echo "  ✓ configs-secrets.yaml"
kubectl get sc,pv,pvc --all-namespaces -o yaml > "$BACKUP_EXTRA/k8s-resources/storage.yaml" 2>/dev/null && echo "  ✓ storage.yaml"
kubectl get crd -o yaml > "$BACKUP_EXTRA/k8s-resources/crds.yaml" 2>/dev/null && echo "  ✓ crds.yaml"
kubectl get ns -o yaml > "$BACKUP_EXTRA/k8s-resources/namespaces.yaml" 2>/dev/null && echo "  ✓ namespaces.yaml"

YAML_COUNT=$(ls "$BACKUP_EXTRA/k8s-resources/"*.yaml 2>/dev/null | wc -l)
echo -e "${GREEN}✓ K8s: $YAML_COUNT files${NC}"
echo ""

#================================================================
# Summary
#================================================================
END=$(date +%s)
DURATION=$((END - START))

cat > "$BACKUP_EXTRA/MANIFEST.txt" << EOF
K8s Extra Backup - Fast Version
================================
Date: $(date)
Duration: ${DURATION} seconds

Contents:
---------
etcd: $(du -sh "$BACKUP_EXTRA/etcd" 2>/dev/null | awk '{print $1}')
Helm: $COUNT charts
K8s: $YAML_COUNT manifests

Total: $(du -sh "$BACKUP_EXTRA" 2>/dev/null | awk '{print $1}')

Note:
-----
kubelet backup skipped because:
- Contains 266GB AI models (Ollama/Open WebUI)
- Models already backed up in /data/K8s/ (NFS PVs)
- Main backup covers this data
- kubelet will regenerate cache on pod restart

Pod with large data:
  3e4b4308-f4e0-49be-9456-dc580fa05d3b: 266GB (AI models)

This is expected and correct.
EOF

echo -e "${GREEN}===================================================================${NC}"
echo -e "${GREEN}   ✓ Backup Completed!${NC}"
echo -e "${GREEN}===================================================================${NC}"
echo ""
echo -e "${BLUE}Location:${NC} $BACKUP_EXTRA"
echo ""
echo -e "${BLUE}Backed up:${NC}"
echo "  ✓ etcd: $(du -sh $BACKUP_EXTRA/etcd | awk '{print $1}')"
echo "  ✓ Helm: $COUNT charts"
echo "  ✓ K8s: $YAML_COUNT manifests"
echo ""
echo -e "${BLUE}Total:${NC} $(du -sh $BACKUP_EXTRA | awk '{print $1}')"
echo -e "${BLUE}Time:${NC} ${DURATION}s"
echo ""
echo -e "${YELLOW}Note: AI models (266GB) already in main backup (/data/K8s)${NC}"
echo ""
echo -e "${GREEN}Next: /root/backup_bcm.sh${NC}"
echo ""
