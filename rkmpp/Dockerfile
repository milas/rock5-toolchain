# syntax=docker/dockerfile:1-labs

ARG OS_BASE=debian:bullseye

FROM scratch AS git-rockchip-gstreamer

ADD https://github.com/JeffyCN/mirrors.git#gstreamer-rockchip /

# --------------------------------------------------------------------------- #

FROM scratch AS git-rockchip-mpp

ADD --keep-git-dir=true https://github.com/rockchip-linux/mpp.git#develop /

# --------------------------------------------------------------------------- #

FROM scratch AS git-rockchip-rga

ADD https://github.com/JeffyCN/mirrors.git#linux-rga /

# --------------------------------------------------------------------------- #

FROM --platform=${BUILDPLATFORM} ${OS_BASE} AS build-base

RUN --mount=type=cache,sharing=locked,id=apt-base,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=apt-base,target=/var/cache/apt \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cmake \
      g++ \
      gcc \
      git \
      make \
      wget \
    && rm -rf /var/lib/apt/lists/* \
    ;

# --------------------------------------------------------------------------- #

FROM build-base AS build-rockchip-mpp

COPY --link --from=git-rockchip-mpp / /src/rockchip-mpp

RUN cd /src/rockchip-mpp/build/linux/aarch64 \
    && ./make-Makefiles.bash \
    && DESTDIR=/out/rockchip-mpp make install -j$(nproc)

# --------------------------------------------------------------------------- #

FROM scratch AS rockchip-mpp

COPY --link --from=build-rockchip-mpp /out/rockchip-mpp /

# --------------------------------------------------------------------------- #

FROM build-base AS build-rockchip-rga

COPY --link --from=git-rockchip-rga / /src/rockchip-rga
WORKDIR /src/rockchip-rga

RUN --mount=type=cache,sharing=locked,id=apt-rkrga,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=apt-rkrga,target=/var/cache/apt \
    apt-get update \
    && DEBIAN_FRONTEND=noninterface apt-get install -y --no-install-recommends \
      libdrm-dev \
      meson \
      pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    ;

RUN cd /src/rockchip-rga \
    && meson build \
    && cd build \
    && DESTDIR=/out/rockchip-rga ninja install \
    ;

# --------------------------------------------------------------------------- #

FROM scratch AS rockchip-rga

COPY --link --from=build-rockchip-rga /out/rockchip-rga /

# --------------------------------------------------------------------------- #

FROM build-base AS build-rockchip-gstreamer

RUN --mount=type=cache,sharing=locked,id=apt-rkgstreamer,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=apt-rkgstreamer,target=/var/cache/apt \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libdrm-dev \
      libgstreamer-plugins-base1.0-dev \
      meson \
      pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    ;

COPY --link --from=rockchip-mpp / /
COPY --link --from=rockchip-rga / /

COPY --link --from=git-rockchip-gstreamer / /src/rockchip-gstreamer

RUN ldconfig && \
    pwd && \
    cd /src/rockchip-gstreamer \
    && meson build \
    && cd build \
    && DESTDIR=/out/rockchip-gstreamer ninja install \
    ;

# --------------------------------------------------------------------------- #

FROM scratch AS rockchip-gstreamer-plugin

COPY --link --from=build-rockchip-gstreamer /out/rockchip-gstreamer/ /

# --------------------------------------------------------------------------- #

FROM ${OS_BASE} AS os-gstreamer

ENV GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0

RUN --mount=type=cache,sharing=locked,id=apt-os,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=apt-os,target=/var/cache/apt \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libgstreamer1.0-0 \
      gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-good \
      gstreamer1.0-tools \
    && rm -rf /var/lib/apt/lists/* \
    ;

FROM os-gstreamer AS os

COPY --link --from=rockchip-mpp / /
COPY --link --from=rockchip-rga / /
COPY --link --from=rockchip-gstreamer-plugin / /

RUN ldconfig

# --------------------------------------------------------------------------- #

FROM os AS os-debug

ENV mpi_debug=1
ENV mpp_debug=1
ENV h264d_debug=1
ENV mpp_syslog_perror=1

ADD https://dl.radxa.com/media/video/1080p.264 /media/1080p.264

CMD mpi_dec_test -i /media/1080p.264 -t 7 -h 1080 -w 1920
