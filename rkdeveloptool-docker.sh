#!/usr/bin/env sh

set -e

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! docker image inspect ghcr.io/milas/rkdeveloptool >/dev/null 2>&1 ; then
  2>&1 echo "Building rkdeveloptool..."
  pushd "${dir}" >/dev/null
  docker buildx bake --load rkdeveloptool >/dev/null
  popd >/dev/null
fi

docker run \
  --rm \
  -it \
  --init \
  --privileged \
  --mount=type=bind,src=/dev/usb,dst=/dev/usb \
  --mount="type=bind,src=${dir}/out,dst=/out" \
  ghcr.io/milas/rkdeveloptool "$@"
