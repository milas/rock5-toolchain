#!/usr/bin/env sh

set -e

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

docker run \
  --rm \
  -it \
  --init \
  --privileged \
  --mount=type=bind,src=/dev/usb/,dst=/dev/usb/ \
  --mount="type=bind,src=${dir}/out,dst=/out" \
  ghcr.io/milas/rkdeveloptool "$@"
