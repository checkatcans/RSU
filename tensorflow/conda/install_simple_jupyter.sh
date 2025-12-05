conda create -n tf_nvidia_25.02 python=3.12.3 -y
conda activate tf_nvidia_25.02

# 2. Install CUDA, cuDNN, NCCL
conda install -c nvidia -c conda-forge -y cuda-toolkit=12.8 cudnn=9.7.1 nccl=2.25.1

# 3. Install MPI and UCX
conda install -c conda-forge -y openmpi=4.1.7 ucx=1.18.0

# 4. Install TensorFlow with GPU
pip install tensorflow[and-cuda]

# 5. Install NVIDIA packages
pip install \
    nvidia-cuda-runtime-cu12==12.8.0 \
    nvidia-cublas-cu12==12.8.3.14 \
    nvidia-cudnn-cu12==9.7.1.26 \
    cutensor-cu12

# 6. Install TensorRT and TensorFlow-TensorRT
pip install tensorrt==10.8.0 tensorflow-tensorrt

# 7. Install TensorBoard
pip install tensorboard==2.17.1

# 8. Install DALI and nvImageCodec
pip install --extra-index-url https://pypi.nvidia.com nvidia-dali-cuda120==1.46
pip install nvidia-nvimgcodec-cu12==0.3.0

# 9. Install RAPIDS
pip install cudf-cu12==24.12.* cuml-cu12==24.12.* cugraph-cu12==24.12.* cupy-cuda12x

# 10. Install Horovod
HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITH_MPI=1 pip install horovod==0.28.1

conda install -y matplotlib





# 11. Install Simple Jupyter Notebook (NOT JupyterLab)
pip install notebook==6.5.7 jupyter jupyter-client jupyter-core ipykernel ipywidgets tensorboar
