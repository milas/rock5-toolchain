variable DEBUG {
  default = false
}

variable DEFCONFIG {
  default = null
}

variable CHIP {
  default = null
}

variable BOARD {
  default = null
}

group default {
  targets = ["kernel", "u-boot"]
}

group u-boot {
  targets = ["u-boot-radxa", "u-boot-collabora"]
}

# virtual target for CI
# https://github.com/docker/metadata-action#bake-definition
target "docker-metadata-action" {}

target sdk {
  target   = "sdk"
  inherits = ["docker-metadata-action"]
  tags     = ["docker.io/milas/rock5-sdk"]
}

target rkdeveloptool {
  target   = "rkdeveloptool"
  inherits = ["docker-metadata-action"]
  tags     = ["docker.io/milas/rkdeveloptool"]
}


variable KERNEL_REPO {
  default = null
}

variable KERNEL_REF {
  default = null
}

target kernel {
  target  = "kernel"
  output  = ["type=local,dest=./out/kernel"]
  inherits = ["kernel-config"]
}

target kernel-config {
  target   = "kernel-build-config"
  inherits = ["docker-metadata-action"]
  tags     = ["milas/rock5-toolchain:kernel-config"]
  contexts = notequal(null, DEFCONFIG) ? { defconfig = DEFCONFIG } : {}
  args     = {
    KERNEL_REPO = KERNEL_REPO
    KERNEL_REF  = KERNEL_REF
  }
}

target radxa-kernel-patches {
  target = "kernel-radxa-patches"
  output = ["type=local,dest=./out/kernel/patches"]
}

target spl {
  target = "rkbin-spl"
  output = ["type=local,dest=./out"]
}

target u-boot-radxa {
  target = "u-boot-radxa"
  output = ["type=local,dest=./out/u-boot/radxa"]
  args   = {
    CHIP  = CHIP
    BOARD = BOARD
  }
}

target u-boot-collabora {
  target = "u-boot-collabora"
  output = ["type=local,dest=./out/u-boot/collabora"]
  args   = {
    CHIP  = CHIP
    BOARD = BOARD
  }
}

target edk2 {
  target = "edk2"
  output = ["type=local,dest=./out/edk2"]
  args   = {
    CHIP  = CHIP
    BOARD = BOARD
  }
}

group yolov8 {
  targets = ["yolov8-model-onnx", "yolov8-model-rknn"]
}

target _yolov8-model {
  context = "./rknn"
  output = ["type=local,dest=./out/rknn"]
  args = {
    YOLO_MODEL = "yolov8s"
  }
}

target yolov8-model-onnx {
  inherits = ["_yolov8-model"]
  target = "yolo-model-onnx"
}

target yolov8-model-rknn {
  inherits = ["_yolov8-model"]
  target = "yolo-model-rknn"
}

variable YOLO_MODEL {
  default = null
}

target rknn-benchmark {
  context = "./rknn"
  target = "rknn-benchmark"
  platforms = ["linux/arm64"]
  tags = ["docker.io/milas/rknn-benchmark:yolov8s"]
  contexts = notequal(null, YOLO_MODEL) ? { yolo-model-rknn = YOLO_MODEL } : {}
}

target rknn-toolkit2 {
  context = "./rknn"
  target = "rknn-toolkit2"
  platforms = ["linux/amd64"]
  tags = ["docker.io/milas/rknn-toolkit2"]
}

group rkmpp {
  targets = ["rkmpp-libs", "rkmpp-debian"]
}

target _rkmpp {
  context = "./rkmpp"
  platforms = ["linux/arm64"]
}

group rkmpp-libs {
  targets = ["rkmpp-rga", "rkmpp-mpp", "rkmpp-gstreamer-plugin"]
}

target rkmpp-rga {
  inherits = ["_rkmpp"]
  target = "rockchip-rga"
  output = ["type=local,dest=./out/rkmpp/rga"]
}

target rkmpp-mpp {
  inherits = ["_rkmpp"]
  target = "rockchip-mpp"
  output = ["type=local,dest=./out/rkmpp/mpp"]
}

target rkmpp-gstreamer-plugin {
  inherits = ["_rkmpp"]
  target = "rockchip-gstreamer-plugin"
  output = ["type=local,dest=./out/rkmpp/gstreamer"]
}

target rkmpp-debian {
  inherits = ["_rkmpp"]
  target = "os"
  args = {
    OS_BASE = "docker.io/debian:bullseye"
  }
  tags = ["docker.io/milas/rkmpp-debian:bullseye"]
}
