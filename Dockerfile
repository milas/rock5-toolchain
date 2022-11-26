# syntax=docker/dockerfile:1
FROM alpine AS fetch
WORKDIR /code
RUN apk add --no-cache \
    curl \
    git \
    ;

FROM fetch AS git-kernel
RUN git clone --branch=linux-5.10-gen-rkr3.4 --single-branch --depth=1 https://github.com/radxa/kernel.git

FROM fetch AS git-u-boot
RUN git clone --branch=stable-5.10-rock5 --single-branch --depth=1 https://github.com/radxa/u-boot.git

FROM fetch AS git-rkbin
RUN git clone --branch=master --single-branch --depth=1 https://github.com/radxa/rkbin.git

FROM fetch AS git-radxa-build
RUN git clone --branch=debian --single-branch --depth=1 https://github.com/radxa/build.git

FROM fetch AS dl-toolchain
RUN curl -q https://dl.radxa.com/tools/linux/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.gz | tar zxv --strip-components 4

FROM fetch AS git-edk2
RUN git clone --branch=master --single-branch --depth=1 https://github.com/edk2-porting/edk2-rk35xx

FROM fetch as git-rkdeveloptool
RUN git clone --branch=master --single-branch --depth=1 https://github.com/rockchip-linux/rkdeveloptool
RUN cd /code/rkdeveloptool \
    && curl -qL https://github.com/rockchip-linux/rkdeveloptool/pull/57.patch | git apply

# --------------------------------------------------------------------------- #

FROM debian:bullseye AS sdk-base

RUN apt-get update && \
    apt-get install -y \
        device-tree-compiler \
        libncurses5 \
        libncurses5-dev \
        build-essential \
        libssl-dev \
        mtools \
        bc \
        python \
        dosfstools \
        bison \
        flex \
        rsync \
        u-boot-tools \
    ;

WORKDIR /rk3588-sdk

# --------------------------------------------------------------------------- #

FROM sdk-base AS sdk

COPY --from=git-radxa-build --link /code/build /rk3588-sdk/build
COPY --from=git-rkbin --link /code/rkbin /rk3588-sdk/rkbin
COPY --from=dl-toolchain --link /code /rk3588-sdk/toolchain

ENV PATH="/rk3588-sdk/toolchain/bin:${PATH}"

# --------------------------------------------------------------------------- #

FROM sdk AS kernel-build

COPY --from=git-kernel --link /code/kernel /rk3588-sdk/kernel
RUN ./build/mk-kernel.sh rk3588-rock-5b

FROM --platform=linux/arm64 scratch AS kernel

COPY --from=kernel-build --link /rk3588-sdk/out/kernel/rk3588-rock-5b.dtb /dtb/rockchip/
COPY --from=kernel-build --link /rk3588-sdk/out/kernel/Image /vmlinuz

# --------------------------------------------------------------------------- #

FROM sdk as u-boot-build

COPY --from=git-u-boot --link /code/u-boot /rk3588-sdk/u-boot

RUN ./build/mk-uboot.sh rk3588-rock-5b

FROM --platform=linux/arm64 scratch AS u-boot

COPY --from=u-boot-build --link /rk3588-sdk/out/u-boot/ /

# --------------------------------------------------------------------------- #

FROM sdk-base AS edk2-build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        binutils-aarch64-linux-gnu \
        device-tree-compiler \
        gcc-aarch64-linux-gnu \
        git \
        iasl \
        libc-dev-arm64-cross \
        python3-pyelftools \
        uuid-dev \
    ;

COPY --from=git-edk2 --link /code/edk2-rk35xx /rk3588-sdk/edk2-rk35xx

RUN /rk3588-sdk/edk2-rk35xx/build.sh -d rock-5b

FROM --platform=linux/arm64 scratch AS edk2

COPY --from=edk2-build --link /rk3588-sdk/edk2-rk35xx/RK3588_NOR_FLASH.img /

# --------------------------------------------------------------------------- #

FROM sdk-base AS rkdeveloptool-build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      dh-autoreconf \
      libudev-dev \
      libusb-1.0-0-dev \
      pkg-config \
    ;

COPY --from=git-rkdeveloptool --link /code/rkdeveloptool/ /rk3588-sdk/rkdeveloptool

RUN cd /rk3588-sdk/rkdeveloptool \
    && aclocal \
    && autoreconf -i \
    && autoheader \
    && automake --add-missing \
    && ./configure \
    && make \
    ;

FROM debian:bullseye AS rkdeveloptool

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libusb-1.0.0 \
    ;

COPY --from=rkdeveloptool-build --link /rk3588-sdk/rkdeveloptool/rkdeveloptool /usr/local/bin/

VOLUME "/out"

ENTRYPOINT ["/usr/local/bin/rkdeveloptool"]

# --------------------------------------------------------------------------- #
