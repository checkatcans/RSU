
#!/bin/bash
#SBATCH --job-name=ngc_gpu_test
#SBATCH --nodes=1
#SBATCH --gres=gpu:1 # Request 1 GPU
#SBATCH --time=00:10:00
#SBATCH --mem=16G

srun --container-image="nvcr.io#nvidia/tensorflow:25.02-tf2-py3" \
     --container-mount-home \
        python /home/uat01/model/test_gpu.py
