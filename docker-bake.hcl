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

target sdk {
  target = "sdk"
  tags = ["docker.io/milas/rock5-sdk"]
}

target rkdeveloptool {
  target     = "rkdeveloptool"
  tags       = ["docker.io/milas/rkdeveloptool"]
}

target kernel {
  dockerfile = "Dockerfile"
  target     = "kernel"
  output = ["type=local,dest=./out/kernel"]
  contexts = notequal(null, DEFCONFIG) ? { defconfig = DEFCONFIG } : {}
  args = {
    CHIP = CHIP
    BOARD = BOARD
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
  args = {
    CHIP = CHIP
    BOARD = BOARD
  }
}

target u-boot-collabora {
  target = "u-boot-collabora"
  output = ["type=local,dest=./out/u-boot/collabora"]
  args = {
    CHIP  = CHIP
    BOARD = BOARD
  }
}

target edk2 {
  target = "edk2"
  output = ["type=local,dest=./out/edk2"]
  args = {
    CHIP  = CHIP
    BOARD = BOARD
  }
}
