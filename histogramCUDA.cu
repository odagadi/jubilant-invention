#include <cuda_runtime.h>
#include <helper_cuda.h>
#include "myProto.h"

__global__  void computeOnGPU(int *arr, int numElements, int *histogram) {
    int g_index = blockDim.x * blockIdx.x + threadIdx.x;
    __shared__ int shared_data[HISTOGRAM_SIZE];
    shared_data[threadIdx.x]=0;
    
    if (g_index < numElements)
        atomicAdd(&shared_data[arr[g_index]],1);

    __syncthreads();
    atomicAdd(&histogram[threadIdx.x], shared_data[threadIdx.x]);    
    __syncthreads();
}

int histogramOnGPU(int *data, int numElements, int *histogram) {
    // Error to check returned from CUDA
    cudaError_t err = cudaSuccess;

    size_t size = numElements * sizeof(int);

    // Alloc on GPU and copy from the host
    int *d_data, *d_histo;
    err = cudaMalloc((void **)&d_data, size);
    if (err != cudaSuccess) {
        fprintf(stderr, "faile alloc of device mem - %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    // copy form hsot to GPU
    err = cudaMemcpy(d_data, data, size, cudaMemcpyHostToDevice);
    if (err != cudaSuccess) {
        fprintf(stderr, "failed copy from host - %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaMalloc((void **)&d_histo, HISTOGRAM_SIZE*sizeof(int));
    if (err != cudaSuccess) {
        fprintf(stderr, "failed alloa device mem - %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaMemset(d_histo,0, HISTOGRAM_SIZE*sizeof(int));
    if (err != cudaSuccess) {
        fprintf(stderr, "failed set device mem - %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }


    // Initiate Kernel
    int blocks =(numElements + HISTOGRAM_SIZE - 1) / HISTOGRAM_SIZE;
    computeOnGPU<<<blocks, HISTOGRAM_SIZE>>>(d_data, numElements, d_histo);
    err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "failed to launch vector add -  %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    
    // Copy from GPU to host.
    err = cudaMemcpy(histogram, d_histo, HISTOGRAM_SIZE*sizeof(int), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess) {
        fprintf(stderr, "failed to copy from GPU to host -%s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    // Free memory
    if (cudaFree(d_data) != cudaSuccess) {
        fprintf(stderr, "Failed to free mem - %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    if (cudaFree(d_histo) != cudaSuccess) {
        fprintf(stderr, "Failed to free data - %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    return 0;
}

