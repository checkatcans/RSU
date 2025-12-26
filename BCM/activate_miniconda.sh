#!/bin/bash

# สร้าง list ของ user
USERS=(csc490-01 csc490-02 csc490-03 csc490-04 csc490-05 csc490-06 csc490-07 csc490-08 csc490-09 csc490-10 \
       csc490-11 csc490-12 csc490-13 csc490-14 csc490-15 csc490-16 csc490-17 csc490-18 csc490-19 csc490-20 \
       csc490-21 csc490-22 csc490-23 csc490-24 csc490-25 csc490-26 csc490-27 csc490-28 csc490-29 csc490-30)

for USERNAME in "${USERS[@]}"; do
    echo "Initializing conda for user: $USERNAME"
    su - $USERNAME -c '/cm/shared/apps/miniconda3/bin/conda init'
    echo "  ✓ Done"
done

echo "All 30 users conda initialized!"
