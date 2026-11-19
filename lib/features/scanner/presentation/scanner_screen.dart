import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/connectivity/online_status.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../pantry/domain/shelf_life.dart';
import '../../pantry/presentation/food_form_entry.dart';
import '../../pantry/presentation/food_form_screen.dart';
import '../application/scanner_providers.dart';
import '../data/ai_client.dart';
import '../data/image_prep.dart';

enum ScanMode { food, barcode }

/// Figma "Scan Food" (349:93) and "Scan Barcode" (355:34).
///
/// Every successful scan adds one entry; the Food Details form then shows all
/// of them. Going back from the form returns here to scan another item.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, this.initialMode = ScanMode.food});

  final ScanMode initialMode;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  late ScanMode _mode = widget.initialMode;
  late MobileScannerController _camera = _newCamera();

  static MobileScannerController _newCamera() => MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );

  /// A fresh controller: mobile_scanner keeps a start error in its state even
  /// after a later start succeeds, so retrying needs a new controller.
  void _retryCamera() {
    final old = _camera;
    setState(() => _camera = _newCamera());
    unawaited(old.dispose());
  }

  final _picker = ImagePicker();
  final List<FoodFormEntry> _entries = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  bool get _online => ref.read(onlineStatusProvider);

  Future<void> _capture(ImageSource source) async {
    if (_busy || !_online) return;
    setState(() => _error = null);
    // The live preview must release the camera before the picker opens it.
    await _camera.stop();
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: ImageLimits.uploadMaxSide.toDouble(),
        maxHeight: ImageLimits.uploadMaxSide.toDouble(),
        imageQuality: 85,
      );
    } catch (_) {
      _showError('Could not open the camera or gallery.');
    }
    if (file == null) {
      if (mounted) unawaited(_camera.start());
      return;
    }
    await _analyze(() async {
      final prepared = await ref
          .read(imagePreparerProvider)
          .prepare(file!.path);
      final result = await ref
          .read(aiClientProvider)
          .analyzeFood(prepared.upload);
      return entryFromAnalysis(result, photo: prepared.thumbnail);
    });
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_mode != ScanMode.barcode || _busy || !_online) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null) return;
    await _camera.stop();
    await _analyze(() async {
      final result = await ref.read(aiClientProvider).analyzeBarcode(value);
      return entryFromAnalysis(result);
    });
  }

  Future<void> _analyze(Future<FoodFormEntry> Function() run) async {
    setState(() => _busy = true);
    try {
      final entry = await run();
      if (!mounted) return;
      _entries.add(entry);
      await _openForm();
    } on AiException catch (e) {
      if (e.code == AiErrorCode.notFound) {
        await _barcodeNotFound();
      } else {
        _showError(aiErrorMessage(e));
      }
    } on FormatException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not analyze the food. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_camera.start());
      }
    }
  }

  Future<void> _openForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodFormScreen.add(entries: _entries),
      ),
    );
  }

  /// PRD §3.3 / AC 22: rescan, switch to Scan Food, or fill manually.
  Future<void> _barcodeNotFound() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product not recognized'),
        content: const Text(
          'We could not find this barcode. You can scan it again, take a '
          'photo of the food instead, or fill in the details yourself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'manual'),
            child: const Text('Fill manually'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'food'),
            child: const Text('Scan Food'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'retry'),
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'food':
        setState(() => _mode = ScanMode.food);
      case 'manual':
        _entries.add(
          FoodFormEntry(
            name: '',
            category: 'Others',
            location: StorageLocation.fridge,
            purchaseDate: dateOnly(DateTime.now()),
          ),
        );
        await _openForm();
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineStatusProvider);
    final lastPhoto = _entries.reversed
        .map((e) => e.photoBytes)
        .whereType<Uint8List>()
        .firstOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF262624),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 16, 26, 0),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      background: AppColors.glassButton,
                      shadow: false,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Scanner',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      background: AppColors.glassButton,
                      shadow: false,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 32, 25, 26),
                  child: _Viewfinder(
                    controller: _camera,
                    mode: _mode,
                    busy: _busy,
                    online: online,
                    error: _error,
                    onDetect: _onBarcode,
                    onRetry: _retryCamera,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ModeButton(
                    icon: Icons.ramen_dining_outlined,
                    label: 'Scan Food',
                    selected: _mode == ScanMode.food,
                    onTap: () => setState(() {
                      _mode = ScanMode.food;
                      _error = null;
                    }),
                  ),
                  const SizedBox(width: 24),
                  _ModeButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Barcode',
                    selected: _mode == ScanMode.barcode,
                    onTap: () => setState(() {
                      _mode = ScanMode.barcode;
                      _error = null;
                    }),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(55, 36, 52, 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GalleryButton(
                      visible: _mode == ScanMode.food,
                      enabled: online && !_busy,
                      preview: lastPhoto,
                      onTap: () => _capture(ImageSource.gallery),
                    ),
                    _ShutterButton(
                      enabled: online && !_busy && _mode == ScanMode.food,
                      onTap: () => _capture(ImageSource.camera),
                    ),
                    CircleIconButton(
                      icon: Icons.cameraswitch_outlined,
                      tooltip: 'Switch camera',
                      size: 50,
                      background: AppColors.glassButton,
                      shadow: false,
                      onPressed: () => _camera.switchCamera(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.controller,
    required this.mode,
    required this.busy,
    required this.online,
    required this.error,
    required this.onDetect,
    required this.onRetry,
  });

  final MobileScannerController controller;
  final ScanMode mode;
  final bool busy;
  final bool online;
  final String? error;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    String? message;
    if (!online) {
      message = mode == ScanMode.food
          ? 'Scanning food needs an internet connection.'
          : 'Scanning barcodes needs an internet connection.';
    } else if (error != null) {
      message = error;
    } else if (mode == ScanMode.barcode) {
      message = 'Point the camera at the product barcode.';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              key: ObjectKey(controller),
              controller: controller,
              onDetect: onDetect,
              errorBuilder: (context, error) => ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera access is off.\n'
                                  'Allow it to scan food and barcodes.'
                            : 'Camera is not available.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      // Asks for the permission again (or reopens the
                      // camera); found missing while testing on a phone.
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
            ),
            // Green scan gradient from Figma (lower half of the frame).
            const Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.55,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66005A32), Color(0x00005A32)],
                    ),
                  ),
                ),
              ),
            ),
            if (busy)
              const ColoredBox(
                color: Color(0x88000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text('Analyzing…', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            if (message != null && !busy)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFE8E8E6) : const Color(0x80E8E8E6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Take photo',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  const _GalleryButton({
    required this.visible,
    required this.enabled,
    required this.preview,
    required this.onTap,
  });

  final bool visible;
  final bool enabled;
  final Uint8List? preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = preview;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible ? (enabled ? 1 : 0.4) : 0,
      child: IgnorePointer(
        ignoring: !visible || !enabled,
        child: Semantics(
          button: true,
          label: 'Choose from gallery',
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 50,
                height: 50,
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.cover)
                    : const ColoredBox(
                        color: Color(0xFFE8E8E6),
                        child: Icon(
                          Icons.photo_library_outlined,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the scanner (used by the center Add button).
Future<void> openScanner(BuildContext context) {
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const ScannerScreen()));
}
