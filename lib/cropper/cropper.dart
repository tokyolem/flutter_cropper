import 'package:flutter/material.dart';
import 'package:flutter_cropper/cropper/cropper_controller.dart';
import 'package:flutter_cropper/cropper/cropper_frame_painter.dart';
import 'package:flutter_cropper/cropper/cropper_size.dart';

class Cropper extends StatefulWidget {
  final CropperController controller;

  const Cropper({required this.controller, super.key});

  @override
  State<Cropper> createState() => _CropperState();
}

class _CropperState extends State<Cropper>
    with TickerProviderStateMixin
    implements CropperSize {
  static const _frameInsets = 32.0;

  late final AnimationController _cropperAnimationController;
  late final AnimationController _zoomController;
  Animation<Matrix4>? _zoomAnimation;

  late final GlobalKey _cropperKey;

  @override
  void initState() {
    super.initState();

    _cropperKey = GlobalKey();

    _cropperAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(
        () => widget.controller.transformationController.value =
            _zoomAnimation?.value ?? Matrix4.identity(),
      );

    var needResetTranslation = true;

    widget.controller.addListener(
      () {
        if (widget.controller.imageFile != null) {
          if (needResetTranslation) {
            needResetTranslation = false;
            widget.controller.setDefaultTranslations();
          }

          setState(() {});
          _cropperAnimationController.forward();
        }
      },
    );

    widget.controller.transformationController
        .addListener(() => setState(() {}));

    Future.delayed(Duration.zero, _calculateCropperDimensions);
  }

  void _calculateCropperDimensions() {
    final cropperRenderObject =
        _cropperKey.currentContext?.findRenderObject() as RenderBox?;

    if (cropperRenderObject == null) return;

    final cropperSize = cropperRenderObject.size;

    final frameSquare = MediaQuery.sizeOf(context).width - _frameInsets * 2;

    CropperSize.setCropperDimensions(
      cropperSize,
      Size(frameSquare, frameSquare),
    );

    setState(() {});
  }

  double _screenPercentage(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height;

    return ((CropperSize.cropperSize.height / availableHeight) * 100) * 0.01;
  }

  double _verticalInsets(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height;

    final cropperScale = widget.controller.transformationMatrix.row0.x;

    final screenRatio = (availableHeight - CropperSize.cropperSize.height) *
        (1 + (_screenPercentage(context)));

    final verticalInsets =
        ((availableHeight - (CropperSize.frameSize.height + (screenRatio))) /
                cropperScale) /
            (1 + _screenPercentage(context));

    return verticalInsets;
  }

  void _handleDoubleTap(TapDownDetails details) {
    final tapPosition = details.localPosition;
    final currentScale =
        widget.controller.transformationController.value.getMaxScaleOnAxis();
    const targetScale = 3.0;

    final adjustedPosition = Offset(tapPosition.dx, tapPosition.dy);

    final currentMatrix = widget.controller.transformationController.value;

    final endMatrix = Matrix4.identity()
      ..translate(
        (-adjustedPosition.dx * targetScale) +
            CropperSize.frameSize.width -
            _frameInsets * 4,
        (-adjustedPosition.dy * targetScale) +
            CropperSize.frameSize.height +
            _frameInsets * 4,
      )
      ..scale(targetScale);

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: currentScale >= 3
          ? widget.controller.setDefaultTranslations()
          : endMatrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_zoomController),
    );

    _zoomController.forward(from: 0);
  }

  @override
  void dispose() {
    _cropperAnimationController.dispose();
    _zoomController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verticalInsets = _verticalInsets(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            key: _cropperKey,
            child: Stack(
              children: <Widget>[
                if (widget.controller.imageFile != null)
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.fastOutSlowIn,
                      switchOutCurve: Curves.fastOutSlowIn,
                      child: widget.controller.croppedImageFile == null
                          ? FadeTransition(
                              opacity: CurvedAnimation(
                                parent: _cropperAnimationController,
                                curve: Curves.fastOutSlowIn,
                              ),
                              child: CustomPaint(
                                foregroundPainter: CropperFramePainter(
                                  squareDimension:
                                      (CropperSize.frameSize.width +
                                              CropperSize.frameSize.height) /
                                          2,
                                ),
                                child: InteractiveViewer(
                                  transformationController: widget
                                      .controller.transformationController,
                                  minScale: 0.1,
                                  maxScale: 4.0,
                                  constrained: false,
                                  boundaryMargin: EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: verticalInsets,
                                  ),
                                  child: GestureDetector(
                                    // onDoubleTapDown: _handleDoubleTap,
                                    child: Image.file(
                                      widget.controller.imageFile!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Align(
                              child: SizedBox(
                                width: MediaQuery.sizeOf(context).width,
                                child: Image.file(
                                  widget.controller.croppedImageFile!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
