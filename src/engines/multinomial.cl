
__kernel void discreteMonteCarloKernel(__global float *callSums,
                                       float const optionPrice, int const steps,
                                       uint const seedA, uint const seedB, float const stockPrice,
                                       __global float *globalShifts,
                                       __local float *shifts) {

  async_work_group_copy(shifts, globalShifts, 64, 0);

  float cumulativeWalk = 0;
  float currentValue = stockPrice;

  uint n = get_global_id(0);
  uint iterations = get_global_size(0);
  uint2 seed2 = (uint2) (seedB ^seedA*n,seedA ^ seedB*(n+1));
  uint random = MWC64X(&seed2);

  for (int j = 0; j < steps; j = j) {
    random = MWC64X(&seed2);
    int stepsLeft = steps - j;
    if(stepsLeft>5){
    stepsLeft=5;
    }
    for (int i = 0; i < stepsLeft; i++) {
      cumulativeWalk += currentValue;
      currentValue = currentValue * shifts[random & 0b111111];
      cumulativeWalk += currentValue;
      random = random >> 6;
      j++;
    }
  }

  callSums[n] = generatePayoff(optionPrice, cumulativeWalk, 2 * steps);
}

__kernel void discreteMonteCarloKernelAntithetic(
    __global float *callSums, float const optionPrice, int const steps,
    uint const seedA, uint const seedB, float const stockPrice, __global float *globalShifts,
    __local float *shifts) {

      async_work_group_copy(shifts, globalShifts, 64, 0);

  float cumulativeWalk = 0;
  float currentValue = stockPrice;
  float cumulativeWalk2 = 0;
  float currentValue2 = stockPrice;

  uint n = get_global_id(0);
  uint iterations = get_global_size(0);
  uint2 seed2 = (uint2) (seedB ^seedA*n,seedA ^ seedB*(n+1));
  uint random = MWC64X(&seed2);

  //float shifts[16] = {u2, u1, u1, u1, u1, m, m, m, m, m, m, d1, d1, d1, d1, d2};

  for (int j = 0; j < steps; j = j) {
    random = MWC64X(&seed2);
    int stepsLeft = steps - j;
    if(stepsLeft>5){
    stepsLeft=5;
    }
    for (int i = 0; i < stepsLeft; i++) {
      cumulativeWalk += currentValue;
      cumulativeWalk2 += currentValue2;
      currentValue = currentValue * shifts[random & 0b111111];
      currentValue2 = currentValue2 * shifts[(0xffffffff - random & 0b111111)];
      cumulativeWalk += currentValue;
      cumulativeWalk2 += currentValue2;
      random = random >> 6;
      j++;
    }
  }

  callSums[n] = generatePayoff(optionPrice, cumulativeWalk, 2 * steps);
  callSums[iterations + n] =
      generatePayoff(optionPrice, cumulativeWalk2, 2 * steps);
}
