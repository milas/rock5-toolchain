# Rock 5 Toolchain
Dockerized build system for Linux kernel & related (e.g. U-Boot) components for the Radxa Rock 5 series of devices

## Prerequisites
* Docker w/ buildx plugin
  * If `docker buildx inspect` works, you're all set!
* `amd64` or `arm64` host
  * `amd64` uses `gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu` as provided by Radxa for cross-compilation (no configuration needed)

## Quick Start
Run `docker buildx bake` from the repo root to build the Kernel and stable U-Boot.

Individual groups and targets also exist if you don't want to build everything or want to use one of the experimental targets.

Artifacts will be output to `out/` in the repo root:
```
out
├── edk2
│   └── RK3588_NOR_FLASH.img
├── kernel
│   ├── dtb
│   │   └── rockchip
│   │       ├── overlay
│   │       ├── rk3588-rock-5b.dtb
│   │       └── rk3588-rock-5b-v11.dtb
│   ├── lib
│   │   └── modules
│   │       └── 5.10.110-gd0b0fd354269
│   └── vmlinuz
└── u-boot
    ├── collabora
    │   ├── idbloader.img
    │   ├── rk3588_spl_loader_v1.08.111.bin
    │   ├── spi
    │   │   └── spi_image.img
    │   └── u-boot.itb
    └── radxa
        ├── idbloader.img
        ├── rk3588_spl_loader_v1.08.111.bin
        ├── spi
        │   └── spi_image.img
        └── u-boot.itb
```

## Kernel
**Upstream**: https://github.com/radxa/kernel/tree/linux-5.10-gen-rkr3.4

```shell
docker buildx bake kernel
```
```
out/kernel
├── dtb
│   └── rockchip
│       ├── overlay
│       ├── rk3588-rock-5b.dtb
│       └── rk3588-rock-5b-v11.dtb
├── lib
│   └── modules
│       └── 5.10.110-gd0b0fd354269
└── vmlinuz

# note: tree listing limited to three levels
```

### Custom Kernel Config (`defconfig`)
You can generate a custom kernel config with the `defconfig.sh` script in this repo:
```shell
./defconfig.sh
```

This builds an image with the kernel sources and then runs `make menuconfig` in a container.
Afterwards, the resulting configuration is copied to the current working directory as `rockchip_linux_defconfig`.

Then, set the `DEFCONFIG` environment variable to the current directory:
```shell
DEFCONFIG='.' docker buildx bake kernel
```
This adds your current directory as an extra context for the build.
The build will then copy & use `rockchip_linux_config` from your current directory to be used instead of the default Radxa config.

## U-Boot
The buildx `u-boot` group will build both the stable U-Boot from Radxa as well as the experimental build from Collabora's mainline fork.

Once the Collabora patches have been merged into upstream U-Boot, a target will be added to build directly from that and building from Collabora's fork will eventually be deprecated.

### Radxa (Stable)
**Upstream**: https://github.com/radxa/u-boot/tree/stable-5.10-rock5
```shell
docker buildx bake u-boot-radxa
```
```
out/u-boot
└── radxa
    ├── idbloader.img
    ├── rk3588_spl_loader_v1.08.111.bin
    ├── spi
    │   └── spi_image.img
    └── u-boot.itb
```

### Collabora (Experimental)
**Upstream**: https://gitlab.collabora.com/hardware-enablement/rockchip-3588/u-boot/-/tree/2023.04-rc2-rock5b

Collabora is working on upstreaming RK3588 support into mainline U-Boot.
The first set of patches have been submitted as of February 2023.
See details at [RK3588 Mainline U-Boot Instructions](https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/upstream_uboot.md).

```shell
docker buildx bake u-boot-collabora
```
```
out/u-boot
└── collabora
    ├── idbloader.img
    ├── rk3588_spl_loader_v1.08.111.bin
    ├── spi
    │   └── spi_image.img
    └── u-boot.itb
```

### Flashing
> 💁 Put the device into [maskrom mode](https://wiki.radxa.com/Rock5/install/spi#Advanced_.28external.29_method) before proceeding!

> 🐳 Replace `sudo rkdeveloptool` with `./rkdeveloptool-docker.sh` to run via container (more details in the [`rkdeveloptool` (via Docker)](#rkdeveloptool-via-docker) section)

First, run the bootloader to initialize the device for flashing:
```shell
sudo rkdeveloptool db ./out/rk3588_spl_loader_v1.08.111.bin
```

#### Option 1: Convenience SPI Image
The `spi_image.img` includes the pre-loader and U-Boot at the right offsets and is sized for the SPI chip.
```shell
docker buildx bake spl
sudo rkdeveloptool wl 0x0 ./out/u-boot/radxa/spi/spi_image.img
```

#### Option 2: Individual Components
Alternatively, you can write the individual components at their offsets.

This is helpful for non-SPI (e.g. eMMC) to avoid destroying the GPT partition table.

1. Flash pre-loader:
   ```shell
   sudo rkdeveloptool wl 0x40 ./out/u-boot/idbloader.img
   ```
2. Flash U-Boot:
   ```shell
   sudo rkdeveloptool wl 0x4000 ./out/u-boot/u-boot.itb
   ```

## EDK2
**Upstream**: https://github.com/edk2-porting/edk2-rk35xx
```shell
docker buildx bake edk2
```
```
out/edk2
└── RK3588_NOR_FLASH.img
```

## `rkdeveloptool` (via Docker)
**Upstream**: https://github.com/rockchip-linux/rkdeveloptool

This is a Dockerized build for `rkdeveloptool`, which can be run as a **privileged** container with `/dev/usb` bind-mounted from the host.

A helper script, `rkdeveloptool-docker.sh`, is provided:
```shell
./rkdeveloptool-docker.sh ld
```
```
DevNo=1 Vid=0x2207,Pid=0x350b,LocationID=704    Maskrom
```
The `out/` directory will be bind-mounted to `/out`.

If you're in the repo root directory, this means you can use relative paths:
```shell
# get the latest spl loader from radxa repos 
docker buildx bake spl

# initialize the bootloader on the device in maskrom mode
./rkdeveloptool-docker.sh db ./out/rk3588_spl_loader_v1.08.111.bin
```

## Troubleshooting
### `rkdeveloptool` Error: `Creating Comm Object failed!`
Disable USB auto-suspend (run this on your host machine, not via Docker):
```shell
sudo sh -c 'echo -1 > /sys/module/usbcore/parameters/autosuspend'
```
NOTE: This won't be preserved across reboots.
