#!/usr/bin/env sh
set -e

# run kernel menuconfig in container, using `rockchip_linux_defconfig` from the
# current working directory as a starting point if present (stock radxa config
# otherwise)
#
# output will overwrite `rockchip_linux_defconfig` in current working directory

self=$(
    self=${0}
    while [ -L "${self}" ]
    do
        cd "${self%/*}"
        self=$(readlink "${self}")
    done
    cd "${self%/*}"
    echo "$(pwd -P)/${self##*/}"
)

DEFCONFIG_CTX=
if [ -f rockchip_linux_defconfig ]; then
  >&2 echo "This will overwrite rockchip_linux_defconfig in $(pwd)"
  while true; do
    read -p "Continue (y/N)? " choice
    case "$choice" in
      y|Y ) break;;
      n|N|'' ) exit 1;;
      * ) ;;
    esac
  done
  DEFCONFIG_CTX="--build-context=defconfig=."
fi

docker rm -f rock5-kernel-config >/dev/null 2>&1 || true

docker buildx build \
  --pull \
  --target=kernel-build-config \
  --tag milas/rock5-toolchain:kernel-config \
  "${DEFCONFIG_CTX}" \
  --load \
  - < "$(dirname "${self}")"/Dockerfile

docker run -it \
  --name rock5-kernel-config \
  -w /rk3588-sdk/kernel \
  milas/rock5-toolchain:kernel-config \
  sh -c 'make menuconfig && make savedefconfig'

docker cp rock5-kernel-config:/rk3588-sdk/kernel/defconfig rockchip_linux_defconfig

docker rm -f rock5-kernel-config >/dev/null 2>&1 || true
