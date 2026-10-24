# llama.cpp server (CUDA) with DeepSeek-V4.1 support (upstream PR #30817)
# For Hugging Face Inference Endpoints (NVIDIA A100 = CUDA arch 80)
# Model: orcarouter/DeepSeek-V4.1-Flash-1017-abliterated-GGUF

ARG CUDA_VERSION=12.4.0

# ---------- build stage ----------
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04 AS build

ARG PR_NUMBER=30817
ARG COMMIT=b72050d03
ARG CUDA_ARCH=80

RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake build-essential libcurl4-openssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/ggml-org/llama.cpp
WORKDIR /src/llama.cpp
RUN git fetch origin pull/${PR_NUMBER}/head:pr-${PR_NUMBER} && git checkout ${COMMIT}

RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} \
        -DGGML_NATIVE=OFF \
        -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON -DGGML_BMI2=ON \
        -DLLAMA_CURL=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
    && cmake --build build --config Release -j"$(nproc)" --target llama-server

# ---------- runtime stage ----------
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04 AS server

RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 libcurl4 curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /src/llama.cpp/build/bin/ /app/

ENV LD_LIBRARY_PATH=/app
ENV LLAMA_ARG_HOST=0.0.0.0

HEALTHCHECK CMD ["curl", "-f", "http://localhost:8080/health"]
ENTRYPOINT ["/app/llama-server"]
