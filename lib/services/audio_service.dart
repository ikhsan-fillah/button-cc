import 'package:flutter/services.dart';

class AudioService {
  Future<void> init() async {}

  Future<void> playBuzzer() async {
    await SystemSound.play(SystemSoundType.alert);
  }

  void dispose() {}
}
