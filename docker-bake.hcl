variable DEFCONFIG {
  default = ""
}

group default {
  targets = ["kernel", "u-boot-radxa", "edk2"]
}

target sdk {
  target = "sdk"
  tags = ["ghcr.io/milas/rock5b-sdk"]
}

target kernel {
  dockerfile = "Dockerfile"
  target     = "kernel"
  tags = ["ghcr.io/milas/rock5b-kernel"]
  output = ["type=local,dest=./out/kernel"]
  contexts = notequal("", DEFCONFIG) ? { defconfig = DEFCONFIG } : {}
}

target u-boot-radxa {
  target = "u-boot-radxa"
  tags = ["ghcr.io/milas/rock5b-u-boot-radxa"]
  output = ["type=local,dest=./out/u-boot/radxa"]
}

target edk2-builder {
  target   = "edk2-builder"
  tags     = ["ghcr.io/milas/rock5b-edk2-builder"]
}

target edk2 {
  target = "edk2"
  tags = ["ghcr.io/milas/rock5b-edk2"]
  output = ["type=local,dest=./out/edk2"]
}

target rkdeveloptool {
  dockerfile = "Dockerfile"
  tags = ["ghcr.io/milas/rkdeveloptool"]
  target = "rkdeveloptool"
}

target bsp {
  tags = ["ghcr.io/milas/radxa-bsp"]
  target = "bsp"
}

target radxa-kernel-patches {
  target = "kernel-radxa-patches"
  output = ["type=local,dest=./out/kernel/patches"]
}
