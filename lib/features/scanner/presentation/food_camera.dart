import 'dart:async';

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';

/// Why the in-app food camera cannot show a preview.
enum FoodCameraProblem { permissionDenied, unavailable }

/// In-app camera for Scan Food: live preview and still photos without leaving
/// the app (the `camera` plugin; PRD v1.7). Barcode mode keeps mobile_scanner.
class FoodCamera extends ChangeNotifier {
  FoodCamera({Future<List<CameraDescription>> Function()? cameras})
    : _cameras = cameras ?? availableCameras;

  final Future<List<CameraDescription>> Function() _cameras;

  CameraController? _controller;
  CameraLensDirection _lens = CameraLensDirection.back;
  FoodCameraProblem? _problem;
  bool _starting = false;
  bool _disposed = false;

  CameraController? get controller => _controller;
  FoodCameraProblem? get problem => _problem;
  bool get isReady => _controller?.value.isInitialized ?? false;

  /// Opens the camera (asks for the permission the first time).
  Future<void> start() async {
    if (_starting || _disposed) return;
    _starting = true;
    _problem = null;
    notifyListeners();
    try {
      await _release();
      final cameras = await _cameras();
      if (cameras.isEmpty) {
        _problem = FoodCameraProblem.unavailable;
        return;
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        // 1280×720: enough for the AI, and small to compress to ≤ 1024 px.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      _controller = controller;
    } on CameraException catch (e) {
      _problem = e.code.startsWith('CameraAccess')
          ? FoodCameraProblem.permissionDenied
          : FoodCameraProblem.unavailable;
    } finally {
      _starting = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Releases the camera (screen left, app paused or Barcode mode chosen).
  Future<void> stop() async {
    await _release();
    if (!_disposed) notifyListeners();
  }

  Future<void> _release() async {
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }

  Future<void> switchLens() async {
    _lens = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await start();
  }

  /// Takes a still photo; returns its file path.
  Future<String> takePicture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      throw const FormatException('The camera is not ready yet.');
    }
    if (c.value.isTakingPicture) {
      throw const FormatException('Hold on, taking the photo…');
    }
    final file = await c.takePicture();
    return file.path;
  }

  Future<void> pausePreview() async {
    final c = _controller;
    if (c != null && c.value.isInitialized && !c.value.isPreviewPaused) {
      await c.pausePreview();
    }
  }

  Future<void> resumePreview() async {
    final c = _controller;
    if (c != null && c.value.isInitialized && c.value.isPreviewPaused) {
      await c.resumePreview();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_release());
    super.dispose();
  }
}

/// Full-bleed preview (cover) or an error with "Try again".
class FoodCameraPreview extends StatelessWidget {
  const FoodCameraPreview({super.key, required this.camera});

  final FoodCamera camera;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: camera,
      builder: (context, _) {
        final problem = camera.problem;
        if (problem != null) {
          return CameraProblemView(
            permissionDenied: problem == FoodCameraProblem.permissionDenied,
            onRetry: camera.start,
          );
        }
        final c = camera.controller;
        if (c == null || !c.value.isInitialized) {
          return const ColoredBox(color: Colors.black);
        }
        final size = c.value.previewSize;
        return ColoredBox(
          color: Colors.black,
          child: size == null
              ? CameraPreview(c)
              : ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    // previewSize is landscape; the app is portrait-only.
                    child: SizedBox(
                      width: size.height,
                      height: size.width,
                      child: CameraPreview(c),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Shared camera error for both modes.
class CameraProblemView extends StatelessWidget {
  const CameraProblemView({
    super.key,
    required this.permissionDenied,
    required this.onRetry,
  });

  final bool permissionDenied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                permissionDenied
                    ? 'Camera access is off.\n'
                          'Allow it to scan food and barcodes.'
                    : 'Camera is not available.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
