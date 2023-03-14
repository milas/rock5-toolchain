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
  extends = ["kernel-config"]
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
