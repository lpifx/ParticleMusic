part of '../../layer/audio_output_settings_layer.dart';

extension _AudioOutputSettingsPanel on _AudioOutputSettingsLayerState {
  Widget panelView(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: settingsVisibleNotifier,
      builder: (context, visible, child) {
        return Opacity(
          opacity: visible ? 0 : 1,
          child: Column(
            children: [
              TitleBar(backToRoot: () => layersManager.popDetail('settings')),
              Expanded(child: _content()),
            ],
          ),
        );
      },
    );
  }
}
