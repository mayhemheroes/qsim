# Base OS 
FROM debian as builder

# Install baseline
RUN apt-get update
RUN apt-get install -y g++ make wget clang

RUN apt install -y apt-transport-https curl gnupg
RUN curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg
RUN mv bazel.gpg /etc/apt/trusted.gpg.d/
RUN echo 'deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8' | tee /etc/apt/sources.list.d/bazel.list
RUN apt update && apt install -y bazel

COPY . /qsim

WORKDIR /qsim/
RUN clang mayhem/fuzz_expand_bits.cpp -fsanitize=fuzzer,address -o /fuzz
RUN bazel build //apps:qsim_base

FROM debian as package

COPY --from=builder /fuzz /fuzz_expand_bits
COPY --from=builder /qsim/bazel-bin/apps/qsim_base /qsim/bazel-bin/apps/qsim_base
ENV LD_LIBRARY_PATH=/deps
