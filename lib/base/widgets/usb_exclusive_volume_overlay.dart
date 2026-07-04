import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

/// 独占模式下按安卓物理音量键时弹出的右侧竖向毛玻璃音量面板：显示音量、可拖动竖滑条
/// 调节、底部静音键，静止约 2 秒后自动隐藏。系统音量条已被 MainActivity 拦截，改由本
/// 面板反馈与操作。叠在 MaterialApp 之上（需 Stack 父级），只在收到物理音量键事件时
/// 显示。DSD 独占不会触发（1-bit 码流无法软件调音量，引擎侧不接管音量键）。
class UsbExclusiveVolumeOverlay extends StatefulWidget {
  const UsbExclusiveVolumeOverlay({super.key});

  @override
  State<UsbExclusiveVolumeOverlay> createState() =>
      _UsbExclusiveVolumeOverlayState();
}

class _UsbExclusiveVolumeOverlayState extends State<UsbExclusiveVolumeOverlay> {
  bool _visible = false;
  Timer? _hideTimer;
  double _lastNonZeroVolume = 0.3;

  @override
  void initState() {
    super.initState();
    usbExclusiveVolumeKeyNotifier.addListener(_show);
  }

  @override
  void dispose() {
    usbExclusiveVolumeKeyNotifier.removeListener(_show);
    _hideTimer?.cancel();
    super.dispose();
  }

  // 显示并重置自动隐藏计时；拖动滑条或点静音时也调用它保持常驻。
  void _show() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _visible = false);
    });
    if (!_visible) {
      setState(() => _visible = true);
    }
  }

  void _applyVolume(double next) {
    if (next > 0) _lastNonZeroVolume = next;
    volumeNotifier.value = next;
    audioHandler.setVolume(next);
    _show();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 固定尺寸避免被松约束撑爆：右侧竖条，高度取屏高一半并封顶。
    final height = (media.size.height * 0.5).clamp(360.0, 520.0);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_visible,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0.25, 0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(width: 78, height: height, child: _panel()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    return ValueListenableBuilder<ThemeType>(
      valueListenable: mainPageThemeNotifier,
      builder: (context, theme, _) {
        return ValueListenableBuilder<double>(
          valueListenable: volumeNotifier,
          builder: (context, volume, _) {
            final accent = iconColor.value;
            final clamped = volume.clamp(0.0, 1.0);
            final percent = (clamped * 100).round();
            final muted = clamped <= 0;
            final dark = theme == ThemeType.dark;
            return ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: menuColor.value.withAlpha(dark ? 160 : 190),
                    borderRadius: BorderRadius.circular(38),
                    border: Border.all(color: textColor.value.withAlpha(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(dark ? 90 : 35),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Icon(
                          muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: accent,
                          size: 24,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppLocalizations.of(context).volumeSection,
                          style: TextStyle(
                            color: textColor.value.withAlpha(140),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: textColor.value,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _verticalSlider(accent, clamped)),
                        const SizedBox(height: 12),
                        _muteButton(accent, clamped, muted),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _verticalSlider(Color accent, double value) {
    return RotatedBox(
      quarterTurns: 3,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          activeTrackColor: accent,
          inactiveTrackColor: accent.withAlpha(38),
          thumbColor: Colors.white,
          overlayColor: accent.withAlpha(30),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        ),
        child: Slider(
          value: value,
          min: 0,
          max: 1,
          onChanged: _applyVolume,
          onChangeEnd: (_) => audioHandler.savePlayState(),
        ),
      ),
    );
  }

  Widget _muteButton(Color accent, double volume, bool muted) {
    return GestureDetector(
      onTap: () {
        _applyVolume(muted ? _lastNonZeroVolume : 0.0);
        audioHandler.savePlayState();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: textColor.value.withAlpha(22),
        ),
        child: Icon(
          Icons.volume_off_rounded,
          color: muted ? accent : textColor.value.withAlpha(170),
          size: 19,
        ),
      ),
    );
  }
}
