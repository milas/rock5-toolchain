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
  DEFCONFIG="$(pwd)"
  export DEFCONFIG
fi

docker rm -f rock5-kernel-config >/dev/null 2>&1 || true

# shellcheck disable=SC2086
(cd "$(dirname "${self}")" && docker buildx bake \
  --pull \
  --load \
  kernel-config)

docker run -it \
  --name rock5-kernel-config \
  -w /rk3588-sdk/kernel \
  milas/rock5-toolchain:kernel-config \
  sh -c 'make menuconfig && make savedefconfig'

docker cp rock5-kernel-config:/rk3588-sdk/kernel/defconfig rockchip_linux_defconfig

docker rm -f rock5-kernel-config >/dev/null 2>&1 || true
