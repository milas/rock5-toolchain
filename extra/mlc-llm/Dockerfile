# syntax=docker/dockerfile:1-labs

ARG MODEL=RedPajama-INCITE-Chat-3B-v1-q4f16_1
# WARNING: Llama-2 requires 16GB board
#ARG MODEL=Llama-2-7b-chat-hf-q4f16_1
#ARG MODEL=Llama-2-13b-chat-hf-q4f16_1

# --------------------------------------------------------------------------- #

FROM scratch AS git-libmali
ADD https://github.com/JeffyCN/mirrors.git#libmali /

# --------------------------------------------------------------------------- #

FROM scratch AS git-mlc-llm
ADD https://github.com/mlc-ai/mlc-llm.git /

# --------------------------------------------------------------------------- #

FROM scratch as libmali-driver
COPY --link --from=git-libmali /lib/aarch64-linux-gnu/libmali-valhall-g610-*.so /

# --------------------------------------------------------------------------- #

FROM scratch AS libmali-firmware
COPY --link --from=git-libmali /firmware/g610/mali_csffw.bin /

# --------------------------------------------------------------------------- #

FROM alpine AS fetch
RUN apk add --no-cache \
    git \
    git-lfs \
    ;

FROM scratch AS git-binary-mlc-llm-libs
ADD https://github.com/mlc-ai/binary-mlc-llm-libs.git /

# --------------------------------------------------------------------------- #

FROM scratch AS binary-mlc-llm-lib
ARG MODEL
COPY --link --from=git-binary-mlc-llm-libs /${MODEL}-mali.so /

# --------------------------------------------------------------------------- #

FROM fetch AS fetch-model
ARG MODEL
ARG GIT_URL="https://huggingface.co/mlc-ai/mlc-chat-${MODEL}.git"
RUN --mount=type=cache,sharing=locked,id=git-${MODEL},target=/cache/${MODEL} \
    git clone \
      --single-branch --depth 1 \
      --separate-git-dir=/cache/${MODEL}/git \
      ${GIT_URL} \
      /out/${MODEL} \
    ;

# --------------------------------------------------------------------------- #

FROM scratch AS model
COPY --link --from=fetch-model /out/ /

# --------------------------------------------------------------------------- #

FROM debian:bullseye AS opencl

# based on https://mlc.ai/mlc-llm/docs/install/gpu.html#orange-pi-5-rk3588-based-sbc
RUN --mount=type=cache,sharing=locked,id=apt-opencl,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=apt-opencl-cache,target=/var/cache/apt \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        mesa-opencl-icd \
        ocl-icd-opencl-dev \
        libxcb-dri2-0 \
        libxcb-dri3-0 \
        libwayland-client0 \
        libwayland-server0 \
        libx11-xcb1 \
        clinfo \
    ;

RUN mkdir -p /etc/OpenCL/vendors \
    && echo "/usr/lib/libmali-valhall-g610-g6p0-x11-wayland-gbm.so" | tee /etc/OpenCL/vendors/mali.icd \
    ;

COPY --link --from=libmali-firmware / /lib/firmware/
COPY --link --from=libmali-driver / /usr/lib/
RUN ldconfig

CMD ["clinfo"]

# --------------------------------------------------------------------------- #

FROM debian:bullseye-backports AS build
LABEL authors="Milas Bowman <devnull@milas.dev>"

RUN --mount=type=cache,sharing=locked,id=apt-mlc-llm,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=apt-mlc-llm-cache,target=/var/cache/apt \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -t bullseye-backports install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        python3 \
    ;

# install rust
ENV PATH="/root/.cargo/bin:${PATH}"
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y

COPY --link --from=git-mlc-llm / /mlc-llm
COPY config.cmake /mlc-llm/build/

# based on https://blog.mlc.ai/2023/08/09/GPU-Accelerated-LLM-on-Orange-Pi
RUN cd /mlc-llm/build \
    && cmake .. \
    && cmake --build . --parallel $(nproc) \
    && cmake --install . --prefix /out \
    ;

# --------------------------------------------------------------------------- #

FROM opencl

COPY --link --from=binary-mlc-llm-lib / /mlc-llm/dist/prebuilt/lib/
COPY --link --from=model / /mlc-llm/dist/prebuilt/
COPY --link --from=build /out/bin/ /out/lib/ /mlc-llm/build/

ENV LD_LIBRARY_PATH=/mlc-llm/build/
WORKDIR /mlc-llm

# HACK: can't interpolate ARGs in CMD, so assign it to an ENV and wrap with
# shell to resolve on start
ARG MODEL
ENV MODEL=${MODEL}
CMD ["sh", "-c", "./build/mlc_chat_cli --local-id ${MODEL} --device mali"]
