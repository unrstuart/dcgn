#include <dcgn/dcgn.h>
#include <dcgn/MPIWorker.h>

namespace dcgn
{
  int globalCPUCount()
  {
    return mpiWorker->getGlobalCPUCount();
  }
}

