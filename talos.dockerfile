#syntax=docker/dockerfile:1
FROM --platform=linux/arm64 ghcr.io/milas/rock5b-kernel AS kernel

#FROM ghcr.io/milas/rock5b-u-boot AS u-boot
#
## TODO(milas): figure this out
#COPY uboot-config /rk3588-sdk/u-boot/configs/rock-5b-rk3588_defconfig
#
## --------------------------------------------------------------------------- #
#
## Rockchip boot uses U-Boot as both SPL and the actual bootloader, so there's
## two things to flash:
##
## 1. Write zero'd 16MiB flash image
## 2. Write pre-loader (SPL) at offset 0x40
## 3. Write U-Boot at offset 0x4000
##
## See https://opensource.rock-chips.com/wiki_Boot_option
##
## Talos wants a single blob to write and we need it to start writing at the
## first offset vs 0x0 so that it doesn't trash our GPT header. We'll actually
## subtract that offset (0x40) as a base from everything here. Basically, we
## don't want to zero out the first 0x40 sectors (32 KiB), but for sanity, we
## use the standard Rockchip constants and let the shell do some light math.
##RUN dd if=/dev/zero of=/rk3588-sdk/out/u-boot/u-boot.img bs=512 count="$((32768-0x40))" status=none \
##    && dd if=/rk3588-sdk/out/u-boot/idbloader.img of=/rk3588-sdk/out/u-boot/u-boot.img bs=512 seek="$((0x40-0x40))" conv=notrunc \
##    && dd if=/rk3588-sdk/out/u-boot/u-boot.itb of=/rk3588-sdk/out/u-boot/u-boot.img bs=512 seek="$((0x4000-0x40))" conv=notrunc \
##    ;
#
#
#RUN dd if=/dev/zero of=/rk3588-sdk/out/u-boot/u-boot.img bs=512 count=32768 \
#    && dd if=/rk3588-sdk/out/u-boot/idbloader.img of=/rk3588-sdk/out/u-boot/u-boot.img bs=512 seek="$((0x40))" conv=notrunc \
#    && dd if=/rk3588-sdk/out/u-boot/u-boot.itb of=/rk3588-sdk/out/u-boot/u-boot.img bs=512 seek="$((0x4000))" conv=notrunc \
#    ;

FROM --platform=linux/arm64 scratch AS customization

# --------------------------------------------------------------------------- #
FROM --platform=linux/arm64 scratch AS rootfs

COPY --from=kernel --link /lib/modules /lib/modules
COPY /rootfs /

FROM alpine AS initramfs-build

#COPY initrd.img-5.10.110-31-rockchip-ged1406c748b1 /initrd.lz4
WORKDIR /out
RUN apk add --no-cache lz4
RUN --mount=type=bind,src=initrd.img-5.10.110-31-rockchip-ged1406c748b1,dst=/initrd.lz4,ro \
    unlz4 -k /initrd.lz4 /initrd \
    && cpio -iv </initrd \
    && rm -rf ./init \
    && rm -rf /initrd \
    ;

# --------------------------------------------------------------------------- #
FROM --platform=linux/arm64 scratch AS initramfs

#COPY --from=initramfs-build --link /out /
COPY /rootfs /

# --------------------------------------------------------------------------- #
# FROM ghcr.io/siderolabs/installer:latest AS talos-installer
FROM --platform=linux/arm64 ghcr.io/milas/installer:latest@sha256:82015b4fedf6ad9c98ef069d5e68709506f0a2607e7f97c5f9a7d28652b69360 AS talos-installer

LABEL org.opencontainers.image.source = "https://github.com/milas/talos"

RUN apk add --no-cache --update \
    cpio \
    squashfs-tools \
    xz
WORKDIR /initramfs
ARG RM
RUN xz -d /usr/install/${TARGETARCH}/initramfs.xz \
    && cpio -idvm < /usr/install/${TARGETARCH}/initramfs \
    && unsquashfs -f -d /rootfs rootfs.sqsh \
    && for f in ${RM}; do rm -rfv /rootfs$f; done \
    && rm /usr/install/${TARGETARCH}/initramfs \
    && rm rootfs.sqsh \
;

COPY --from=initramfs --link / .
COPY --from=rootfs --link / /rootfs

RUN find /rootfs \
    && echo 'Building rootfs & initramfs...' \
    && mksquashfs /rootfs rootfs.sqsh -all-root -noappend -comp xz -Xdict-size 100% -no-progress \
    && set -o pipefail && find . 2>/dev/null | cpio -H newc -o | xz -v -C crc32 -0 -e -T 0 -z >/usr/install/${TARGETARCH}/initramfs.xz \
    && rm -rf /rootfs \
    && rm -rf /initramfs
WORKDIR /

# COPY --from=u-boot --link /rk3588-sdk/out/u-boot/u-boot.img /usr/install/arm64/u-boot/rock_5b/
COPY rock-5b-spi-image-g3caf61a44c2-debug.img /usr/install/arm64/u-boot/rock_5b/u-boot.img

COPY --from=kernel --link /vmlinuz /usr/install/arm64/
COPY --from=kernel --link /dtb /usr/install/arm64/dtb

#COPY vmlinuz-5.10.110-31-rockchip-ged1406c748b1 /usr/install/arm64/vmlinuz
#COPY rk3588-rock-5b.dtb /usr/install/arm64/dtb/rockchip/

#COPY vmlinuz-5.10.66-28-rockchip-gc428536281d6 /usr/install/arm64/vmlinuz
#COPY rk3588-rock-5b.dtb /usr/install/arm64/dtb/rockchip/
COPY dtbs/rockchip/overlay/rk3588-uart7-m2.dtbo /usr/install/arm64/dtb/rockchip/

COPY extlinux.conf /usr/install/arm64/extlinux/extlinux.conf

#target "talos-installer" {
#  dockerfile = "talos.dockerfile"
#  tags = ["ghcr.io/milas/imager"]
#  target = "talos-installer"
#  platforms = ["linux/arm64"]
#  contexts = {
#    "milas/rock5b-docker-build" = "target:kernel"
#    "milas/rock5b-u-boot" = "target:u-boot"
#  }
#}
