# syntax=docker/dockerfile:1-labs

FROM scratch AS git-rknntoolkit2

ADD https://github.com/rockchip-linux/rknn-toolkit2.git /

# --------------------------------------------------------------------------- #

FROM scratch AS git-rknpu2

ADD https://github.com/rockchip-linux/rknpu2.git /

# --------------------------------------------------------------------------- #

FROM --platform=linux/amd64 ubuntu:20.04 AS rknn-toolkit2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    python3-pip \
    python3.8-dev \
    ;

COPY --link --from=git-rknntoolkit2 / /sdk/rknn-toolkit2

# need to install numpy first to prevent dependency-ordering issues
RUN pip3 install numpy==1.19.5
RUN pip3 install -r /sdk/rknn-toolkit2/doc/requirements_cp38-1.4.0.txt
RUN pip3 install /sdk/rknn-toolkit2/packages/rknn_toolkit2-1.4.0_22dcfef4-cp38-cp38-linux_x86_64.whl

# --------------------------------------------------------------------------- #

FROM --platform=${BUILDPLATFORM} python:3.11-bullseye AS yolo-build

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 \
    ;

ADD https://github.com/ultralytics/ultralytics.git /ultralytics
WORKDIR /ultralytics

RUN pip install .

# --------------------------------------------------------------------------- #

FROM yolo-build AS yolo-export-onnx

ARG YOLO_MODEL=yolov8s
RUN yolo export model=${YOLO_MODEL}.pt imgsz=480,640 format=onnx opset=12

# --------------------------------------------------------------------------- #

FROM scratch AS yolo-model-onnx

ARG YOLO_MODEL=yolov8s
COPY --link --from=yolo-export-onnx /ultralytics/${YOLO_MODEL}.onnx /

# --------------------------------------------------------------------------- #

FROM scratch AS dataset

COPY --link --from=git-rknntoolkit2 /examples/onnx/yolov5/bus.jpg /examples/onnx/yolov5/dataset.txt /

# --------------------------------------------------------------------------- #

FROM rknn-toolkit2 AS yolo-convert-rknn

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libgl1 \
    ;

RUN pip uninstall opencv-python -y \
    && pip install opencv-python-headless \
    ;

COPY rknn-export.py /sdk/tools/

ARG YOLO_MODEL=yolov8s
COPY --link --from=yolo-model-onnx /${YOLO_MODEL}.onnx /sdk/models/
COPY --link --from=dataset / /sdk/models/

RUN cd /sdk/models && python3 /sdk/tools/rknn-export.py ${YOLO_MODEL}.onnx

# --------------------------------------------------------------------------- #

FROM scratch AS yolo-model-rknn

ARG YOLO_MODEL=yolov8s
COPY --link --from=yolo-convert-rknn /sdk/models/${YOLO_MODEL}.rknn /

# --------------------------------------------------------------------------- #

FROM --platform=${BUILDPLATFORM} alpine AS dl-cross-compile

WORKDIR /cross-compile
ADD https://dl.radxa.com/tools/linux/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.gz .
RUN tar -xzf gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.gz --strip-components=4 \
    && rm gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.gz

# --------------------------------------------------------------------------- #

FROM --platform=${BUILDPLATFORM} ubuntu:20.04 AS rknn-benchmark-build-base

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cmake \
    make \
    ;

# --------------------------------------------------------------------------- #

FROM rknn-benchmark-build-base AS rknn-benchmark-build-amd64

COPY --from=dl-cross-compile /cross-compile /sdk/toolchain
RUN ln -s /sdk/toolchain/bin/aarch64-none-linux-gnu-gcc /usr/local/bin/aarch64-linux-gnu-gcc \
    && ln -s /sdk/toolchain/bin/aarch64-none-linux-gnu-g++ /usr/local/bin/aarch64-linux-gnu-g++ \
    ;

# --------------------------------------------------------------------------- #

FROM rknn-benchmark-build-base AS rknn-benchmark-build-arm64

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    g++ \
    gcc \
    ;

RUN ln -s $(which gcc) /usr/local/bin/aarch64-linux-gnu-gcc \
    && ln -s $(which g++) /usr/local/bin/aarch64-linux-gnu-g++ \
    ;

# --------------------------------------------------------------------------- #

FROM rknn-benchmark-build-${BUILDARCH} AS rknn-benchmark-build

COPY --link --from=git-rknpu2 / /sdk/rknpu2
RUN bash /sdk/rknpu2/examples/rknn_benchmark/build-linux_RK3588.sh

# --------------------------------------------------------------------------- #

FROM --platform=linux/arm64 ubuntu:20.04 AS rknn-benchmark

COPY --link --from=git-rknpu2 /runtime/RK3588/Linux/librknn_api/aarch64/*.so /usr/local/lib/aarch64-linux-gnu/
RUN ldconfig

COPY --link --from=rknn-benchmark-build /sdk/rknpu2/examples/rknn_benchmark/build/build_linux_aarch64/rknn_benchmark /usr/local/bin/

COPY --link --from=yolo-model-rknn /*.rknn /sdk/models/
