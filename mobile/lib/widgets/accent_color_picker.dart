import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/haptic_service.dart';
import '../services/user_api.dart';

class AccentColorPicker extends StatelessWidget {
  static const List<_PresetColor> _presets = [
    _PresetColor(Color(0xFF4CAF50), Color(0xFF81C784), 'Green'),
    _PresetColor(Color(0xFF2196F3), Color(0xFF64B5F6), 'Blue'),
    _PresetColor(Color(0xFF9C27B0), Color(0xFFCE93D8), 'Purple'),
    _PresetColor(Color(0xFFF44336), Color(0xFFEF9A9A), 'Red'),
    _PresetColor(Color(0xFFFF9800), Color(0xFFFFCC80), 'Orange'),
    _PresetColor(Color(0xFF009688), Color(0xFF80CBC4), 'Teal'),
    _PresetColor(Color(0xFFE91E63), Color(0xFFF48FB1), 'Pink'),
  ];

  const AccentColorPicker({super.key});

  void _selectColor(BuildContext context, Color color) {
    HapticService.action();
    final themeProvider = context.read<ThemeProvider>();
    themeProvider.setAccentColor(color);

    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final isDefault = color.toARGB32() == const Color(0xFF4CAF50).toARGB32();
    userApi.updateAccentColor(accentColor: isDefault ? null : hex).then((_) {}).catchError((_) {});
  }

  void _openCustomPicker(BuildContext context) {
    HapticService.action();
    final themeProvider = context.read<ThemeProvider>();
    Color pickerColor = themeProvider.accentColor;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            enableAlpha: false,
            hexInputBar: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _selectColor(context, pickerColor);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentColor = themeProvider.accentColor;
        final isPreset = _presets.any((p) => p.light.toARGB32() == currentColor.toARGB32());

        final children = <Widget>[
          ..._presets.map((preset) => _DiagonalSwatch(
            topLeftColor: preset.light,
            bottomRightColor: preset.dark,
            isSelected: preset.light.toARGB32() == currentColor.toARGB32(),
            onTap: () => _selectColor(context, preset.light),
            tooltip: preset.label,
          )),
          _CustomSwatch(
            customColor: isPreset ? null : currentColor,
            isSelected: !isPreset,
            onTap: () => _openCustomPicker(context),
          ),
        ];

        // 7 presets at 36px + 1 custom at 40px
        const totalItemWidth = 7 * 36.0 + 40.0;
        const itemCount = 8;
        const minSpacing = 6.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final fitsOnOneLine = availableWidth >= totalItemWidth + minSpacing * (itemCount - 1);

            if (fitsOnOneLine) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: children,
              );
            }

            return Wrap(
              spacing: minSpacing,
              runSpacing: 10,
              children: children,
            );
          },
        );
      },
    );
  }
}

class _PresetColor {
  final Color light;
  final Color dark;
  final String label;
  const _PresetColor(this.light, this.dark, this.label);
}

/// A circular swatch split diagonally: top-left is one color, bottom-right is another.
class _DiagonalSwatch extends StatelessWidget {
  final Color topLeftColor;
  final Color bottomRightColor;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _DiagonalSwatch({
    required this.topLeftColor,
    required this.bottomRightColor,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: ClipOval(
            child: CustomPaint(
              size: const Size(36, 36),
              painter: _DiagonalSplitPainter(
                topLeftColor: topLeftColor,
                bottomRightColor: bottomRightColor,
              ),
              child: isSelected
                  ? const Center(child: Icon(Icons.check, size: 18, color: Colors.white))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom swatch: diagonal split between the selected custom color and a "+" icon area.
/// Uses a rainbow gradient border to distinguish it from preset swatches.
class _CustomSwatch extends StatelessWidget {
  final Color? customColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomSwatch({
    required this.customColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final displayColor = customColor ?? bgColor;

    return Tooltip(
      message: 'Custom',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: isSelected ? 32 : 34,
              height: isSelected ? 32 : 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: CustomPaint(
                  size: Size(isSelected ? 32 : 34, isSelected ? 32 : 34),
                  painter: _DiagonalSplitPainter(
                    topLeftColor: displayColor,
                    bottomRightColor: bgColor,
                  ),
                  child: Center(
                    child: Icon(Icons.add, size: 18, color: isDark ? Colors.white70 : Colors.grey[600]),
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

class _DiagonalSplitPainter extends CustomPainter {
  final Color topLeftColor;
  final Color bottomRightColor;

  _DiagonalSplitPainter({
    required this.topLeftColor,
    required this.bottomRightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Bottom-right half (drawn first, behind)
    final bgPaint = Paint()..color = bottomRightColor;
    canvas.drawCircle(center, radius, bgPaint);

    // Top-left half: clip to the top-left triangle of the circle
    final topLeftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipPath(topLeftPath);
    final fgPaint = Paint()..color = topLeftColor;
    canvas.drawCircle(center, radius, fgPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagonalSplitPainter oldDelegate) {
    return oldDelegate.topLeftColor != topLeftColor ||
        oldDelegate.bottomRightColor != bottomRightColor;
  }
}
