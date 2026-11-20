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
import 'food_camera.dart';
import 'scan_line.dart';

enum ScanMode { food, barcode }

/// Figma "Scan Food" (349:93) and "Scan Barcode" (355:34).
///
/// Scan Food uses the in-app camera (`camera` plugin): the shutter takes the
/// photo here, without opening the phone's camera app. Barcode uses
/// mobile_scanner. Only one of them holds the camera at a time.
///
/// Every successful scan adds one entry; the Food Details form then shows all
/// of them. Going back from the form returns here to scan another item.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, this.initialMode = ScanMode.food});

  final ScanMode initialMode;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  late ScanMode _mode = widget.initialMode;
  FoodCamera? _foodCam;
  MobileScannerController? _barcodeCam;
  bool _switching = false;
  bool _formOpen = false;

  static MobileScannerController _newBarcodeCamera() => MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );

  final _picker = ImagePicker();
  final List<FoodFormEntry> _entries = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_openCamera(_mode));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foodCam?.dispose();
    unawaited(_barcodeCam?.dispose());
    super.dispose();
  }

  /// Releases the camera while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _foodCam;
    if (cam == null || _formOpen) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(cam.stop());
    } else if (state == AppLifecycleState.resumed && !cam.isReady) {
      unawaited(cam.start());
    }
  }

  /// Hands the camera to the chosen mode, closing the other one first.
  Future<void> _openCamera(ScanMode mode) async {
    setState(() => _switching = true);
    if (mode == ScanMode.food) {
      final barcode = _barcodeCam;
      _barcodeCam = null;
      await barcode?.dispose();
      final cam = _foodCam ??= FoodCamera();
      if (mounted) setState(() => _switching = false);
      await cam.start();
    } else {
      final food = _foodCam;
      _foodCam = null;
      await food?.stop();
      food?.dispose();
      if (!mounted) return;
      setState(() {
        _barcodeCam = _newBarcodeCamera();
        _switching = false;
      });
    }
  }

  Future<void> _switchMode(ScanMode mode) async {
    if (mode == _mode || _switching) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
    await _openCamera(mode);
  }

  /// Barcode retry: mobile_scanner keeps a start error in its state even
  /// after a later start succeeds, so it needs a new controller.
  void _retryBarcodeCamera() {
    final old = _barcodeCam;
    setState(() => _barcodeCam = _newBarcodeCamera());
    unawaited(old?.dispose());
  }

  Future<void> _switchLens() async {
    if (_mode == ScanMode.food) {
      await _foodCam?.switchLens();
    } else {
      await _barcodeCam?.switchCamera();
    }
  }

  bool get _online => ref.read(onlineStatusProvider);

  /// Shutter: takes the photo with the in-app camera.
  Future<void> _shoot() async {
    final cam = _foodCam;
    if (_busy || !_online || cam == null) return;
    setState(() => _error = null);
    final String path;
    try {
      path = await cam.takePicture();
    } on FormatException catch (e) {
      _showError(e.message);
      return;
    } catch (_) {
      _showError('Could not take the photo. Please try again.');
      return;
    }
    await _analyzePhoto(path);
  }

  Future<void> _pickFromGallery() async {
    if (_busy || !_online) return;
    setState(() => _error = null);
    XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      _showError('Could not open the gallery.');
    }
    if (file != null) await _analyzePhoto(file.path);
  }

  Future<void> _analyzePhoto(String path) => _analyze(() async {
    final prepared = await ref.read(imagePreparerProvider).prepare(path);
    final result = await ref
        .read(aiClientProvider)
        .analyzeFood(prepared.upload);
    return entryFromAnalysis(result, photo: prepared.thumbnail);
  });

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_mode != ScanMode.barcode || _busy || !_online) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null) return;
    await _barcodeCam?.stop();
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
        if (_mode == ScanMode.barcode) unawaited(_barcodeCam?.start());
      }
    }
  }

  /// The camera preview is paused while the form is open.
  Future<void> _openForm() async {
    _formOpen = true;
    await _foodCam?.pausePreview();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodFormScreen.add(entries: _entries),
      ),
    );
    _formOpen = false;
    final cam = _foodCam;
    if (cam != null) {
      cam.isReady ? await cam.resumePreview() : await cam.start();
    }
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
        await _switchMode(ScanMode.food);
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
                    mode: _mode,
                    foodCamera: _foodCam,
                    barcodeCamera: _barcodeCam,
                    switching: _switching,
                    busy: _busy,
                    online: online,
                    error: _error,
                    onDetect: _onBarcode,
                    onRetryBarcode: _retryBarcodeCamera,
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
                    onTap: () => _switchMode(ScanMode.food),
                  ),
                  const SizedBox(width: 24),
                  _ModeButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Barcode',
                    selected: _mode == ScanMode.barcode,
                    onTap: () => _switchMode(ScanMode.barcode),
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
                      onTap: _pickFromGallery,
                    ),
                    _ShutterButton(
                      enabled: online && !_busy && _mode == ScanMode.food,
                      onTap: _shoot,
                    ),
                    CircleIconButton(
                      icon: Icons.cameraswitch_outlined,
                      tooltip: 'Switch camera',
                      size: 50,
                      background: AppColors.glassButton,
                      shadow: false,
                      onPressed: _busy ? null : _switchLens,
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
    required this.mode,
    required this.foodCamera,
    required this.barcodeCamera,
    required this.switching,
    required this.busy,
    required this.online,
    required this.error,
    required this.onDetect,
    required this.onRetryBarcode,
  });

  final ScanMode mode;
  final FoodCamera? foodCamera;
  final MobileScannerController? barcodeCamera;
  final bool switching;
  final bool busy;
  final bool online;
  final String? error;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onRetryBarcode;

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

    final food = foodCamera;
    final barcode = barcodeCamera;
    final Widget preview;
    if (switching) {
      preview = const ColoredBox(color: Colors.black);
    } else if (mode == ScanMode.food && food != null) {
      preview = FoodCameraPreview(camera: food);
    } else if (mode == ScanMode.barcode && barcode != null) {
      final scanner = MobileScanner(
        key: ObjectKey(barcode),
        controller: barcode,
        onDetect: onDetect,
        errorBuilder: (context, error) => CameraProblemView(
          permissionDenied:
              error.errorCode == MobileScannerErrorCode.permissionDenied,
          onRetry: onRetryBarcode,
        ),
      );
      // CameraX mirrors the front-camera preview; a scanner should show the
      // real orientation (phone test feedback), so flip it back. Detection
      // runs on the camera frames and is not affected.
      preview = ValueListenableBuilder<MobileScannerState>(
        valueListenable: barcode,
        child: scanner,
        builder: (context, state, child) =>
            state.cameraDirection == CameraFacing.front && state.isRunning
            ? Transform.flip(flipX: true, child: child)
            : child!,
      );
    } else {
      preview = const ColoredBox(color: Colors.black);
    }

    // Barcode errors are drawn by MobileScanner itself; the sweep sits on
    // top and is hidden only for food-camera problems.
    final hasCamera = !switching && (food != null || barcode != null);

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
            preview,
            if (hasCamera)
              ListenableBuilder(
                listenable: food ?? const _NoListenable(),
                builder: (context, _) => food?.problem != null
                    ? const SizedBox.shrink()
                    : ScanLine(active: !busy && online),
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

/// Placeholder [Listenable] for Barcode mode (no food camera to watch).
class _NoListenable implements Listenable {
  const _NoListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
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
