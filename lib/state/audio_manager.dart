import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static AudioPool? _diceSoundPool;

  static Future<void> initialize() async {
    if (_diceSoundPool == null) {
      _diceSoundPool = await AudioPool.createFromAsset(
        path: 'dice.mp3', // ← Sirf file name
        maxPlayers: 3,
      );
    }
  }

  static Future<StopFunction> playDiceSound({double volume = 1.0}) async {
    return await _diceSoundPool!.start(volume: volume);
  }

  static Future<void> dispose() async {
    await _diceSoundPool?.dispose();
    _diceSoundPool = null;
  }
}
