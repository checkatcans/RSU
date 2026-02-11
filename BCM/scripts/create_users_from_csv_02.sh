#!/bin/bash

CSV_FILE="Format_import_RSU_02.csv"
CLUSTER_NAME="rsu-slurm"

# Define all GPU profiles in your system
ALL_GPU_PROFILES=("1g.18gb" "1g.35gb" "3g.71gb" "7g.141gb")

# Define resource packages
declare -A PKG_ALLOWED_GPU=(
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

# All packages have MaxJobs=5
MAX_JOBS=5

# Function to build GRES string with all profiles
build_gres_string() {
    local package=$1
    local allowed_gpu=${PKG_ALLOWED_GPU[$package]}
    local gpu_count=${PKG_GPU_COUNT[$package]}
    
    # Start with total GPU count
    local gres_string="gres/gpu=${gpu_count}"
    
    # Add all GPU profiles (allowed=count, others=0)
    for profile in "${ALL_GPU_PROFILES[@]}"; do
        if [ "$profile" = "$allowed_gpu" ]; then
            gres_string="${gres_string},gres/gpu:${profile}=${gpu_count}"
        else
            gres_string="${gres_string},gres/gpu:${profile}=0"
        fi
    done
    
    echo "$gres_string"
}

echo "Starting user creation process..."
echo "=================================="

# Read CSV (skip header) and handle both Unix and DOS line endings
tail -n +2 "$CSV_FILE" | tr -d '\r' | while IFS=, read -r USERNAME PASSWORD GROUP EMAIL PACKAGE; do
    
    # Trim whitespace and remove any remaining control characters
    USERNAME=$(echo "$USERNAME" | xargs | tr -d '\r\n')
    PASSWORD=$(echo "$PASSWORD" | xargs | tr -d '\r\n')
    GROUP=$(echo "$GROUP" | xargs | tr -d '\r\n')
    EMAIL=$(echo "$EMAIL" | xargs | tr -d '\r\n')
    PACKAGE=$(echo "$PACKAGE" | xargs | tr -d '\r\n')
    
    # Skip empty lines
    if [ -z "$USERNAME" ]; then
        continue
    fi
    
    # Debug: Show what we read
    echo ""
    echo "DEBUG: Read from CSV:"
    echo "  Username: '$USERNAME'"
    echo "  Password: '$PASSWORD'"
    echo "  Group: '$GROUP'"
    echo "  Email: '$EMAIL'"
    echo "  Package: '$PACKAGE'"
    
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
    ALLOWED_GPU=${PKG_ALLOWED_GPU[$PACKAGE]}
    GRES=$(build_gres_string "$PACKAGE")
    
    echo "  Resources: CPU=${CPU}, RAM=${MEM}, GPU=${GPU_COUNT}x${ALLOWED_GPU}, MaxJobs=${MAX_JOBS}"
    echo "  GRES: ${GRES}"
    
    # 1. Create user in Bright CM
    echo "  [1/5] Creating CM user..."
    cmsh -c "user; add $USERNAME; set password $PASSWORD; set email $EMAIL; commit;" 2>&1
    echo "    ✓ CM user step completed"
    
    # 2. Add to group
    echo "  [2/5] Adding to group $GROUP..."
    cmsh -c "group; use $GROUP; append members $USERNAME; commit" 2>&1
    echo "    ✓ Group assignment step completed"
    
    # 3. Setup SLURM account
    SLURM_ACCOUNT="g_${GROUP}"
    echo "  [3/5] Setting up SLURM account $SLURM_ACCOUNT..."
    
    # Check if account exists using grep
    if ! sacctmgr show account | grep -q "$SLURM_ACCOUNT"; then
        echo "    Creating SLURM account..."
        sacctmgr -i add account $SLURM_ACCOUNT \
            cluster=$CLUSTER_NAME \
            Organization=$SLURM_ACCOUNT \
            Description="Auto-created for group $GROUP"
        echo "    ✓ SLURM account created"
    else
        echo "    ✓ SLURM account already exists"
    fi
    
    # 4. Add user to SLURM with package-based limits
    echo "  [4/5] Adding user to SLURM..."
    
    # Check if user already exists using grep
    if sacctmgr show user | grep -q "^[[:space:]]*$USERNAME[[:space:]]"; then
        echo "    User exists, updating limits..."
        sacctmgr -i modify user $USERNAME \
            where cluster=$CLUSTER_NAME account=$SLURM_ACCOUNT \
            set GrpTRES=cpu=${CPU},${GRES},mem=${MEM} \
            MaxJobs=${MAX_JOBS}
        echo "    ✓ SLURM limits updated"
    else
        echo "    Adding new user..."
        sacctmgr -i add user $USERNAME \
            cluster=$CLUSTER_NAME \
            account=$SLURM_ACCOUNT \
            DefaultAccount=$SLURM_ACCOUNT \
            GrpTRES=cpu=${CPU},${GRES},mem=${MEM} \
            MaxJobs=${MAX_JOBS}
        echo "    ✓ SLURM user added with package $PACKAGE limits"
    fi
    
    # 5. Setup Kubernetes namespace
    echo "  [5/5] Setting up Kubernetes..."
    cm-kubernetes-setup --add-user "$USERNAME" --operators cm-jupyter-kernel-operator 2>&1
    echo "    ✓ Kubernetes setup step completed"
    
    echo "  ✓ User $USERNAME processing completed!"
    
done

echo ""
echo "=================================="
echo "All users processed!"
echo ""
echo "Verify SLURM configuration:"
echo "  sacctmgr show assoc format=cluster,account,user%15,GrpTRES%120,MaxJobs where account=g_csc490"
echo ""
echo "Test with user:"
echo "  su - csc490-01"
echo "  kubectl get pods"
