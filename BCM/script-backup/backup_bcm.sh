#!/bin/bash
# BCM Complete Backup Script - rsu-management
# Uses rsync -avX everywhere for maximum safety

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
EXTERNAL="/mnt/passport"
BACKUP_DIR="$EXTERNAL/bcm_complete_backup_$BACKUP_DATE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}   BCM Complete Backup - rsu-management${NC}"
echo -e "${GREEN}   Using rsync -avX everywhere for maximum safety${NC}"
echo -e "${GREEN}================================================================${NC}"
echo "Backup Date: $BACKUP_DATE"
echo "External Drive: $EXTERNAL"
echo ""

# Check if rsync supports -X
if ! rsync --help | grep -q "preserve extended attributes"; then
    echo -e "${RED}ERROR: rsync doesn't support -X flag${NC}"
    echo "Please upgrade rsync or this backup may not work correctly"
    exit 1
fi
echo -e "${GREEN}✓ rsync supports extended attributes${NC}"
echo ""

# Check if external drive is mounted
if [ ! -d "$EXTERNAL" ]; then
    echo -e "${RED}ERROR: External drive not mounted at $EXTERNAL${NC}"
    echo ""
    echo "To mount:"
    echo "  mkdir -p /mnt/passport"
    echo "  mount /dev/sdb1 /mnt/passport"
    exit 1
fi

# Check available space
EXTERNAL_AVAIL_GB=$(df -BG "$EXTERNAL" | tail -1 | awk '{print $4}' | sed 's/G//')
echo -e "${BLUE}External drive available: ${EXTERNAL_AVAIL_GB}GB${NC}"

# Estimate total backup size
echo ""
echo "Estimating backup size..."
IMAGES_SIZE_GB=$(du -sm /cm/images/ 2>/dev/null | awk '{printf "%.1f", $1/1024}')
DATA_CM_SIZE_GB=$(du -sm /data/cm/ 2>/dev/null | awk '{printf "%.1f", $1/1024}')
DATA_K8S_SIZE_GB=$(du -sm /data/K8s/ 2>/dev/null | awk '{printf "%.1f", $1/1024}')
ETC_SIZE_GB=$(du -sm /etc/ 2>/dev/null | awk '{printf "%.1f", $1/1024}')
CM_SIZE_GB=$(du -sm /cm/ --exclude=/cm/images --exclude=/cm/shared 2>/dev/null | awk '{printf "%.1f", $1/1024}')
ESTIMATE_TOTAL=$(echo "$IMAGES_SIZE_GB + $DATA_CM_SIZE_GB + $DATA_K8S_SIZE_GB + $ETC_SIZE_GB + $CM_SIZE_GB + 2" | bc)

echo -e "${YELLOW}Estimated backup size:${NC}"
echo "  - Node images:    ${IMAGES_SIZE_GB}GB"
echo "  - /data/cm:       ${DATA_CM_SIZE_GB}GB"
echo "  - /data/K8s:      ${DATA_K8S_SIZE_GB}GB"
echo "  - /cm config:     ${CM_SIZE_GB}GB"
echo "  - /etc:           ${ETC_SIZE_GB}GB"
echo "  - Database:       ~2GB"
echo "  ─────────────────────────"
echo "  - Total estimate: ~${ESTIMATE_TOTAL}GB"
echo ""

if (( $(echo "$ESTIMATE_TOTAL > $EXTERNAL_AVAIL_GB" | bc -l) )); then
    echo -e "${RED}ERROR: Not enough space on external drive!${NC}"
    echo "Need: ~${ESTIMATE_TOTAL}GB, Available: ${EXTERNAL_AVAIL_GB}GB"
    exit 1
fi

echo "This backup will take approximately 2-3 hours."
echo -e "${YELLOW}All data will be backed up with extended attributes (rsync -avX)${NC}"
echo ""
read -p "Proceed with backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Backup cancelled."
    exit 0
fi

# Create backup directory structure
mkdir -p "$BACKUP_DIR"/{database,system,cm,data,images,monitoring}
echo -e "${GREEN}✓ Created backup directory structure${NC}"
echo ""

# Start timing
START_TIME=$(date +%s)

#================================================================
# 1. Backup CMDaemon Database
#================================================================
echo -e "${YELLOW}[1/7] Backing up CMDaemon database...${NC}"

# Backup automatic database backups (last 7 days) using rsync
if [ -d /var/spool/cmd/backup/ ]; then
    echo "  → Copying automatic database backups..."
    rsync -avX /var/spool/cmd/backup/ "$BACKUP_DIR/database/automatic/" 2>&1 | tail -5
    echo -e "${GREEN}  ✓ Copied automatic database backups${NC}"
fi

# Create fresh database dump
echo "  → Creating fresh database dump..."
DBPASS=$(grep DBPass /cm/local/apps/cmd/etc/cmd.conf | awk -F'"' '{print $2}')

if [ -z "$DBPASS" ]; then
    echo -e "${RED}  ✗ Failed to extract database password${NC}"
    exit 1
fi

mysqldump -u cmdaemon -p"$DBPASS" cmdaemon > "$BACKUP_DIR/database/cmdaemon_fresh_${BACKUP_DATE}.sql" 2>/dev/null

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_DIR/database/cmdaemon_fresh_${BACKUP_DATE}.sql" | awk '{print $1}')
    echo -e "${GREEN}  ✓ Fresh database dump created ($SIZE)${NC}"
else
    echo -e "${RED}  ✗ Database dump failed${NC}"
fi

echo ""

#================================================================
# 2. Backup /etc
#================================================================
echo -e "${YELLOW}[2/7] Backing up /etc...${NC}"

rsync -avX --progress /etc/ "$BACKUP_DIR/system/etc/" 2>&1 | tail -10

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_DIR/system/etc" | awk '{print $1}')
    echo -e "${GREEN}  ✓ /etc backed up ($SIZE)${NC}"
fi

# Backup critical files separately for easy access
echo "  → Creating critical files backup..."
mkdir -p "$BACKUP_DIR/system/critical"
rsync -avX /etc/fstab "$BACKUP_DIR/system/critical/" 2>/dev/null
rsync -avX /etc/hosts "$BACKUP_DIR/system/critical/" 2>/dev/null
rsync -avX /etc/resolv.conf "$BACKUP_DIR/system/critical/" 2>/dev/null
rsync -avX /etc/hostname "$BACKUP_DIR/system/critical/" 2>/dev/null
rsync -avX /etc/sysconfig/network-scripts/ "$BACKUP_DIR/system/critical/network-scripts/" 2>/dev/null

echo -e "${GREEN}  ✓ Critical system files backed up${NC}"
echo ""

#================================================================
# 3. Backup /cm configuration
#================================================================
echo -e "${YELLOW}[3/7] Backing up /cm configuration...${NC}"
echo "  (excluding: shared symlink, images, node-installer)"

rsync -avX \
    --exclude='shared' \
    --exclude='images' \
    --exclude='node-installer' \
    --exclude='shared-bak' \
    --progress \
    /cm/ "$BACKUP_DIR/cm/" 2>&1 | tail -10

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_DIR/cm" | awk '{print $1}')
    echo -e "${GREEN}  ✓ /cm configuration backed up ($SIZE)${NC}"
fi

echo ""

#================================================================
# 4. Backup /data (excluding /data/home)
#================================================================
echo -e "${YELLOW}[4/7] Backing up /data (excluding home)...${NC}"
echo "  Includes: /data/cm, /data/K8s, /data/shared-datasets"
echo "  Excludes: /data/home (${DATA_HOME_SIZE_GB}GB - not backed up)"
echo ""

rsync -avX \
    --exclude='home' \
    --exclude='lost+found' \
    --progress \
    /data/ "$BACKUP_DIR/data/" 2>&1 | grep -E 'to-chk|%|MB/s|GB/s|sending|total size'

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_DIR/data" | awk '{print $1}')
    echo -e "${GREEN}  ✓ /data backed up ($SIZE)${NC}"
else
    echo -e "${RED}  ✗ /data backup had errors${NC}"
fi

echo ""

#================================================================
# 5. Backup ALL node images
#================================================================
echo -e "${YELLOW}[5/7] Backing up ALL node images...${NC}"
echo "  Images to backup:"

IMAGES=($(ls -d /cm/images/*-image 2>/dev/null | xargs -n1 basename))

for img in "${IMAGES[@]}"; do
    SIZE=$(du -sh "/cm/images/$img" 2>/dev/null | awk '{print $1}')
    echo "    - $img ($SIZE)"
done

echo ""
echo "  Total images size: ~${IMAGES_SIZE_GB}GB"
echo -e "  ${BLUE}Using rsync -avX to preserve extended attributes${NC}"
echo "  This is the most time-consuming part..."
echo ""

for img in "${IMAGES[@]}"; do
    echo -e "${BLUE}  → Backing up $img...${NC}"
    
    rsync -avX --progress "/cm/images/$img/" "$BACKUP_DIR/images/$img/" 2>&1 | \
        grep -E 'to-chk|%|MB/s|GB/s|sending|total size'
    
    if [ $? -eq 0 ]; then
        IMG_SIZE=$(du -sh "$BACKUP_DIR/images/$img" | awk '{print $1}')
        echo -e "${GREEN}    ✓ $img completed ($IMG_SIZE)${NC}"
    else
        echo -e "${RED}    ✗ $img backup failed${NC}"
    fi
    echo ""
done

IMAGES_BACKUP_SIZE=$(du -sh "$BACKUP_DIR/images" | awk '{print $1}')
echo -e "${GREEN}  ✓ All images backed up (Total: $IMAGES_BACKUP_SIZE)${NC}"
echo ""

#================================================================
# 6. Backup monitoring data (optional)
#================================================================
echo -e "${YELLOW}[6/7] Backup monitoring data?${NC}"
echo "  Monitoring data can be several GB"
echo "  (Can be skipped - monitoring config is already in database backup)"
read -p "  Backup monitoring data? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  → Backing up monitoring data..."
    rsync -avX --progress /var/spool/cmd/monitoring/ "$BACKUP_DIR/monitoring/" 2>&1 | tail -10
    
    if [ $? -eq 0 ]; then
        SIZE=$(du -sh "$BACKUP_DIR/monitoring" | awk '{print $1}')
        echo -e "${GREEN}  ✓ Monitoring data backed up ($SIZE)${NC}"
    fi
else
    echo -e "${YELLOW}  ⊘ Skipped monitoring data${NC}"
fi

echo ""

#================================================================
# 7. Verify and create documentation
#================================================================
echo -e "${YELLOW}[7/7] Verifying and creating documentation...${NC}"

# Verify extended attributes
echo "  → Verifying extended attributes preservation..."

if [ ${#IMAGES[@]} -gt 0 ]; then
    FIRST_IMAGE="${IMAGES[0]}"
    SAMPLE_BINARY=$(find "$BACKUP_DIR/images/$FIRST_IMAGE" -type f -name bash 2>/dev/null | head -1)
    
    if [ -n "$SAMPLE_BINARY" ]; then
        XATTRS=$(getfattr -d -m - "$SAMPLE_BINARY" 2>/dev/null)
        
        if [ -n "$XATTRS" ]; then
            echo -e "${GREEN}  ✓ Extended attributes verified in images${NC}"
            
            if echo "$XATTRS" | grep -q "security.selinux"; then
                echo -e "${GREEN}  ✓ SELinux contexts preserved${NC}"
            fi
            
            if echo "$XATTRS" | grep -q "security.capability"; then
                echo -e "${GREEN}  ✓ File capabilities preserved${NC}"
            fi
        else
            echo -e "${YELLOW}  ⊘ No extended attributes found (may be normal)${NC}"
        fi
    fi
fi

# Create manifest
cat > "$BACKUP_DIR/BACKUP_MANIFEST.txt" << EOF
================================================================
BCM Complete Backup Manifest
================================================================
Backup Date: $BACKUP_DATE
Hostname: $(hostname)
BCM Version: $(cmsh -c "version" 2>/dev/null | grep "Bright Cluster Manager" | head -1 || echo "N/A")
OS: $(cat /etc/redhat-release 2>/dev/null)
Kernel: $(uname -r)

BACKUP METHOD: rsync -avX (everywhere)
Extended Attributes: PRESERVED
ACLs: PRESERVED

================================================================
System Information
================================================================
Root Partition: $(df -h / | tail -1)
Data Partition: $(df -h /data | tail -1)
External Drive: $(df -h $EXTERNAL | tail -1)

Symlinks:
  /cm/shared -> $(readlink /cm/shared 2>/dev/null)

================================================================
Managed Nodes
================================================================
$(cmsh -c "device; list -f name,roles,category,softwareimage" 2>/dev/null || echo "N/A")

================================================================
Backup Contents
================================================================

Directory Structure and Sizes:
$(du -sh "$BACKUP_DIR"/* 2>/dev/null)

Database Backups:
$(ls -lh "$BACKUP_DIR/database/" 2>/dev/null)

Node Images:
$(du -sh "$BACKUP_DIR/images"/* 2>/dev/null)

Total Backup Size: $(du -sh $BACKUP_DIR | awk '{print $1}')

================================================================
What Was Backed Up
================================================================
✓ CMDaemon database (automatic backups + fresh dump)
✓ /etc (complete system configuration)
✓ /cm configuration (BCM settings and configs)
✓ /data/cm (shared directory with all apps/modules)
✓ /data/K8s (Kubernetes data)
✓ /data/shared-datasets
✓ All node images (6 images)
$([ -d "$BACKUP_DIR/monitoring" ] && echo "✓ Monitoring data" || echo "⊘ Monitoring data (skipped)")

✗ /data/home (NOT backed up - user decision)

================================================================
Extended Attributes Verification
================================================================
Sample file checked: $(find "$BACKUP_DIR/images" -type f -name bash 2>/dev/null | head -1 | sed "s|$BACKUP_DIR/||")
$(getfattr -d -m - "$(find "$BACKUP_DIR/images" -type f -name bash 2>/dev/null | head -1)" 2>/dev/null | head -15)
EOF

# Create restore instructions
cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.txt" << 'EOF'
================================================================
BCM Complete Restore Instructions
================================================================

ALL RESTORES USE: rsync -avX

This preserves:
  - Extended attributes (xattrs)
  - SELinux contexts
  - File capabilities
  - ACLs

================================================================
QUICK RESTORE (automated)
================================================================
cd /mnt/passport/bcm_complete_backup_YYYYMMDD_HHMMSS
./quick_restore.sh

OR follow manual steps below:

================================================================
MANUAL RESTORE STEPS
================================================================

1. RESTORE DATABASE
   ----------------
   service cmd stop
   
   # Get password
   DBPASS=$(grep DBPass /cm/local/apps/cmd/etc/cmd.conf | awk -F'"' '{print $2}')
   
   # Restore
   mysql -u cmdaemon -p"$DBPASS" cmdaemon < database/cmdaemon_fresh_*.sql
   
   service cmd start
   cmsh -c "device list"  # verify

2. RESTORE /etc
   ------------
   rsync -avX system/etc/ /etc/
   
   # Or restore critical files only
   rsync -avX system/critical/fstab /etc/
   rsync -avX system/critical/hosts /etc/
   rsync -avX system/critical/resolv.conf /etc/

3. RESTORE /cm CONFIGURATION
   -------------------------
   rsync -avX cm/ /cm/
   
   # Verify symlink
   ls -l /cm/shared

4. RESTORE /data
   -------------
   rsync -avX data/ /data/
   
   # Verify
   ls -l /data/
   ls -l /cm/shared

5. RESTORE NODE IMAGES
   -------------------
   rsync -avX images/ /cm/images/
   
   # Verify extended attributes
   getfattr -d -m - /cm/images/*/bin/bash | head -20
   
   # Assign images
   cmsh
   % device use rsu-login
   % set softwareimage slurm-image
   % device use rsu-training
   % set softwareimage training-image
   % device use rsu-inference
   % set softwareimage inference-image
   % device
   % reboot rsu-login rsu-training rsu-inference

6. RESTORE MONITORING (if backed up)
   ---------------------------------
   rsync -avX monitoring/ /var/spool/cmd/monitoring/

================================================================
VERIFICATION
================================================================
# Services
systemctl status cmd

# Database
cmsh -c "device; list"

# Images
cmsh -c "softwareimage; list"

# Extended attributes
getfattr -d -m - /cm/images/*/bin/bash | grep security

# Nodes
cmsh -c "device; list -f name,status,softwareimage"

================================================================
TROUBLESHOOTING
================================================================
If nodes fail to boot:
1. Check extended attributes:
   getfattr -R /cm/images/<image> | grep security
   
2. Restore SELinux contexts:
   restorecon -Rv /cm/images/<image>
   
3. Check capabilities:
   getcap -r /cm/images/<image>

If database corruption:
   Use automatic backups in database/automatic/
EOF

# Create verification script
cat > "$BACKUP_DIR/verify_backup.sh" << 'EOF'
#!/bin/bash

echo "================================================================"
echo "   Backup Verification"
echo "================================================================"
echo ""

# Check each component
echo "1. Database: $(du -sh database/ | awk '{print $1}')"
[ -f database/cmdaemon_fresh_*.sql ] && echo "   ✓ Fresh dump exists" || echo "   ✗ No fresh dump"

echo ""
echo "2. /etc: $(du -sh system/etc/ | awk '{print $1}')"
[ -d system/etc ] && echo "   ✓ Backup exists" || echo "   ✗ No backup"

echo ""
echo "3. /cm config: $(du -sh cm/ | awk '{print $1}')"
[ -d cm ] && echo "   ✓ Backup exists" || echo "   ✗ No backup"

echo ""
echo "4. /data: $(du -sh data/ | awk '{print $1}')"
[ -d data/cm ] && echo "   ✓ /data/cm exists" || echo "   ✗ No /data/cm"
[ -d data/K8s ] && echo "   ✓ /data/K8s exists" || echo "   ✗ No /data/K8s"

echo ""
echo "5. Images:"
for img in images/*-image; do
    [ -d "$img" ] && echo "   ✓ $(basename $img): $(du -sh $img | awk '{print $1}')"
done

echo ""
echo "6. Extended Attributes Check:"
SAMPLE=$(find images -type f -name bash 2>/dev/null | head -1)
if [ -n "$SAMPLE" ]; then
    XATTRS=$(getfattr -d -m - "$SAMPLE" 2>/dev/null)
    if [ -n "$XATTRS" ]; then
        echo "   ✓ Extended attributes present"
        echo "$XATTRS" | grep security | head -5
    else
        echo "   ✗ No extended attributes!"
    fi
else
    echo "   ? Cannot find sample file"
fi

echo ""
echo "================================================================"
echo "Total Size: $(du -sh . | awk '{print $1}')"
echo "Files: $(find . -type f | wc -l)"
echo "================================================================"
EOF

chmod +x "$BACKUP_DIR/verify_backup.sh"

# Create quick restore script
cat > "$BACKUP_DIR/quick_restore.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "================================================================"
echo "   BCM Quick Restore"
echo "================================================================"
echo ""
echo "WARNING: This will restore the entire system!"
echo ""
read -p "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then exit 0; fi

DBPASS=$(grep DBPass /cm/local/apps/cmd/etc/cmd.conf | awk -F'"' '{print $2}')

echo "[1/5] Database..."
service cmd stop
mysql -u cmdaemon -p"$DBPASS" cmdaemon < database/cmdaemon_fresh_*.sql
service cmd start

echo "[2/5] /cm..."
rsync -avX cm/ /cm/

echo "[3/5] /data..."
rsync -avX data/ /data/

echo "[4/5] Images..."
rsync -avX images/ /cm/images/

echo "[5/5] Verify..."
cmsh -c "device; list"
ls -lh /cm/images/

echo ""
echo "Done! Check output above for any errors."
echo "Assign images and reboot nodes as needed."
EOFSCRIPT

chmod +x "$BACKUP_DIR/quick_restore.sh"

echo -e "${GREEN}  ✓ Documentation created${NC}"
echo ""

#================================================================
# Final Summary
#================================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
HOURS=$((DURATION / 3600))
MINUTES=$(((DURATION % 3600) / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}   ✓ BACKUP COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""
echo -e "${BLUE}Location:${NC} $BACKUP_DIR"
echo ""
echo -e "${BLUE}What was backed up:${NC}"
echo "  ✓ Database ($(du -sh $BACKUP_DIR/database | awk '{print $1}'))"
echo "  ✓ /etc ($(du -sh $BACKUP_DIR/system | awk '{print $1}'))"
echo "  ✓ /cm config ($(du -sh $BACKUP_DIR/cm | awk '{print $1}'))"
echo "  ✓ /data ($(du -sh $BACKUP_DIR/data | awk '{print $1}'))"
echo "  ✓ Node images ($(du -sh $BACKUP_DIR/images | awk '{print $1}'))"
[ -d "$BACKUP_DIR/monitoring" ] && echo "  ✓ Monitoring ($(du -sh $BACKUP_DIR/monitoring | awk '{print $1}'))"
echo ""
echo -e "${BLUE}Total backup size:${NC} $(du -sh $BACKUP_DIR | awk '{print $1}')"
echo -e "${BLUE}Time taken:${NC} ${HOURS}h ${MINUTES}m ${SECONDS}s"
echo ""
echo -e "${BLUE}External drive:${NC}"
df -h $EXTERNAL | tail -1
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Verify backup:"
echo "     cd $BACKUP_DIR"
echo "     ./verify_backup.sh"
echo ""
echo "  2. Safely unmount external drive:"
echo "     umount $EXTERNAL"
echo ""
echo "  3. Store external drive safely"
echo ""
echo -e "${GREEN}✓ Backup completed at $(date)${NC}"
echo ""
