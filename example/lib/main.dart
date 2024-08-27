import 'package:flutter/material.dart';
import 'package:flutter_cropper/flutter_cropper.dart';

void main() {
  runApp(const ExampleApp());
}

final class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CropperExample(),
    );
  }
}

final class CropperExample extends StatefulWidget {
  const CropperExample({super.key});

  @override
  State<CropperExample> createState() => _CropperExampleState();
}

class _CropperExampleState extends State<CropperExample>
    with SingleTickerProviderStateMixin {
  late final CropperController _cropperController;
  late final AnimationController _controller;

  var _needCropButton = true;

  @override
  void initState() {
    super.initState();

    const url =
        'https://www.dmarge.com/wp-content/uploads/2021/01/dwayne-the-rock-.jpg';

    _cropperController = CropperController.network(source: Uri.parse(url));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Curves.fastOutSlowIn,
            ),
            child: Cropper(
              controller: _cropperController,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchOutCurve: Curves.fastOutSlowIn,
              switchInCurve: Curves.fastOutSlowIn,
              child: _needCropButton
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: FilledButton(
                            onPressed: () {
                              setState(() => _needCropButton = false);
                              _cropperController.cropImage(
                                onCropStart: _controller.reverse,
                                onCropEnd: _controller.forward,
                              );
                            },
                            child: const Text('Crop image'),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _needCropButton = true);
              _cropperController.resetCrop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
