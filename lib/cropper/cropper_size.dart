import 'dart:ui';

import 'package:flutter/foundation.dart';

abstract interface class CropperSize {
  @protected
  static Size cropperSize = const Size(0, 0);

  @protected
  static Size frameSize = const Size(0, 0);

  @protected
  static void setCropperDimensions(Size cSize, Size fSize) {
    cropperSize = cSize;
    frameSize = fSize;
  }
}
