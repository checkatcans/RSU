#!/bin/bash

CSV_FILE="Format_import_RSU.csv"
CLUSTER_NAME="rsu-slurm"

# Define resource packages
declare -A PKG_GPU_TYPE=(
    ["S"]="1g.18gb"
    ["M"]="1g.35gb"
    ["L"]="3g.71gb"
    ["XL"]="7g.141gb"
)

declare -A PKG_GPU_COUNT=(
    ["S"]=1
    ["M"]=1
    ["L"]=1
    ["XL"]=1
)

declare -A PKG_CPU=(
    ["S"]=2
    ["M"]=4
    ["L"]=8
    ["XL"]=16
)

declare -A PKG_MEM=(
    ["S"]="32G"
    ["M"]="64G"
    ["L"]="128G"
    ["XL"]="256G"
)

declare -A PKG_MAX_JOBS=(
    ["S"]=3
    ["M"]=5
    ["L"]=8
    ["XL"]=10
)

# Function to build GRES string based on package
build_gres_string() {
    local package=$1
    local gpu_type=${PKG_GPU_TYPE[$package]}
    local gpu_count=${PKG_GPU_COUNT[$package]}
    
    echo "gres/gpu=${gpu_count},gres/gpu:${gpu_type}=${gpu_count}"
}

echo "Starting user creation process..."
echo "=================================="

# Read CSV (skip header)
tail -n +2 "$CSV_FILE" | while IFS=, read -r USERNAME PASSWORD GROUP EMAIL PACKAGE; do
    
    # Trim whitespace
    USERNAME=$(echo "$USERNAME" | xargs)
    PASSWORD=$(echo "$PASSWORD" | xargs)
    GROUP=$(echo "$GROUP" | xargs)
    EMAIL=$(echo "$EMAIL" | xargs)
    PACKAGE=$(echo "$PACKAGE" | xargs)
    
    # Validate package
    if [[ ! "$PACKAGE" =~ ^(S|M|L|XL)$ ]]; then
        echo "ERROR: Invalid package '$PACKAGE' for user $USERNAME. Skipping..."
        continue
    fi
    
    echo ""
    echo "Processing: $USERNAME (Package: $PACKAGE)"
    echo "-------------------------------------------"
    
    # Get package resources
    CPU=${PKG_CPU[$PACKAGE]}
    MEM=${PKG_MEM[$PACKAGE]}
    GPU_COUNT=${PKG_GPU_COUNT[$PACKAGE]}
    GPU_TYPE=${PKG_GPU_TYPE[$PACKAGE]}
    MAX_JOBS=${PKG_MAX_JOBS[$PACKAGE]}
    GRES=$(build_gres_string "$PACKAGE")
    
    echo "  Resources: CPU=${CPU}, RAM=${MEM}, GPU=${GPU_COUNT}x${GPU_TYPE}, MaxJobs=${MAX_JOBS}"
    
    # 1. Create user in Bright CM
    echo "  [1/5] Creating CM user..."
    if cmsh -c "user; add $USERNAME; set password $PASSWORD; set email $EMAIL; commit;" 2>/dev/null; then
        echo "    ✓ CM user created"
    else
        echo "    ! CM user already exists or error occurred"
    fi
    
    # 2. Add to group
    echo "  [2/5] Adding to group $GROUP..."
    if cmsh -c "group; use $GROUP; append members $USERNAME; commit" 2>/dev/null; then
        echo "    ✓ Added to group"
    else
        echo "    ! Already in group or error occurred"
    fi
    
    # 3. Setup SLURM account
    SLURM_ACCOUNT="g_${GROUP}"
    echo "  [3/5] Setting up SLURM account $SLURM_ACCOUNT..."
    
    if ! sacctmgr -n show account $SLURM_ACCOUNT cluster=$CLUSTER_NAME 2>/dev/null | grep -q "$SLURM_ACCOUNT"; then
        echo "    Creating SLURM account..."
        sacctmgr -i add account $SLURM_ACCOUNT \
            cluster=$CLUSTER_NAME \
            Organization=$SLURM_ACCOUNT \
            Description="Auto-created for group $GROUP"
        echo "    ✓ SLURM account created"
    else
        echo "    ✓ SLURM account exists"
    fi
    
    # 4. Add user to SLURM with package-based limits (NO MaxSubmitJobs)
    echo "  [4/5] Adding user to SLURM..."
    if sacctmgr -i add user $USERNAME \
        cluster=$CLUSTER_NAME \
        account=$SLURM_ACCOUNT \
        DefaultAccount=$SLURM_ACCOUNT \
        GrpTRES=cpu=${CPU},${GRES},mem=${MEM} \
        MaxJobs=${MAX_JOBS} 2>/dev/null; then
        echo "    ✓ SLURM user added with package $PACKAGE limits"
    else
        echo "    ! SLURM user already exists, updating limits..."
        sacctmgr -i modify user $USERNAME \
            cluster=$CLUSTER_NAME \
            account=$SLURM_ACCOUNT \
            set GrpTRES=cpu=${CPU},${GRES},mem=${MEM} \
            MaxJobs=${MAX_JOBS}
        echo "    ✓ SLURM limits updated"
    fi
    
    # 5. Setup Kubernetes namespace
    echo "  [5/5] Setting up Kubernetes..."
    if cm-kubernetes-setup --add-user "$USERNAME" --operators cm-jupyter-kernel-operator 2>/dev/null; then
        echo "    ✓ Kubernetes namespace created"
    else
        echo "    ! Kubernetes setup failed or already exists"
    fi
    
    echo "  ✓ User $USERNAME completed successfully!"
    
done

echo ""
echo "=================================="
echo "All users processed!"
echo ""
echo "Verify SLURM configuration:"
echo "  sacctmgr show assoc format=cluster,account,user%15,GrpTRES%85,MaxJobs where account=g_$GROUP"
