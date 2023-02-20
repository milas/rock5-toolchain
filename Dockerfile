# syntax=docker/dockerfile:1-labs

#### GIT TARGETS ####
FROM scratch AS git-kernel

ADD --keep-git-dir=true https://github.com/radxa/kernel.git#linux-5.10-gen-rkr3.4 /

# --------------------------------------------------------------------------- #

FROM scratch AS git-u-boot-radxa

ADD https://github.com/radxa/u-boot.git#stable-5.10-rock5 /

# --------------------------------------------------------------------------- #

FROM scratch AS git-u-boot-collabora

ADD https://gitlab.collabora.com/hardware-enablement/rockchip-3588/u-boot.git#2023.04-rc2-rock5b /

# --------------------------------------------------------------------------- #

FROM scratch AS git-rkbin

ADD https://github.com/radxa/rkbin.git#master /

# --------------------------------------------------------------------------- #

FROM scratch AS git-radxa-build

ADD https://github.com/radxa/build.git#debian /

# --------------------------------------------------------------------------- #

FROM scratch AS git-edk2

ADD https://github.com/edk2-porting/edk2-rk35xx.git#master /

# --------------------------------------------------------------------------- #

FROM scratch AS git-rkdeveloptool

ADD https://github.com/rockchip-linux/rkdeveloptool.git#master /

# --------------------------------------------------------------------------- #

FROM scratch AS git-bsp

ADD https://github.com/radxa-repo/bsp.git#main /

# --------------------------------------------------------------------------- #

FROM scratch AS git-overlays

ADD https://github.com/radxa/overlays.git#main /

# --------------------------------------------------------------------------- #

FROM --platform=${BUILDPLATFORM} alpine AS fetch
RUN apk add --no-cache \
    curl \
    git \
    ;

# --------------------------------------------------------------------------- #

FROM fetch AS dl-cross-compiler
WORKDIR /cross-compile
RUN curl -sS https://dl.radxa.com/tools/linux/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.gz | tar -xz --strip-components=4

# --------------------------------------------------------------------------- #

FROM --platform=${BUILDPLATFORM} debian:bullseye AS sdk-deps

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

RUN ln -s /usr/bin/ccache /usr/local/bin/gcc \
    && ln -s /usr/bin/ccache /usr/local/bin/g++ \
    ;
ENV CCACHE_DIR=/rk3588-sdk/ccache/cache
ENV ARCH=arm64

WORKDIR /rk3588-sdk

# --------------------------------------------------------------------------- #

FROM sdk-deps AS sdk-base-amd64

COPY --from=dl-cross-compiler --link /cross-compile /rk3588-sdk/cross-compile

RUN mkdir -p /rk3588-sdk/ccache/bin \
    && ln -s /usr/bin/ccache /rk3588-sdk/ccache/bin/aarch64-none-linux-gnu-gcc \
    && ln -s /usr/bin/ccache /rk3588-sdk/ccache/bin/aarch64-none-linux-gnu-g++ \
    ;

# ccache shims first, then real cross-compiler
ENV PATH="/rk3588-sdk/ccache/bin:/rk3588-sdk/cross-compile/bin:${PATH}"
ENV CROSS_COMPILE=aarch64-none-linux-gnu-

# --------------------------------------------------------------------------- #

FROM sdk-deps AS sdk-base-arm64
# no extra configuration required

# --------------------------------------------------------------------------- #

FROM sdk-base-${BUILDARCH} AS sdk-base

# --------------------------------------------------------------------------- #

FROM sdk-base AS sdk

COPY --from=git-rkbin --link / /rk3588-sdk/rkbin

# --------------------------------------------------------------------------- #

FROM sdk-base AS bsp

COPY --from=git-bsp --link / /rk3588-sdk/bsp

# --------------------------------------------------------------------------- #

FROM scratch AS kernel-radxa-patches

COPY --from=git-bsp --link /linux/rockchip /

# --------------------------------------------------------------------------- #

# this is a circuitous no-op intended to be overridden via a var passed to
# docker buildx bake (or alternatively, CLI flags to `buildx build`)
FROM scratch AS defconfig

COPY --from=git-kernel --link /arch/arm64/configs/rockchip_linux_defconfig /

# --------------------------------------------------------------------------- #

FROM sdk AS kernel-builder

COPY --from=git-kernel --link / /rk3588-sdk/kernel/

RUN rm -rf /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlay
COPY --from=git-overlays --link /arch/arm64/boot/dts/amlogic/overlays /rk3588-sdk/kernel/arch/arm64/boot/dts/amlogic/overlays
COPY --from=git-overlays --link /arch/arm64/boot/dts/rockchip/overlays /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlays
COPY --from=kernel-radxa-patches --link / /rk3588-sdk/kernel/patches

COPY --from=defconfig --link /rockchip_linux_defconfig /rk3588-sdk/kernel/arch/arm64/configs/rockchip_linux_defconfig

RUN cd /rk3588-sdk/kernel \
    && git config --global user.email "rock5-docker@milas.dev" \
    && git config --global user.name "Rock 5 Docker Build User" \
    && find /rk3588-sdk/kernel/patches \
        -name '*.patch' \
        -not -iname "*-rock-4*" \
        -type f \
        -print0 \
      | sort -z \
      | xargs -r0 git am --reject --whitespace=fix \
    ;

# --------------------------------------------------------------------------- #

FROM kernel-builder AS kernel-build-config
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    cd /rk3588-sdk/kernel \
    && make rockchip_linux_defconfig \
    ;

# --------------------------------------------------------------------------- #

FROM kernel-build-config AS kernel-build

RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    cd /rk3588-sdk/kernel \
    && make -j $(nproc) \
    ;

RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache ccache --show-stats > /rk3588-sdk/ccache/ccache-kernel-core.log

# --------------------------------------------------------------------------- #

FROM kernel-build AS kernel-build-modules

ENV INSTALL_MOD_PATH=/rk3588-sdk/out/kernel/modules
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    mkdir -p /out \
    && cd /rk3588-sdk/kernel \
    && make modules_install INSTALL_MOD_PATH=/out \
    && rm /out/lib/modules/*/build \
    && rm /out/lib/modules/*/source \
    ;

RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache ccache --show-stats > /rk3588-sdk/ccache/ccache-kernel-modules.log

# --------------------------------------------------------------------------- #

FROM scratch AS kernel-modules

COPY --from=kernel-build-modules --link /out /

# --------------------------------------------------------------------------- #

FROM kernel-build AS kernel-build-firmware

RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    cd /rk3588-sdk/kernel \
    && make firmware \
    ;

RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache ccache --show-stats > /rk3588-sdk/out/ccache-kernel-firmware.log

# --------------------------------------------------------------------------- #

FROM scratch AS kernel

COPY --from=kernel-build --link /rk3588-sdk/kernel/arch/arm64/boot/Image /vmlinuz

COPY --from=kernel-build --link /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/rk3588-rock-5*.dtb /dtb/rockchip/
COPY --from=kernel-build --link /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlays/rock-5*.dtbo /dtb/rockchip/overlay/
COPY --from=kernel-build --link /rk3588-sdk/kernel/arch/arm64/boot/dts/rockchip/overlays/rk3588*.dtbo /dtb/rockchip/overlay/
COPY --from=kernel-modules --link / /

# --------------------------------------------------------------------------- #

FROM scratch as rkbin-spl

COPY --from=git-rkbin --link /bin/rk35/rk3588_spl_loader_v1.08.111.bin /

# --------------------------------------------------------------------------- #

FROM sdk AS u-boot-radxa-builder

COPY --from=git-radxa-build --link / /rk3588-sdk/build
COPY --from=git-u-boot-radxa --link / /rk3588-sdk/u-boot

# --------------------------------------------------------------------------- #

FROM u-boot-radxa-builder AS u-boot-radxa-build

ARG CHIP="rk3588"
ARG BOARD="rock-5b"
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    ./build/mk-uboot.sh "${CHIP}-${BOARD}" \
    ;

# --------------------------------------------------------------------------- #

FROM scratch AS u-boot-radxa

COPY --from=u-boot-radxa-build --link /rk3588-sdk/out/u-boot/ /

# --------------------------------------------------------------------------- #

FROM sdk-base as u-boot-collabora-builder

RUN apt-get update \
    && apt-get install -y \
    python3 \
    python3-dev \
    python3-pyelftools \
    python3-setuptools \
    swig \
    ;

COPY --from=git-rkbin --link /bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin /rk3588-sdk/u-boot/rockchip-tpl
COPY --from=git-rkbin --link /bin/rk35/rk3588_bl31_v1.34.elf /rk3588-sdk/u-boot/atf-bl31
COPY --from=git-u-boot-collabora --link / /rk3588-sdk/u-boot

WORKDIR /rk3588-sdk/u-boot

# --------------------------------------------------------------------------- #

FROM u-boot-collabora-builder AS u-boot-collabora-build

ARG CHIP="rk3588"
ARG BOARD="rock-5b"
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    cd /rk3588-sdk/u-boot \
    && make "${BOARD}-${CHIP}_defconfig" \
    && make \
    ;

# adapted from https://github.com/radxa/build/blob/223bcb503769e862a05ebe08c2d49348c050e732/mk-uboot.sh#L29-L41
RUN <<EOF
    SPI_IMAGE="/rk3588-sdk/u-boot/spi_image.img"
  	dd if=/dev/zero of=$SPI_IMAGE bs=1M count=0 seek=16
  	parted -s $SPI_IMAGE mklabel gpt
  	parted -s $SPI_IMAGE unit s mkpart idbloader 64 7167
  	parted -s $SPI_IMAGE unit s mkpart vnvm 7168 7679
  	parted -s $SPI_IMAGE unit s mkpart reserved_space 7680 8063
  	parted -s $SPI_IMAGE unit s mkpart reserved1 8064 8127
  	parted -s $SPI_IMAGE unit s mkpart uboot_env 8128 8191
  	parted -s $SPI_IMAGE unit s mkpart reserved2 8192 16383
  	parted -s $SPI_IMAGE unit s mkpart uboot 16384 32734
  	dd if=/rk3588-sdk/u-boot/idbloader.img of=$SPI_IMAGE seek=64 conv=notrunc
  	dd if=/rk3588-sdk/u-boot/u-boot.itb of=$SPI_IMAGE seek=16384 conv=notrunc
EOF

# --------------------------------------------------------------------------- #

FROM scratch AS u-boot-collabora

COPY --from=rkbin-spl --link / /
COPY --from=u-boot-collabora-build --link /rk3588-sdk/u-boot/idbloader.img /
COPY --from=u-boot-collabora-build --link /rk3588-sdk/u-boot/u-boot.itb /
COPY --from=u-boot-collabora-build --link /rk3588-sdk/u-boot/spi_image.img /spi/spi_image.img

# --------------------------------------------------------------------------- #

FROM u-boot-radxa-builder AS u-boot-radxa-tools-build

ARG CHIP="rk3588"
ARG BOARD="rock-5b"
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    cd /rk3588-sdk/u-boot \
    && make "${BOARD}-${CHIP}_defconfig" \
    && make tools \
    ;

# --------------------------------------------------------------------------- #

FROM scratch AS u-boot-radxa-tools

COPY --from=u-boot-radxa-tools-build --link /rk3588-sdk/u-boot/tools/boot_merger /
COPY --from=u-boot-radxa-tools-build --link /rk3588-sdk/u-boot/tools/loaderimage /
COPY --from=u-boot-radxa-tools-build --link /rk3588-sdk/u-boot/tools/mkimage /

# --------------------------------------------------------------------------- #

FROM sdk-base AS edk2-deps

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

# --------------------------------------------------------------------------- #

FROM edk2-deps AS edk2-builder-base

COPY --from=git-edk2 --link / /rk3588-sdk/edk2-rk35xx

# --------------------------------------------------------------------------- #

FROM edk2-builder-base AS edk2-builder-arm64

# the vendored rkbin tools are all precompiled for x86, so need to grab them
# from a u-boot build on arm64
# see https://forum.radxa.com/t/edk2-uefi-firmware/14050/2
ENV IDBLOCK_BUILDTOOL=mkimage
COPY --from=u-boot-radxa-tools --link / /rk3588-sdk/edk2-rk35xx/misc/rkbin/tools/

FROM edk2-builder-base AS edk2-builder-amd64

# --------------------------------------------------------------------------- #

FROM edk2-builder-${BUILDARCH} AS edk2-build

ARG BOARD="rock-5b"
RUN --mount=type=cache,dst=/rk3588-sdk/ccache/cache \
    /rk3588-sdk/edk2-rk35xx/build.sh -d "${BOARD}"

# --------------------------------------------------------------------------- #

FROM scratch AS edk2

COPY --from=edk2-build --link /rk3588-sdk/edk2-rk35xx/RK3588_NOR_FLASH.img /

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

# --------------------------------------------------------------------------- #

FROM debian:bullseye AS rkdeveloptool

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libusb-1.0.0 \
    ;

COPY --from=rkdeveloptool-build --link /rk3588-sdk/rkdeveloptool/rkdeveloptool /usr/local/bin/

VOLUME "/out"

ENTRYPOINT ["/usr/local/bin/rkdeveloptool"]

# --------------------------------------------------------------------------- #
