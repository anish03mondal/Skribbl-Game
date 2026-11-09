import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralized sound and BGM manager for the Skribbl game.
class SoundService {
  static final SoundService instance = SoundService._internal();

  SoundService._internal();

  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  // Dedicated BGM Player for Arcade Pop Bounce
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _isBgmPlaying = false;
  static const String lobbyBgmPath = 'audio/bgm_arcade_pop.wav';

  // Pool of AudioPlayers for overlapping sound effects
  final List<AudioPlayer> _players = [];
  int _playerIndex = 0;
  static const int _poolSize = 4;

  bool get isMuted => isMutedNotifier.value;

  void toggleMute() {
    isMutedNotifier.value = !isMutedNotifier.value;
    if (isMutedNotifier.value) {
      _bgmPlayer.pause().catchError((_) {});
    } else if (_isBgmPlaying) {
      _bgmPlayer.resume().catchError((_) {});
    }
  }

  void setMuted(bool muted) {
    if (isMutedNotifier.value == muted) return;
    toggleMute();
  }

  /// Start playing the Arcade Pop Bounce lobby BGM in an infinite loop
  Future<void> playLobbyBgm() async {
    _isBgmPlaying = true;
    if (isMuted) return;

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.45); // Balanced background volume
      await _bgmPlayer.play(AssetSource(lobbyBgmPath));
    } catch (e) {
      debugPrint('SoundService BGM playback notice ($lobbyBgmPath): $e');
    }
  }

  /// Pause or stop the lobby BGM
  Future<void> stopLobbyBgm() async {
    _isBgmPlaying = false;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('SoundService stop BGM notice: $e');
    }
  }

  AudioPlayer _getPlayer() {
    if (_players.length < _poolSize) {
      final player = AudioPlayer();
      _players.add(player);
      return player;
    }
    final player = _players[_playerIndex];
    _playerIndex = (_playerIndex + 1) % _poolSize;
    return player;
  }

  Future<void> _playSound(String assetPath, {double volume = 0.85}) async {
    if (isMuted) return;
    try {
      final player = _getPlayer();
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('SoundService audio playback notice ($assetPath): $e');
    }
  }

  /// SFX: Triggered when a player correctly guesses the secret word!
  Future<void> playCorrectGuess() => _playSound('audio/correct_guess.wav', volume: 0.95);

  /// SFX: Triggered when it's your turn to draw or word selection starts
  Future<void> playTurnStart() => _playSound('audio/turn_start.wav', volume: 0.9);

  /// SFX: Triggered when a new drawing round officially starts
  Future<void> playRoundStart() => _playSound('audio/round_start.wav', volume: 0.85);

  /// SFX: Triggered on the final 5 seconds of the round timer
  Future<void> playClockTick() => _playSound('audio/clock_tick.wav', volume: 0.7);

  /// SFX: Triggered when a chat message or guess attempt arrives
  Future<void> playPopChat() => _playSound('audio/pop_chat.wav', volume: 0.65);

  /// SFX: Triggered when canvas is cleared
  Future<void> playCanvasClear() => _playSound('audio/canvas_clear.wav', volume: 0.8);

  /// SFX: Triggered on UI button and toolbar clicks
  Future<void> playButtonClick() => _playSound('audio/button_click.wav', volume: 0.6);

  /// SFX: Triggered when final leaderboard / game victory is shown
  Future<void> playVictory() => _playSound('audio/game_victory.wav', volume: 0.95);

  void dispose() {
    _bgmPlayer.dispose();
    for (final player in _players) {
      player.dispose();
    }
    _players.clear();
    isMutedNotifier.dispose();
  }
}
