#include <stdint.h>
#include <stdio.h>
#include "../lib/bits.h"
#include <climits>

#include <fuzzer/FuzzedDataProvider.h>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    FuzzedDataProvider provider(data, size);
    int bits = provider.ConsumeIntegral<int>();
    unsigned n = provider.ConsumeIntegralInRange<unsigned>(1, 15);
    int mask = provider.ConsumeIntegral<int>();
    qsim::bits::ExpandBits(bits, n, mask);

    return 0;
}