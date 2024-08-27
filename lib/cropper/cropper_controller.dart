import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_cropper/cropper/cropper_size.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

final class CropperController extends ChangeNotifier implements CropperSize {
  final String imagePath;
  final Uri source;

  CropperController.filePath({required this.imagePath}) : source = Uri() {
    _transformationController = TransformationController();
    _initializeCroppedImage();
  }

  CropperController.network({required this.source}) : imagePath = '' {
    _transformationController = TransformationController();
    _initializeNetworkImage();
  }

  TransformationController get transformationController =>
      _transformationController;

  Matrix4 get transformationMatrix => _transformationController.value;

  ui.Image? get imageInstance => _originalImage;

  File? get imageFile => _imageFile;

  File? get croppedImageFile => _croppedImageFile;

  late final TransformationController _transformationController;
  ui.Image? _originalImage;
  File? _imageFile;
  File? _croppedImageFile;

  @override
  void dispose() {
    super.dispose();

    _transformationController.dispose();
  }

  void resetCrop({
    VoidCallback? onResetStart,
    VoidCallback? onResetEnd,
  }) {
    onResetStart?.call();

    File(_croppedImageFile!.path)
        .openSync(mode: FileMode.append)
        .truncateSync(0);

    _croppedImageFile = null;
    setDefaultTranslations();

    onResetEnd?.call();
  }

  Matrix4 setDefaultTranslations() {
    final imageW = imageInstance?.width;
    final imageH = imageInstance?.height;

    final cropperSize = CropperSize.cropperSize;
    final frameSize = CropperSize.frameSize;

    if (imageW == null || imageH == null) return Matrix4.identity();

    final imageAspectRatio = imageW / imageH;
    final cropperAspectRatio = cropperSize.width / cropperSize.height;

    var scale = 0.0;
    if (imageAspectRatio > cropperAspectRatio || imageW < cropperSize.width) {
      scale = cropperSize.width / imageW;
      if (imageH * scale < frameSize.height) {
        scale = frameSize.height / imageH;
      }
    } else {
      scale = cropperSize.height / imageH;
    }

    final offsetX = (cropperSize.width - imageW * scale) / 2;
    final offsetY = (cropperSize.height / 2) - ((imageH * scale) / 2);

    final matrix4 = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(scale);

    transformationController.value = matrix4;

    return matrix4;
  }

  Future<File?> cropImage({
    VoidCallback? onCropStart,
    VoidCallback? onCropEnd,
  }) async {
    onCropStart?.call();

    final croppedFile = await _CropIsolate(
      _imageFile,
      transformationMatrix: transformationMatrix,
      cropperFrameSize: Size(
        CropperSize.frameSize.width,
        CropperSize.frameSize.height,
      ),
      cropperSize: Size(
        CropperSize.cropperSize.width,
        CropperSize.cropperSize.height,
      ),
    ).startCropping();

    _croppedImageFile = croppedFile;

    if (croppedFile == null) {
      onCropEnd?.call();
      return null;
    }

    notifyListeners();
    onCropEnd?.call();

    return croppedFile;
  }

  Future<void> _initializeNetworkImage() async {
    final networkImageResponse = await http.get(source);
    final imageBytes = networkImageResponse.bodyBytes;

    final temporaryDir = await getTemporaryDirectory();
    final microseconds = DateTime.now().microsecondsSinceEpoch;
    final imagePath = '${temporaryDir.path}/$microseconds.jpg';

    final imageFile = File(imagePath);
    await imageFile.create();
    await imageFile.writeAsBytes(imageBytes);

    await _createUiImage(imagePath);
    _createImageFile(imagePath);

    notifyListeners();
  }

  Future<void> _initializeCroppedImage() async {
    await _createUiImage(imagePath);
    _createImageFile();

    notifyListeners();
  }

  Future<void> _createUiImage(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();

    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();

    _originalImage = frameInfo.image;
  }

  void _createImageFile([String? imagePath]) => _imageFile = File(
        imagePath ?? this.imagePath,
      );
}

final class _CropIsolate {
  final File? imageFile;
  final Matrix4 transformationMatrix;
  final Size cropperFrameSize;
  final Size cropperSize;

  const _CropIsolate(
    this.imageFile, {
    required this.transformationMatrix,
    required this.cropperFrameSize,
    required this.cropperSize,
  });

  Future<File?> startCropping() {
    return Isolate.run<File?>(
      () => _cropImage(
        cropperFrameSize: cropperFrameSize,
        cropperSize: cropperSize,
      ),
    );
  }

  Future<File?> _cropImage({
    required Size cropperFrameSize,
    required Size cropperSize,
  }) async {
    final originalImage = img.decodeImage(await imageFile!.readAsBytes());

    if (originalImage == null) return null;

    final currentTranslation = transformationMatrix.getTranslation();
    final currentScale = transformationMatrix.getMaxScaleOnAxis();

    final cropRect = Rect.fromLTWH(
      ((cropperSize.width / 2 - cropperFrameSize.width / 2) -
              currentTranslation.x) /
          currentScale,
      ((cropperSize.height / 2 - cropperFrameSize.height / 2) -
              currentTranslation.y) /
          currentScale,
      cropperFrameSize.width / currentScale,
      cropperFrameSize.height / currentScale,
    );

    final croppedImage = img.copyCrop(
      originalImage,
      x: cropRect.left.clamp(0, originalImage.width.toDouble()).toInt(),
      y: cropRect.top.clamp(0, originalImage.height.toDouble()).toInt(),
      width: cropRect.width.clamp(0, originalImage.width.toDouble()).toInt(),
      height: cropRect.height.clamp(0, originalImage.height.toDouble()).toInt(),
    );

    final croppedFile = await _encodeImage(imageFile!.path, croppedImage);

    return croppedFile;
  }

  Future<File?> _encodeImage(String imagePath, img.Image croppedImage) async {
    final imageExtension = imagePath.split('.').last.toLowerCase();
    final randImageUnique = Random().nextInt(2147483647);

    if (imageExtension == 'heic' || imageExtension == 'heif') {
      final convertedPath = imagePath.replaceAll(
        '.$imageExtension',
        '_cropped$randImageUnique.jpeg',
      );

      return _compressHeifHeicImage(imagePath, convertedPath);
    }

    final croppedFile = File(
      imagePath.replaceAll(
        '.$imageExtension',
        '_cropped$randImageUnique.$imageExtension',
      ),
    );

    return switch (imageExtension) {
      'png' => croppedFile.writeAsBytes(
          img.encodePng(croppedImage),
        ),
      'jpg' || 'jpeg' => croppedFile.writeAsBytes(
          img.encodeJpg(croppedImage),
        ),
      _ => throw UnimplementedError(),
    };
  }

  Future<File?> _compressHeifHeicImage(
    String targetPath,
    String convertedPath,
  ) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      convertedPath,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 90,
    );

    return result == null ? null : File(result.path);
  }
}
