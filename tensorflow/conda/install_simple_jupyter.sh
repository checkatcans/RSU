#!/bin/bash
# NVIDIA TensorFlow 25.02 Environment with Simple Jupyter Notebook
# Python 3.12.3 with all NVIDIA components

set -e

ENV_NAME="tf_nvidia_25.02"

echo "=========================================="
echo "Creating NVIDIA TensorFlow 25.02 Environment"
echo "with Simple Jupyter Notebook"
echo "=========================================="
echo ""

# Create conda environment with Python 3.12.3
echo "Step 1: Creating conda environment with Python 3.12.3..."
conda create -n $ENV_NAME python=3.12.3 -y

# Activate environment
echo "Step 2: Activating environment..."
eval "$(conda shell.bash hook)"
conda activate $ENV_NAME

# Install CUDA 12.8 and related libraries
echo "Step 3: Installing CUDA 12.8, cuDNN 9.7.1, NCCL 2.25.1..."
conda install -c nvidia -c conda-forge -y \
    cuda-toolkit=12.8 \
    cudnn=9.7.1 \
    nccl=2.25.1

# Install OpenMPI 4.1.7 and OpenUCX 1.18.0
echo "Step 4: Installing OpenMPI 4.1.7 and OpenUCX 1.18.0..."
conda install -c conda-forge -y \
    openmpi=4.1.7 \
    ucx=1.18.0

# Install TensorFlow with GPU support
echo "Step 5: Installing TensorFlow with GPU support..."
pip install --no-cache-dir tensorflow[and-cuda]

# Install NVIDIA CUDA Python packages
echo "Step 6: Installing NVIDIA CUDA packages..."
pip install --no-cache-dir \
    nvidia-cuda-runtime-cu12==12.8.0 \
    nvidia-cublas-cu12==12.8.3.14 \
    nvidia-cudnn-cu12==9.7.1.26 \
    nvidia-cufft-cu12 \
    nvidia-curand-cu12 \
    nvidia-cusolver-cu12 \
    nvidia-cusparse-cu12

# Install cuTENSOR 2.1.1.1
echo "Step 7: Installing cuTENSOR..."
pip install --no-cache-dir cutensor-cu12

# Install TensorRT 10.8.0.43
echo "Step 8: Installing TensorRT 10.8.0..."
pip install --no-cache-dir tensorrt==10.8.0

# Install TensorFlow-TensorRT
echo "Step 9: Installing TensorFlow-TensorRT..."
pip install --no-cache-dir tensorflow-tensorrt

# Install TensorBoard 2.17.1
echo "Step 10: Installing TensorBoard 2.17.1..."
pip install --no-cache-dir tensorboard==2.17.1

# Install NVIDIA DALI 1.46
echo "Step 11: Installing NVIDIA DALI 1.46..."
pip install --no-cache-dir --extra-index-url https://pypi.nvidia.com \
    nvidia-dali-cuda120==1.46

# Install nvImageCodec 0.3.0.5
echo "Step 12: Installing nvImageCodec 0.3.0.5..."
pip install --no-cache-dir nvidia-nvimgcodec-cu12==0.3.0

# Install RAPIDS 24.12
echo "Step 13: Installing RAPIDS 24.12 (this may take a while)..."
pip install --no-cache-dir \
    cudf-cu12==24.12.* \
    cuml-cu12==24.12.* \
    cugraph-cu12==24.12.* \
    cupy-cuda12x

# Install Horovod 0.28.1
echo "Step 14: Installing Horovod 0.28.1..."
HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITH_MPI=1 \
pip install --no-cache-dir horovod==0.28.1

# Install Simple Jupyter Notebook (NOT JupyterLab)
echo "Step 15: Installing Simple Jupyter Notebook..."
pip install --no-cache-dir \
    notebook==6.5.7 \
    jupyter \
    jupyter-client \
    jupyter-core \
    ipykernel \
    ipywidgets

# Install Jupyter TensorBoard extension
echo "Step 16: Installing Jupyter TensorBoard..."
pip install --no-cache-dir jupyter-tensorboard

# Enable extensions
echo "Step 17: Enabling Jupyter extensions..."
jupyter nbextension enable --py widgetsnbextension --sys-prefix

# Install common ML packages
echo "Step 18: Installing additional packages..."
pip install --no-cache-dir \
    numpy \
    scipy \
    pandas \
    matplotlib \
    seaborn \
    scikit-learn \
    Pillow \
    opencv-python \
    h5py

echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="

# Verify installation
python << 'EOF'
import sys
print(f"Python version: {sys.version.split()[0]}")

import tensorflow as tf
print(f"\nTensorFlow version: {tf.__version__}")
print(f"Built with CUDA: {tf.test.is_built_with_cuda()}")
gpus = tf.config.list_physical_devices('GPU')
print(f"GPU devices: {len(gpus)}")
for i, gpu in enumerate(gpus):
    print(f"  GPU {i}: {gpu.name}")

try:
    import tensorrt
    print(f"\nTensorRT: {tensorrt.__version__}")
except ImportError:
    print("\nTensorRT: Not available")

try:
    import nvidia.dali
    print(f"DALI: {nvidia.dali.__version__}")
except ImportError:
    print("DALI: Not available")

try:
    import cudf
    print(f"RAPIDS cuDF: {cudf.__version__}")
except ImportError:
    print("RAPIDS: Not available")

try:
    import horovod
    print(f"Horovod: {horovod.__version__}")
except ImportError:
    print("Horovod: Not available")

try:
    import notebook
    print(f"Jupyter Notebook: {notebook.__version__}")
except ImportError:
    print("Jupyter Notebook: Not available")

try:
    import tensorboard
    print(f"TensorBoard: {tensorboard.__version__}")
except ImportError:
    print("TensorBoard: Not available")
EOF

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Environment name: $ENV_NAME"
echo ""
echo "To activate this environment:"
echo "  conda activate $ENV_NAME"
echo ""
echo "To start Jupyter Notebook (Simple Interface):"
echo "  jupyter notebook"
echo ""
echo "To start JupyterLab (if needed later):"
echo "  pip install jupyterlab"
echo "  jupyter lab"
echo ""
echo "Default Jupyter Notebook URL:"
echo "  http://localhost:8888"
echo ""
