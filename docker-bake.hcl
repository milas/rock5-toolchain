variable DEFCONFIG {
  default = ""
}

function git_contexts {
  params = []
  result = {
    git-kernel : "https://github.com/radxa/kernel.git#linux-5.10-gen-rkr3.4"
    git-u-boot : "https://github.com/radxa/u-boot.git#stable-5.10-rock5"
    git-rkbin : "https://github.com/radxa/rkbin.git#master"
    git-radxa-build : "https://github.com/radxa/build.git#debian"
    git-edk2 : "https://github.com/edk2-porting/edk2-rk35xx.git#master"
    git-rkdeveloptool : "https://github.com/rockchip-linux/rkdeveloptool.git#master"
  }
}

group default {
  targets = ["kernel", "u-boot", "edk2"]
}

target sdk {
  target = "sdk"
  tags = ["ghcr.io/milas/rock5b-sdk"]
  contexts = git_contexts()
}

target kernel-builder {
  target     = "kernel-builder"
  tags       = ["ghcr.io/milas/rock5b-kernel-build"]
  contexts   = merge(notequal("", DEFCONFIG) ? { defconfig = DEFCONFIG } : {}, git_contexts())
}

target kernel {
  dockerfile = "Dockerfile"
  target     = "kernel"
  tags = ["ghcr.io/milas/rock5b-kernel"]
  output = ["type=local,dest=./out/kernel"]
  contexts = merge(notequal("", DEFCONFIG) ? { defconfig = DEFCONFIG } : {}, git_contexts())
}

target u-boot-builder {
  target   = "u-boot"
  tags     = ["ghcr.io/milas/rock5b-u-boot-builder"]
  contexts = git_contexts()
}

target u-boot {
  target = "u-boot"
  tags = ["ghcr.io/milas/rock5b-u-boot"]
  output = ["type=local,dest=./out/u-boot"]
  contexts = git_contexts()
}

target edk2-builder {
  target   = "edk2-builder"
  tags     = ["ghcr.io/milas/rock5b-edk2-builder"]
  contexts = git_contexts()
}

target edk2 {
  target = "edk2"
  tags = ["ghcr.io/milas/rock5b-edk2"]
  output = ["type=local,dest=./out/edk2"]
  contexts = git_contexts()
}

target rkdeveloptool {
  dockerfile = "Dockerfile"
  tags = ["ghcr.io/milas/rkdeveloptool"]
  target = "rkdeveloptool"
  contexts = git_contexts()
}
