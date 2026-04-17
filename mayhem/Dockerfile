FROM debian:bookworm AS builder

RUN apt-get update && apt-get install -y g++ make wget clang curl

RUN wget -q https://github.com/bazelbuild/bazel/releases/download/6.5.0/bazel-6.5.0-linux-x86_64 -O /usr/local/bin/bazel && \
    chmod +x /usr/local/bin/bazel

COPY . /qsim
WORKDIR /qsim/

RUN clang mayhem/fuzz_expand_bits.cpp -fsanitize=fuzzer,address -o /fuzz
RUN bazel build //apps:qsim_base

FROM debian:bookworm AS package

COPY --from=builder /fuzz /fuzz_expand_bits
COPY --from=builder /qsim/bazel-bin/apps/qsim_base /qsim/bazel-bin/apps/qsim_base
ENV LD_LIBRARY_PATH=/deps
