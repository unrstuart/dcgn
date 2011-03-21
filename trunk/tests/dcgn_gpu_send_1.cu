#include <dcgn/dcgn.h>
#include <dcgn/CUDAFunctions.h>
#include <cstdlib>
#include <cstdio>

const int MIN_SIZE = 1;
const int MAX_SIZE = 1048576;
const int ITERS = 30;

__shared__ clock_t timers[31];

__global__ void kernel(void * gmem, clock_t * clocks, const dcgn::GPUInitRequest libParam)
{
  dcgn::gpu::init(libParam);
  int index = 0;
  for (int i = MIN_SIZE; i <= MAX_SIZE; i *= 2)
  {
    dcgn::CommStatus stat;
    dcgn::gpu::barrier(0);
    timers[index] = clock();
    for (int j = 0; j < ITERS; ++j)
    {
      if (dcgn::gpu::getRank(0) == 0) dcgn::gpu::send(0, 1, gmem, i);
      else                            dcgn::gpu::recv(0, 0, gmem, i, &stat);
    }
    timers[index] = (clock() - timers[index]) / ITERS;
    dcgn::gpu::barrier(0);
    ++index;
  }
  for (int i = 0; i < index; ++i)
  {
    clocks[i] = timers[i];
  }
}

__host__ void gpuKernel(void * info, const dcgn::GPUInitRequest libParam, const uint3 & gridSize, const uint3 & blockSize, const int sharedMemSize, cudaStream_t * const stream)
{
  void ** mem = (void ** )info;
  cudaMalloc(mem, MAX_SIZE);
  kernel<<<gridSize, blockSize, sharedMemSize, *stream>>>(*mem, (clock_t *)*mem, libParam);
}

__host__ void gpuDtor(void * info)
{
  if (dcgn::getNodeID() != 0) return;
  void ** ptr;
  clock_t clocks[31];

  int deviceIndex = 0;
  CUdevice dev;
  CUdevprop prop;
  cuInit(0);
  cuDeviceGet(&dev, deviceIndex);
  cuDeviceGetProperties(&prop, dev);

  ptr = (void ** )info;
  cudaMemcpy(clocks, *ptr, sizeof(clock_t) * 31, cudaMemcpyDeviceToHost);
  int index = 0;
  for (int i = MIN_SIZE; i <= MAX_SIZE; i *= 2)
  {
    printf("%10d - %20.10f ms\n", i, ((double)clocks[index] / (double)prop.clockRate));
    ++index;
  }
  cudaFree(*ptr);
}

int main(int argc, char ** argv)
{
  void * gpuMem;
  int gpus[] = { 0, -1 };
  uint3 gs = { 1, 1, 1 }, bs = { 1, 1, 1 };

  dcgn::init(&argc, &argv);
  dcgn::initComm(-1);
  dcgn::initCPU(0);
  dcgn::initGPU(gpus, 1, 0);
  dcgn::start();

  dcgn::launchGPUKernel(0, gpuKernel, gpuDtor, &gpuMem, gs, bs);

  dcgn::finalize();
  return 0;
}
