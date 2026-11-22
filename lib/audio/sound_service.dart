import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Layanan efek suara ringan untuk pertandingan dan UI.
/// Aman dipanggil di lingkungan headless `flutter test` tanpa platform plugin.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool enabled = true;

  AudioPlayer? _whistlePlayer;
  AudioPlayer? _crowdPlayer;
  AudioPlayer? _ambiencePlayer;

  bool get _isTestEnv {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> _play(String asset, {bool crowd = false, double volume = 0.85}) async {
    if (!enabled || _isTestEnv) return;
    try {
      final player = crowd
          ? (_crowdPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop))
          : (_whistlePlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    } catch (_) {
      // Abaikan bila perangkat/emulator tidak mendukung audio.
    }
  }

  Future<void> startAmbience() async {
    if (!enabled || _isTestEnv) return;
    try {
      final p = _ambiencePlayer ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.loop);
      await p.setVolume(0.24);
      await p.play(AssetSource('audio/crowd_ambience.wav'));
    } catch (_) {}
  }

  Future<void> stopAmbience() async {
    if (_isTestEnv) return;
    try {
      await _ambiencePlayer?.stop();
    } catch (_) {}
  }

  Future<void> playKickoff() => _play('audio/whistle_kickoff.wav', volume: 0.85);
  Future<void> playFulltime() => _play('audio/whistle_fulltime.wav', volume: 0.9);
  Future<void> playFoul() => _play('audio/whistle_foul.wav', volume: 0.75);
  Future<void> playGoal() => _play('audio/goal_cheer.wav', crowd: true, volume: 0.9);
  Future<void> playMiss() => _play('audio/crowd_miss.wav', crowd: true, volume: 0.65);
  Future<void> playTap() => _play('audio/ui_tap.wav', volume: 0.45);

  Future<void> stopAll() async {
    if (_isTestEnv) return;
    try {
      await _whistlePlayer?.stop();
      await _crowdPlayer?.stop();
      await _ambiencePlayer?.stop();
    } catch (_) {}
  }
}
