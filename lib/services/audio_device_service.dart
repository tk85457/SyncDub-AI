import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class AudioOutputDevice {
  final int id;
  final String name;
  final String type; // 'speaker' | 'bluetooth' | 'headset' | 'earpiece'

  const AudioOutputDevice({
    required this.id,
    required this.name,
    required this.type,
  });

  IconData get iconData {
    switch (type) {
      case 'bluetooth':
        return Iconsax.headphone;
      case 'headset':
        return Iconsax.headphone;
      case 'earpiece':
        return Iconsax.mobile;
      default:
        return Iconsax.volume_high;
    }
  }

  String get icon => '';

  factory AudioOutputDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioOutputDevice(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? 'Phone Speaker',
      type: map['type']?.toString() ?? 'speaker',
    );
  }
}

class AudioDeviceService {
  static const MethodChannel _channel = MethodChannel('com.syncdub.livedub/audio_routing');

  static final AudioOutputDevice defaultSpeaker = const AudioOutputDevice(
    id: 1,
    name: 'Phone Speaker',
    type: 'speaker',
  );

  /// Fetch real-time available audio output devices from the physical phone
  static Future<List<AudioOutputDevice>> getAvailableOutputDevices() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getAudioDevices');
      if (result != null && result.isNotEmpty) {
        final devices = <AudioOutputDevice>[];
        final seenNames = <String>{};

        for (final item in result) {
          if (item is Map) {
            final dev = AudioOutputDevice.fromMap(item);
            if (!seenNames.contains(dev.name)) {
              seenNames.add(dev.name);
              devices.add(dev);
            }
          }
        }
        if (devices.isNotEmpty) return devices;
      }
    } catch (e) {
      debugPrint('[AudioDeviceService] Native audio device query failed: $e');
    }

    // Graceful default fallback list
    return [
      defaultSpeaker,
      const AudioOutputDevice(id: 2, name: 'Bluetooth Audio', type: 'bluetooth'),
      const AudioOutputDevice(id: 3, name: 'Wired Headset', type: 'headset'),
      const AudioOutputDevice(id: 4, name: 'Phone Earpiece', type: 'earpiece'),
    ];
  }

  /// Switch audio output route on the device
  static Future<bool> selectAudioOutput(AudioOutputDevice device) async {
    try {
      final bool? success = await _channel.invokeMethod('setAudioDevice', {
        'id': device.id,
        'type': device.type,
      });
      return success ?? true;
    } catch (e) {
      debugPrint('[AudioDeviceService] setAudioDevice error: $e');
      return false;
    }
  }
}
