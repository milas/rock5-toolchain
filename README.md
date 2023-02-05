# Rock 5B Build Scripts
This is a Dockerized build environment for Rock 5B vendor kernel & related (e.g. U-Boot) components.

## Prerequisites
* Docker w/ buildx plugin
* AMD64 host

## Quick Start
Run `docker buildx bake` from the repo root to build the Kernel, U-Boot, and EDK2.

Artifacts will be output to `out/` in the repo root:
```
out
├── edk2
│   ├── RK3588_NOR_FLASH.img
│   └── ROCK_5B_SDK_UEFI.img
├── kernel
│   ├── dtb
│   │   └── rockchip
│   │       ├── overlay
│   │       ├── rk3588-rock-5b.dtb
│   │       └── rk3588-rock-5b-v11.dtb
│   ├── lib
│   │   └── modules
│   │       └── 5.10.110-gb62cf4be15ea
│   └── vmlinuz
└── u-boot
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
│       └── rk3588-rock-5b.dtb
└── vmlinuz
```

### Custom `defconfig`
To use a custom config, create a subdirectory (within this repo) that contains your `rockchip_linux_defconfig`:
```
defconfig
└── rockchip_linux_defconfig
```
Then, set the `DEFCONFIG` environment variable to the directory path and build:
```shell
DEFCONFIG="./defconfig/" docker buildx bake kernel
```

## U-Boot
**Upstream**: https://github.com/radxa/u-boot/tree/stable-5.10-rock5
```shell
docker buildx bake u-boot
```
```
out/u-boot
├── idbloader.img
├── rk3588_spl_loader_v1.08.111.bin
├── spi
│   └── spi_image.img
└── u-boot.itb
```

### Flashing
> 💁 Put the device into maskrom mode before proceeding!

> 🐳 Replace `sudo rkdeveloptool` with `./rkdeveloptool-docker.sh` to run via container

First, run the bootloader to initialize the device for flashing:
```shell
sudo rkdeveloptool db ./out/u-boot/rk3588_spl_loader_v1.08.111.bin
```

#### Use SPI Image
```shell
sudo rkdeveloptool wl 0x0 ./out/u-boot/spi/spi_image.img
```

#### Use Individual
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

There's a Dockerized build for `rkdeveloptool`, which can be run as a **privileged** container with `/dev/usb` bind-mounted from the host.

A helper script, `rkdeveloptool-docker.sh`, is provided.

Build Docker image:
```shell
docker buildx bake --load rkdeveloptool
```
Run:
```shell
./rkdeveloptool-docker.sh ld

DevNo=1 Vid=0x2207,Pid=0x350b,LocationID=704    Maskrom
```
The `out/` directory will be bind-mounted to `/out`.

If you're in the repo root directory, this means you can use relative paths:
```shell
# build u-boot to get the SPL bootloader
docker buildx bake u-boot

# initialize the bootloader on the device in maskrom mode
./rkdeveloptool-docker.sh db ./out/u-boot/rk3588_spl_loader_v1.08.111.bin
```

## Troubleshooting
### `rkdeveloptool` Error: `Creating Comm Object failed!`
Disable USB auto-suspend (run this on your host machine, not via Docker):
```shell
sudo sh -c 'echo -1 > /sys/module/usbcore/parameters/autosuspend'
```
NOTE: This won't be preserved across reboots.
