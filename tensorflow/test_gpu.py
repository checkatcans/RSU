import tensorflow as tf

print("TensorFlow version:", tf.__version__)
print("Built with CUDA:", tf.test.is_built_with_cuda())
print("GPU devices:", tf.config.list_physical_devices('GPU'))

# Test GPU computation
if tf.config.list_physical_devices('GPU'):
    print("\nGPU is available and working!")
    
    # Create a simple computation on GPU
    with tf.device('/GPU:0'):
        a = tf.constant([[1.0, 2.0], [3.0, 4.0]])
        b = tf.constant([[5.0, 6.0], [7.0, 8.0]])
        c = tf.matmul(a, b)
    
    print("Matrix multiplication result:")
    print(c.numpy())
else:
    print("\nNo GPU found. Running on CPU.")
