import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum AudioDevice { earpiece, speaker, bluetooth }

extension AudioDeviceExt on AudioDevice {
  IconData get icon {
    switch (this) {
      case AudioDevice.earpiece: return Icons.hearing;
      case AudioDevice.speaker: return Icons.volume_up;
      case AudioDevice.bluetooth: return Icons.bluetooth_audio;
    }
  }

  String get label {
    switch (this) {
      case AudioDevice.earpiece: return 'Fülhallgató';
      case AudioDevice.speaker: return 'Hangszóró';
      case AudioDevice.bluetooth: return 'Bluetooth';
    }
  }
}

class AudioDevicePicker extends StatefulWidget {
  final AudioDevice current;
  final bool demoMode;
  final void Function(AudioDevice) onSelect;

  const AudioDevicePicker({
    super.key,
    required this.current,
    required this.onSelect,
    this.demoMode = false,
  });

  @override
  State<AudioDevicePicker> createState() => _AudioDevicePickerState();
}

class _AudioDevicePickerState extends State<AudioDevicePicker> {
  List<_DeviceOption> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final options = <_DeviceOption>[
      _DeviceOption(device: AudioDevice.earpiece, label: 'Fülhallgató', available: true),
      _DeviceOption(device: AudioDevice.speaker, label: 'Hangszóró', available: true),
    ];

    if (widget.demoMode) {
      // Demo módban mindig mutassunk egy fake BT eszközt
      options.add(_DeviceOption(
        device: AudioDevice.bluetooth,
        label: 'AirPods Pro',
        available: true,
      ));
    } else {
      // Éles módban enumeráljuk az eszközöket
      try {
        final devices = await navigator.mediaDevices.enumerateDevices();
        final btDevices = devices.where((d) =>
          d.kind == 'audioinput' && d.label.toLowerCase().contains('bluetooth') ||
          d.kind == 'audiooutput' && d.label.isNotEmpty
        ).toList();

        if (btDevices.isNotEmpty) {
          final btLabel = btDevices.first.label.isNotEmpty
              ? btDevices.first.label
              : 'Bluetooth eszköz';
          options.add(_DeviceOption(
            device: AudioDevice.bluetooth,
            label: btLabel,
            available: true,
          ));
        }
      } catch (_) {
        // Ha nem sikerül, nem mutatjuk a BT opciót
      }
    }

    if (mounted) setState(() { _devices = options; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Hangkimenet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            ..._devices.map((opt) => ListTile(
              leading: Icon(opt.device.icon,
                color: widget.current == opt.device ? Colors.blue : Colors.grey[600]),
              title: Text(opt.label),
              trailing: widget.current == opt.device
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                widget.onSelect(opt.device);
                Navigator.pop(context);
              },
            )),
        ],
      ),
    );
  }
}

class _DeviceOption {
  final AudioDevice device;
  final String label;
  final bool available;
  _DeviceOption({required this.device, required this.label, required this.available});
}

// Hangeszköz alkalmazása éles hívásban
Future<void> applyAudioDevice(AudioDevice device) async {
  try {
    switch (device) {
      case AudioDevice.speaker:
        await Helper.setSpeakerphoneOn(true);
        break;
      case AudioDevice.earpiece:
        await Helper.setSpeakerphoneOn(false);
        break;
      case AudioDevice.bluetooth:
        await Helper.setSpeakerphoneOn(false);
        // iOS/Android automatikusan routol BT-re ha ki van kapcsolva a speaker
        break;
    }
  } catch (_) {}
}
