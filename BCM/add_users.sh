#!/bin/bash

# ตรวจสอบว่ามีการระบุไฟล์ CSV หรือไม่
if [ $# -eq 0 ]; then
    echo "Usage: $0 <csv_file>"
    echo "Example: $0 users.csv"
    exit 1
fi

CSV_FILE=$1

# ตรวจสอบว่าไฟล์มีอยู่จริง
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File '$CSV_FILE' not found!"
    exit 1
fi

# อ่านไฟล์ CSV (ข้ามบรรทัดแรกที่เป็น header)
tail -n +2 "$CSV_FILE" | while IFS=',' read -r USERNAME PASSWORD NAME SURNAME EMAIL; do
    # ตัดช่องว่างออก (ถ้ามี)
    USERNAME=$(echo "$USERNAME" | xargs)
    PASSWORD=$(echo "$PASSWORD" | xargs)
    EMAIL=$(echo "$EMAIL" | xargs)
    
    echo "Adding user: $USERNAME ($EMAIL)"
    
    # รันคำสั่งเพิ่ม user
    cmsh -c "
    user;
    add ${USERNAME};
    set password ${PASSWORD};
    set email ${EMAIL};
    commit;"
    
    # ตรวจสอบผลลัพธ์
    if [ $? -eq 0 ]; then
        echo "✓ Successfully added user: $USERNAME"
    else
        echo "✗ Failed to add user: $USERNAME"
    fi
    
    echo "---"
done

echo "User creation process completed!"
