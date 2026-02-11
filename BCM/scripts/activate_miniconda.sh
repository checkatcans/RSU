#!/bin/bash

# อ่านจาก CSV
CSV_FILE="Format_import_RSU_3.csv"

tail -n +2 "$CSV_FILE" | tr -d '\r' | while IFS=, read -r USERNAME PASSWORD GROUP EMAIL PACKAGE; do
    USERNAME=$(echo "$USERNAME" | xargs | tr -d '\r\n')
    
    if [ -z "$USERNAME" ]; then
        continue
    fi
    
    echo "Initializing conda for user: $USERNAME"
    
    # รันคำสั่ง conda init ในฐานะ user นั้นๆ
    su - $USERNAME -c '/cm/shared/apps/miniconda3/bin/conda init'
    
    echo "  ✓ Conda initialized for $USERNAME"
done

echo "All users conda initialized!"
