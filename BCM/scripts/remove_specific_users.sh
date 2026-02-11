#!/bin/bash
# remove_specific_users.sh

CLUSTER_NAME="rsu-slurm"

# ตรวจสอบว่ามี arguments หรือไม่
if [ $# -eq 0 ]; then
    echo "Usage: $0 <username1> [username2] [username3] ..."
    echo "Example: $0 test01 test02 csc490-01"
    exit 1
fi

# เก็บ username ทั้งหมดจาก arguments
USERS_TO_REMOVE=("$@")

echo "========================================="
echo "   User Removal Script"
echo "========================================="
echo ""
echo "Users to be removed:"
for user in "${USERS_TO_REMOVE[@]}"; do
    echo "  - $user"
done
echo ""
echo "Total: ${#USERS_TO_REMOVE[@]} user(s)"
echo ""
echo "WARNING: This will permanently delete these users!"
echo "Press Ctrl+C within 10 seconds to cancel..."
sleep 10

# ลบแต่ละ user
for USERNAME in "${USERS_TO_REMOVE[@]}"; do
    
    echo ""
    echo "Removing user: $USERNAME"
    echo "-------------------------------------------"
    
    # 1. Remove from Kubernetes
    echo "  [1/3] Removing from Kubernetes..."
    if cm-kubernetes-setup --remove-user "$USERNAME" --operators cm-jupyter-kernel-operator 2>&1 | tail -5; then
        echo "    ✓ K8s removal completed"
    else
        echo "    ! K8s removal attempted (may not exist)"
    fi
    
    # 2. Remove from SLURM
    echo "  [2/3] Removing from SLURM..."
    if sacctmgr show user | grep -q "^[[:space:]]*$USERNAME[[:space:]]"; then
        sacctmgr -i remove user $USERNAME 2>&1
        echo "    ✓ Removed from SLURM"
    else
        echo "    ! User not found in SLURM"
    fi
    
    # 3. Remove from Bright Cluster Manager
    echo "  [3/3] Removing from Bright CM..."
    if cmsh -c "user; remove $USERNAME -d; commit;" 2>&1 | grep -q -i "success"; then
        echo "    ✓ Removed from BCM"
    else
        echo "    ! BCM removal attempted"
    fi
    
    echo "  ✓ User $USERNAME processing completed!"
    
done

echo ""
echo "========================================="
echo "All specified users processed!"
echo "========================================="
