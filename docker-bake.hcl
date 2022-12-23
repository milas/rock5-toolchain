variable GIT_FETCH {
  default = ""
}

variable DEFCONFIG {
  default = ""
}

function "maybe_skip_git_targets" {
  params = []
  result = notequal("",GIT_FETCH) ? ["git-kernel,git-u-boot,git-rkbin,git-radxa-build,git-edk2,git-rkdeveloptool"] : []
}

group "default" {
  targets = ["kernel", "u-boot", "edk2"]
}

target "kernel" {
  dockerfile = "Dockerfile"
  target     = "kernel"
  tags = ["ghcr.io/milas/rock5b-kernel"]
  output = ["type=local,dest=./out/kernel"]
  no-cache-filter = maybe_skip_git_targets()
  args = {
    DEFCONFIG = DEFCONFIG
  }
}

target "u-boot" {
  dockerfile = "Dockerfile"
  target = "u-boot"
  tags = ["ghcr.io/milas/rock5b-u-boot"]
  output = ["type=local,dest=./out/u-boot"]
  no-cache-filter = maybe_skip_git_targets()
}

target "edk2" {
  dockerfile = "Dockerfile"
  target = "edk2"
  output = ["type=local,dest=./out/edk2"]
  no-cache-filter = maybe_skip_git_targets()
}

target "rkdeveloptool" {
  dockerfile = "Dockerfile"
  tags = ["ghcr.io/milas/rkdeveloptool"]
  target = "rkdeveloptool"
  no-cache-filter = maybe_skip_git_targets()
}
