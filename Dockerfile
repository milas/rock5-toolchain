# syntax=docker/dockerfile:1-labs

#### REPO TARGETS ####
FROM scratch AS git-kernel

ADD https://github.com/radxa/kernel.git#linux-5.10-gen-rkr3.4 /

FROM scratch AS git-u-boot

ADD https://github.com/radxa/u-boot.git#stable-5.10-rock5 /

FROM scratch AS git-rkbin

ADD https://github.com/radxa/rkbin.git#master /

FROM scratch AS git-radxa-build

ADD https://github.com/radxa/build.git#debian /

FROM scratch AS git-edk2

ADD https://github.com/edk2-porting/edk2-rk35xx.git#master /

FROM scratch AS git-rkdeveloptool

ADD https://github.com/rockchip-linux/rkdeveloptool.git#master /

FROM scratch AS git-bsp

ADD https://github.com/radxa-repo/bsp.git#main /

FROM scratch AS git-overlays

ADD https://github.com/radxa/overlays.git#main /

FROM alpine AS fetch
RUN apk add --no-cache \
    curl \
    git \
    ;

FROM fetch AS dl-toolchain
WORKDIR /toolchain
RUN curl -q https://dl.radxa.com/tools/linux/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.gz | tar zx --strip-components 4

# --------------------------------------------------------------------------- #

FROM debian:bullseye AS sdk-base

RUN apt-get update && \
    apt-get install -y \
        bc \
        bison \
        build-essential \
        device-tree-compiler \
        dosfstools \
        ccache \
        flex \
        git \
        kmod \
        libncurses5 \
        libncurses5-dev \
        libssl-dev \
        mtools \
        python \
        rsync \
        u-boot-tools \
    ;

WORKDIR /rk3588-sdk

# --------------------------------------------------------------------------- #

FROM sdk-base AS sdk

COPY --from=git-radxa-build --link / /rk3588-sdk/build
COPY --from=git-rkbin --link / /rk3588-sdk/rkbin
COPY --from=dl-toolchain --link /toolchain /rk3588-sdk/toolchain

ENV PATH="/rk3588-sdk/toolchain/bin:${PATH}"

# --------------------------------------------------------------------------- #

FROM sdk-base AS bsp

COPY --from=git-bsp --link / /rk3588-sdk/bsp

FROM scratch AS kernel-radxa-patches

COPY --from=git-bsp --link /linux/rockchip /

# --------------------------------------------------------------------------- #

# this is a circuitous no-op intended to be overridden via a var passed to
# docker buildx bake (or alternatively, CLI flags to `buildx build`)
FROM scratch AS defconfig

COPY --from=git-kernel --link /arch/arm64/configs/rockchip_linux_defconfig /

# --------------------------------------------------------------------------- #

FROM sdk AS kernel-builder-base

ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-none-linux-gnu-
ENV INSTALL_MOD_PATH=/rk3588-sdk/out/kernel/modules

RUN mkdir -p /rk3588-sdk/ccache/bin \
    && ln -s /usr/bin/ccache /rk3588-sdk/ccache/bin/aarch64-none-linux-gnu-gcc \
    && ln -s /usr/bin/ccache /rk3588-sdk/ccache/bin/aarch64-none-linux-gnu-g++ \
    ;
ENV PATH="/rk3588-sdk/ccache/bin:${PATH}"
ENV CCACHE_DIR=/rk3588-sdk/ccache/cache

RUN mkdir -p ${INSTALL_MOD_PATH}

COPY --from=git-kernel --link / /rk3588-sdk/kernel/

FROM kernel-builder-base AS kernel-builder

RUN rm -rf /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlay

COPY --from=git-overlays --link /arch/arm64/boot/dts/amlogic/overlays /rk3588-sdk/kernel/arch/arm64/boot/dts/amlogic/overlays
COPY --from=git-overlays --link /arch/arm64/boot/dts/rockchip/overlays /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlays

COPY --from=kernel-radxa-patches --link / /rk3588-sdk/kernel/patches
RUN cd /rk3588-sdk/kernel \
    && git config --global user.email "devnull@milas.dev" \
    && git config --global user.name "Docker Build" \
    && find /rk3588-sdk/kernel/patches \
        -name '*.patch' \
        -not -iname "*-rock-4*" \
        -type f \
        -print0 \
      | sort -z \
      | xargs -r0 git am --reject --whitespace=fix \
    ;

COPY --from=defconfig --link /rockchip_linux_defconfig /rk3588-sdk/kernel/arch/arm64/configs/rockchip_linux_defconfig

FROM kernel-builder AS kernel-build
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    ./build/mk-kernel.sh rk3588-rock-5b
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    cd /rk3588-sdk/kernel \
    && make modules modules_install \
    && rm ${INSTALL_MOD_PATH}/lib/modules/*/build \
    && rm ${INSTALL_MOD_PATH}/lib/modules/*/source \
    ;

FROM kernel-build AS firmware

RUN cd /rk3588-sdk/kernel && make firmware

FROM --platform=linux/arm64 scratch AS kernel

COPY --from=kernel-build --link /rk3588-sdk/out/kernel/Image /vmlinuz

COPY --from=kernel-build --link /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/rk3588-rock-5*.dtb /dtb/rockchip/
COPY --from=kernel-build --link /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlays/rock-5*.dtbo /dtb/rockchip/overlay/
COPY --from=kernel-build --link /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlays/rk3588*.dtbo /dtb/rockchip/overlay/
COPY --from=kernel-build --link /rk3588-sdk/out/kernel/modules /

# --------------------------------------------------------------------------- #

FROM sdk AS u-boot-builder

COPY --from=git-u-boot --link / /rk3588-sdk/u-boot

FROM u-boot-builder AS u-boot-build

RUN ./build/mk-uboot.sh rk3588-rock-5b

FROM --platform=linux/arm64 scratch AS u-boot

COPY --from=u-boot-build --link /rk3588-sdk/out/u-boot/ /

# --------------------------------------------------------------------------- #

FROM sdk AS edk2-builder

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

COPY --from=git-edk2 --link / /rk3588-sdk/edk2-rk35xx

FROM edk2-builder AS edk2-build

RUN /rk3588-sdk/edk2-rk35xx/build.sh -d rock-5b

RUN ./rkbin/tools/loaderimage --pack --uboot ./workspace/Build/ROCK5B/DEBUG_GCC5/FV/NOR_FLASH_IMAGE.fd ./workspace/ROCK_5B_SDK_UEFI.img || true

FROM --platform=linux/arm64 scratch AS edk2

COPY --from=edk2-build --link /rk3588-sdk/edk2-rk35xx/RK3588_NOR_FLASH.img /
COPY --from=edk2-build --link /rk3588-sdk/workspace/ROCK_5B_SDK_UEFI.img /

# --------------------------------------------------------------------------- #

FROM sdk-base AS rkdeveloptool-build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      dh-autoreconf \
      git \
      libudev-dev \
      libusb-1.0-0-dev \
      pkg-config \
    ;

COPY --from=git-rkdeveloptool --link / /rk3588-sdk/rkdeveloptool

RUN cd /rk3588-sdk/rkdeveloptool \
    && curl -qL https://github.com/rockchip-linux/rkdeveloptool/pull/57.patch | git apply \
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
