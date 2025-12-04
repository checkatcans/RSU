#!/bin/bash
#SBATCH --job-name=ngc_gpu_test
#SBATCH --nodes=1
#SBATCH --gres=gpu:1 # Request 1 GPU
#SBATCH --time=00:10:00
#SBATCH --mem=16G

# get tunneling info
XDG_RUNTIME_DIR=""
port=$(shuf -i8000-9999 -n1)
node=$(hostname -s)
user=$(whoami)
cluster=$(hostname -f | awk -F"." '{print $2}')

# print tunneling instructions jupyter-log
echo -e "

MacOS or linux terminal command to create your ssh tunnel
ssh -N -L ${port}:${node}:${port} ${user}@${cluster}

Windows MobaXterm info
Forwarded port:same as remote port
Remote server: ${node}
Remote port: ${port}
SSH server: ${cluster}
SSH login: $user
SSH port: 22

Use a Browser on your local machine to go to:
localhost:${port}  (prefix w/ https:// if using password)
"

# load modules or conda environments here
# uncomment the following two lines to use your conda environment called notebook_env
# module load miniconda
# source activate notebook_env

srun --container-image="nvcr.io#nvidia/tensorflow:25.02-tf2-py3" \
     --container-mount-home \
        jupyter-notebook --no-browser --port=${port} --ip=0.0.0.0
