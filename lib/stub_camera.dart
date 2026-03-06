// Stub for camera package on Web
import 'package:flutter/material.dart';

class CameraValue {
  final bool isInitialized;
  const CameraValue({this.isInitialized = false});
}

class CameraController {
  final CameraValue value = const CameraValue(isInitialized: false);
  CameraController(dynamic camera, dynamic preset, {bool enableAudio = true});
  Future<void> initialize() async {}
  Future<_StubXFile> takePicture() async => _StubXFile();
  void dispose() {}
}

class _StubXFile {
  Future<List<int>> readAsBytes() async => [];
}

class CameraPreview extends StatelessWidget {
  final CameraController controller;
  const CameraPreview(this.controller, {super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CameraLensDirection {
  static const front = CameraLensDirection._();
  const CameraLensDirection._();
}

class ResolutionPreset {
  static const low = ResolutionPreset._();
  const ResolutionPreset._();
}

Future<List<dynamic>> availableCameras() async => [];
