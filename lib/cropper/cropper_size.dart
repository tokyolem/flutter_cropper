import 'dart:ui';

abstract interface class CropperSize {
  static Size cropperSize = const Size(0, 0);

  static Size frameSize = const Size(0, 0);

  static void setCropperDimensions(Size cSize, Size fSize) {
    cropperSize = cSize;
    frameSize = fSize;
  }
}
