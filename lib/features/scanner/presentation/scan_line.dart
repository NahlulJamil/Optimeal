import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Green scanning band that sweeps up and down over the viewfinder, based on
/// the green gradient in the Figma scanner frames.
class ScanLine extends StatefulWidget {
  const ScanLine({super.key, this.active = true});

  /// Stops the sweep (e.g. while analyzing or when the camera is off).
  final bool active;

  @override
  State<ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final Animation<double> _position = CurvedAnimation(
    parent: _sweep,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _sweep.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ScanLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    } else if (!widget.active && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          const bandHeight = 120.0;
          return AnimatedBuilder(
            animation: _position,
            builder: (context, _) {
              // Moving down the glow trails above the line; moving up, below.
              final goingDown = _sweep.status != AnimationStatus.reverse;
              final lineY = _position.value * h;
              final top = goingDown ? lineY - bandHeight : lineY;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top,
                    height: bandHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: goingDown
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          end: goingDown
                              ? Alignment.bottomCenter
                              : Alignment.topCenter,
                          colors: const [Color(0x00005A32), Color(0x8000A35C)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: lineY - 1,
                    height: 2,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF3DDC84),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
