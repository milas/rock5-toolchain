#!/usr/bin/env sh

set -e

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

# the substitution uses :+ to ensure that no empty quoted value is present
# if no mount flags are being passed, or the run command will interpret the
# empty literal as the image name
mnt_args=
if [ -d /dev/usb ]; then
  mnt_args="${mnt_args} --mount=type=bind,src=/dev/usb/,dst=/dev/usb/"
fi

out_dir=$(dirname "${self}")/out
if [ -d "${out_dir}" ]; then
  mnt_args="${mnt_args} --mount=type=bind,src=$(dirname "${self}")/out,dst=/out"
fi

docker --context=default run \
  --rm \
  -it \
  --init \
  --privileged \
  ${mnt_args:+${mnt_args}} \
  ghcr.io/milas/rkdeveloptool "$@"
