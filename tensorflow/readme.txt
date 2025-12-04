(tf_gpu) [uat01@rsu-login ~]$ conda create --name tf_gpu python=3.12.3
(tf_gpu) [uat01@rsu-login ~]$ conda activate tf_gpu
(tf_gpu) [uat01@rsu-login ~]$ conda install -c nvidia cudatoolkit
(tf_gpu) [uat01@rsu-login ~]$ conda install tensorflow
(tf_gpu) [uat01@rsu-login ~]$ conda install keras
(tf_gpu) [uat01@rsu-login ~]$ conda install jupyterlab tensorboard

# Result
2025-12-04 21:38:48.354891: E external/local_xla/xla/stream_executor/cuda/cuda_fft.cc:485] Unable to register cuFFT factory: Attempting to register factory for plugin cuFFT when one has already been registered
2025-12-04 21:38:48.395470: E external/local_xla/xla/stream_executor/cuda/cuda_dnn.cc:8473] Unable to register cuDNN factory: Attempting to register factory for plugin cuDNN when one has already been registered
2025-12-04 21:38:48.410145: E external/local_xla/xla/stream_executor/cuda/cuda_blas.cc:1471] Unable to register cuBLAS factory: Attempting to register factory for plugin cuBLAS when one has already been registered
2025-12-04 21:38:48.489780: I tensorflow/core/platform/cpu_feature_guard.cc:211] This TensorFlow binary is optimized to use available CPU instructions in performance-critical operations.
To enable the following instructions: SSE3 SSE4.1 SSE4.2 AVX, in other operations, rebuild TensorFlow with the appropriate compiler flags.
2025-12-04 21:38:51.928805: I tensorflow/core/common_runtime/gpu/gpu_device.cc:2021] Created device /job:localhost/replica:0/task:0/device:GPU:0 with 138533 MB memory:  -> device: 0, name: NVIDIA H200, pci bus id: 0000:04:00.0, compute capability: 9.0
TensorFlow version: 2.17.0
Built with CUDA: True
GPU devices: [PhysicalDevice(name='/physical_device:GPU:0', device_type='GPU')]

GPU is available and working!
Matrix multiplication result:
[[19. 22.]
 [43. 50.]]
