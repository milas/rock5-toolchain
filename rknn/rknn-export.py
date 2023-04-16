import sys

from rknn.api import RKNN

# adapted from
# https://github.com/rockchip-linux/rknn-toolkit2/blob/324671aa65785fd471920771de98baf9ca45ab43/examples/onnx/yolov5/test.py#L236-L268
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('usage: rknn-export.py ONXX_MODEL_FILE')
        exit(1)

    onxx_model_filename = sys.argv[1]

    # Create RKNN object
    rknn = RKNN(verbose=True)

    # pre-process config
    print('--> Config model')
    rknn.config(mean_values=[[0, 0, 0]], std_values=[[255, 255, 255]], target_platform="rk3588")
    print('done')

    # Load ONNX model
    print('--> Loading model')
    ret = rknn.load_onnx(model=onxx_model_filename)
    if ret != 0:
        print('Load model failed!')
        exit(ret)
    print('done')

    # Build model
    print('--> Building model')
    ret = rknn.build(do_quantization=True)
    if ret != 0:
        print('Build model failed!')
        exit(ret)
    print('done')

    # Export RKNN model
    print('--> Export rknn model')
    ret = rknn.export_rknn(onxx_model_filename.rstrip('.onnx') + ".rknn")
    if ret != 0:
        print('Export rknn model failed!')
        exit(ret)
    print('done')
