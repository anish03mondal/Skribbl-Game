import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:skribbl_clone/final_leaderboard.dart';
import 'package:skribbl_clone/home_screen.dart';
import 'package:skribbl_clone/models/my_custom_painter.dart';
import 'package:skribbl_clone/models/touch_points.dart';
import 'package:skribbl_clone/services/server_config_service.dart';
import 'package:skribbl_clone/services/sound_service.dart';
import 'package:skribbl_clone/sidebar/player_scoreboard_drawer.dart';
import 'package:skribbl_clone/waiting_lobby_screen.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PaintScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String screenFrom;
  const PaintScreen({super.key, required this.data, required this.screenFrom});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  late IO.Socket _socket;
  Map dataOfRoom = {};
  List<TouchPoints?> points = [];
  StrokeCap strokeType = StrokeCap.round;
  Color selectedColors = Colors.black;
  double opacity = 1;
  double strokeWidth = 3;
  bool isEraserMode = false;
  Color previousColor = const Color(0xFF6366F1);
  double previousStrokeWidth = 3;
  Set<int> revealedLetterIndices = {};
  bool isRoundBannerVisible = false;
  Timer? _roundBannerTimer;

  static const List<String> _avatarEmojis = [
    '🦊',
    '🐼',
    '🦁',
    '🐸',
    '🚀',
    '🎨',
    '⚡',
    '👑',
    '🦄',
    '🐯',
  ];

  List<Widget> textBlankWidget = [];
  final ScrollController _scrollController = ScrollController();
  List<Map> messaages = [];
  TextEditingController controller = TextEditingController();
  int gussedUserCtr = 0;
  int _start = 90;
  Timer? _timer;
  Timer? _wordChoiceTimer;
  Timer? _turnEndedTimer;
  int _wordChoiceSeconds = 15;
  bool _isWordChoiceDialogOpen = false;
  bool isChoosingWord = false;
  String drawerChoosingName = '';
  bool isTurnEndedOverlay = false;
  String turnEndedWord = '';
  String turnEndedNextDrawer = '';
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map> scoreboard = [];
  bool isTextInputReadOnly = false;
  int maxPoints = 0;
  String winner = '';
  bool isShowFinalLeaderboard = false;
  bool isConnecting = true;
  bool hasConnectionError = false;
  String connectionErrorMessage = '';
  Timer? _connectionTimeoutTimer;
  bool _hasJoinedRoom = false;

  @override
  void initState() {
    super.initState();
    connect();
  }

  void _undoStroke() {
    if (points.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (points.isNotEmpty && points.last == null) {
        points.removeLast();
      }
      while (points.isNotEmpty && points.last != null) {
        points.removeLast();
      }
    });
    _socket.emit('undo-stroke', dataOfRoom['name'] ?? widget.data['name']);
  }

  void _toggleEraser() {
    HapticFeedback.selectionClick();
    setState(() {
      isEraserMode = !isEraserMode;
      if (isEraserMode) {
        previousColor = selectedColors;
        previousStrokeWidth = strokeWidth;
        selectedColors = Colors.white;
        strokeWidth = 22.0;
      } else {
        selectedColors = previousColor;
        strokeWidth = previousStrokeWidth;
      }
    });
    String valueString = selectedColors.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    _socket.emit('color-change', {
      'color': valueString,
      'roomName': dataOfRoom['name'] ?? widget.data['name'],
    });
    _socket.emit('stroke-width', {
      'value': strokeWidth,
      'roomName': dataOfRoom['name'] ?? widget.data['name'],
    });
  }

  void _revealHintLetter() {
    final String word = dataOfRoom['word']?.toString() ?? '';
    if (word.isEmpty) return;

    List<int> eligibleIndices = [];
    for (int i = 0; i < word.length; i++) {
      if (word[i] != ' ' && !revealedLetterIndices.contains(i)) {
        eligibleIndices.add(i);
      }
    }

    if (eligibleIndices.length > 1) {
      eligibleIndices.shuffle();
      final int chosenIndex = eligibleIndices.first;
      if (mounted) {
        setState(() {
          revealedLetterIndices.add(chosenIndex);
          renderTextBlank(word);
        });
        HapticFeedback.lightImpact();
      }
    }
  }

  void startTimer() {
    _timer?.cancel();
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer time) {
      if (_start <= 1) {
        _timer?.cancel();
        final bool isCurrentDrawer = dataOfRoom.isNotEmpty &&
            dataOfRoom['turn'] != null &&
            dataOfRoom['turn']['nickname'] == widget.data['nickname'];
        if (isCurrentDrawer) {
          _socket.emit('change-turn', dataOfRoom['name']);
        }
        if (mounted) {
          setState(() {
            _start = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _start--;
          });
          if (_start == 50 || _start == 25) {
            _revealHintLetter();
          }
          if (_start <= 5 && _start > 0) {
            SoundService.instance.playClockTick();
          }
        }
      }
    });
  }

  void renderTextBlank(String text) {
    textBlankWidget.clear();
    for (int i = 0; i < text.length; i++) {
      if (text[i] == ' ') {
        textBlankWidget.add(const SizedBox(width: 6));
      } else if (revealedLetterIndices.contains(i)) {
        textBlankWidget.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF14B8A6)),
            ),
            child: Text(
              text[i].toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2DD4BF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else {
        textBlankWidget.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Text(
              '_',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }
  }

  void _showWordChoiceDialog(List<String> choices) {
    if (choices.isEmpty || !mounted) return;
    _wordChoiceSeconds = 15;
    bool wordPicked = false;
    _isWordChoiceDialogOpen = true;

    void pickWord(String word) {
      if (wordPicked) return;
      wordPicked = true;
      _wordChoiceTimer?.cancel();
      if (_isWordChoiceDialogOpen && mounted) {
        _isWordChoiceDialogOpen = false;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      _socket.emit('select-word', {
        'roomName': dataOfRoom['name'] ?? widget.data['name'],
        'word': word,
      });
    }

    StateSetter? dialogSetState;
    _wordChoiceTimer?.cancel();
    _wordChoiceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wordChoiceSeconds <= 1) {
        t.cancel();
        pickWord(choices[0]);
      } else {
        _wordChoiceSeconds--;
        if (dialogSetState != null) {
          dialogSetState!(() {});
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
              title: Column(
                children: [
                  const Text(
                    'CHOOSE A WORD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF818CF8)),
                    ),
                    child: Text(
                      '$_wordChoiceSeconds s',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA78BFA),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: choices.map((w) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => pickWord(w),
                      child: Text(
                        w.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    ).then((_) {
      _isWordChoiceDialogOpen = false;
      _wordChoiceTimer?.cancel();
    });
  }

  void connect() {
    _connectionTimeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        isConnecting = true;
        hasConnectionError = false;
        connectionErrorMessage = '';
      });
    }

    final serverUrl = ServerConfigService.instance.serverUrl;

    try {
      _socket.disconnect();
      _socket.dispose();
    } catch (_) {}

    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoconnect': false,
    });
    _socket.connect();

    // 7-second watchdog timer to detect unresponsive connection on real phones
    _connectionTimeoutTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && dataOfRoom.isEmpty) {
        setState(() {
          isConnecting = false;
          hasConnectionError = true;
          connectionErrorMessage =
              'Could not connect to game server at $serverUrl within 7 seconds.';
        });
      }
    });

    _socket.onConnect((data) {
      if (!mounted) return;
      if (!_hasJoinedRoom) {
        if (widget.screenFrom == 'createRoom') {
          _socket.emit('create-game', widget.data);
        } else {
          _socket.emit('join-game', widget.data);
        }
      } else {
        // Seamless reconnect after network fluctuation: do NOT emit create-game again!
        _socket.emit('rejoin-game', {
          'nickname': widget.data['nickname'],
          'roomName': dataOfRoom['name'] ?? widget.data['name'],
        });
      }
    });

    _socket.onConnectError((err) {
      if (!mounted) return;
      if (!_hasJoinedRoom) {
        _connectionTimeoutTimer?.cancel();
        setState(() {
          isConnecting = false;
          hasConnectionError = true;
          connectionErrorMessage = 'Connection error: $err';
        });
      }
    });

    _socket.onConnectTimeout((_) {
      if (!mounted) return;
      if (!_hasJoinedRoom) {
        _connectionTimeoutTimer?.cancel();
        setState(() {
          isConnecting = false;
          hasConnectionError = true;
          connectionErrorMessage = 'Connection timed out while reaching $serverUrl';
        });
      }
    });

    _socket.onError((err) {
      if (!mounted) return;
      if (!_hasJoinedRoom && dataOfRoom.isEmpty) {
        _connectionTimeoutTimer?.cancel();
        setState(() {
          isConnecting = false;
          hasConnectionError = true;
          connectionErrorMessage = 'Socket error: $err';
        });
      }
    });

    _socket.on('updateRoom', (roomData) {
      _connectionTimeoutTimer?.cancel();
      if (!mounted) return;
      _hasJoinedRoom = true;
      setState(() {
        isConnecting = false;
        hasConnectionError = false;
        dataOfRoom = roomData;
      });
      if (roomData['players'] != null) {
        scoreboard.clear();
        for (int i = 0; i < roomData['players'].length; i++) {
          scoreboard.add({
            'username': roomData['players'][i]['nickname'],
            'points': roomData['players'][i]['points'].toString(),
          });
        }
      }
      if (mounted) setState(() {});
    });

    _socket.on('start-word-selection', (data) {
      if (!mounted) return;
      SoundService.instance.playTurnStart();
      _timer?.cancel();
      _wordChoiceTimer?.cancel();
      _turnEndedTimer?.cancel();

      setState(() {
        isTurnEndedOverlay = false;
        points.clear();
        isTextInputReadOnly = false;
        gussedUserCtr = 0;
        _start = 90;
        drawerChoosingName = data['drawerNickname'] ?? '';
        isChoosingWord = true;
        if (data['turn'] != null) {
          dataOfRoom['turn'] = data['turn'];
        }
        if (data['currentRound'] != null) {
          dataOfRoom['currentRound'] = data['currentRound'];
        }
        if (data['players'] != null) {
          scoreboard.clear();
          for (var p in data['players']) {
            scoreboard.add({
              'username': p['nickname'],
              'points': p['points'].toString(),
            });
          }
        }
      });

      if (widget.data['nickname'] == data['drawerNickname']) {
        List<String> choices = List<String>.from(data['wordChoices'] ?? []);
        _showWordChoiceDialog(choices);
      }
    });

    _socket.on('round-started', (data) {
      if (!mounted) return;
      SoundService.instance.playRoundStart();
      _wordChoiceTimer?.cancel();
      _turnEndedTimer?.cancel();
      if (_isWordChoiceDialogOpen) {
        _isWordChoiceDialogOpen = false;
        Navigator.of(context, rootNavigator: true).maybePop();
      }

      setState(() {
        isTurnEndedOverlay = false;
        isChoosingWord = false;
        revealedLetterIndices.clear();
        isRoundBannerVisible = true;
        dataOfRoom['word'] = data['word'] ?? '';
        if (data['room'] != null) {
          dataOfRoom = data['room'];
        }
        renderTextBlank(data['word'] ?? '');
        isTextInputReadOnly = false;
        points.clear();
        _start = 90;
      });

      _roundBannerTimer?.cancel();
      _roundBannerTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            isRoundBannerVisible = false;
          });
        }
      });

      _timer?.cancel();
      startTimer();
    });

    _socket.on('undo-stroke', (_) {
      if (!mounted) return;
      setState(() {
        if (points.isNotEmpty && points.last == null) {
          points.removeLast();
        }
        while (points.isNotEmpty && points.last != null) {
          points.removeLast();
        }
      });
    });

    _socket.on('close-guess', (data) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        messaages.add({
          'isClose': true,
          'msg': data['msg'] ?? 'You are very close!',
        });
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 50,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });

    _socket.on('turn-ended', (data) {
      if (!mounted) return;
      _timer?.cancel();
      _wordChoiceTimer?.cancel();
      _turnEndedTimer?.cancel();
      if (_isWordChoiceDialogOpen) {
        _isWordChoiceDialogOpen = false;
        Navigator.of(context, rootNavigator: true).maybePop();
      }

      setState(() {
        turnEndedWord = data['oldWord'] ?? '';
        turnEndedNextDrawer = data['nextDrawer'] ?? '';
        isTurnEndedOverlay = true;
      });

      _turnEndedTimer = Timer(const Duration(milliseconds: 3200), () {
        if (!mounted) return;
        setState(() {
          isTurnEndedOverlay = false;
        });
      });
    });

    _socket.on('points', (point) {
      if (!mounted) return;
      setState(() {
        if (point['details'] != null) {
          final double rawDx = (point['details']['dx']).toDouble();
          final double rawDy = (point['details']['dy']).toDouble();
          final double sourceVw = (point['details']['vw'] ?? kVirtualCanvasWidth).toDouble();
          final double sourceVh = (point['details']['vh'] ?? kVirtualCanvasHeight).toDouble();

          // Normalize to standard virtual coordinates (0..1000, 0..750)
          final double vx = (rawDx / sourceVw) * kVirtualCanvasWidth;
          final double vy = (rawDy / sourceVh) * kVirtualCanvasHeight;

          // Color synchronization
          Color pointColor = selectedColors;
          if (point['details']['color'] != null) {
            try {
              pointColor = Color(int.parse(point['details']['color'].toString(), radix: 16));
            } catch (_) {}
          }

          // Stroke width synchronization
          double pointWidth = strokeWidth;
          if (point['details']['width'] != null) {
            try {
              pointWidth = (point['details']['width']).toDouble();
            } catch (_) {}
          }

          // Scale stroke width to virtual space so it scales identically on all screens
          final double virtualStrokeWidth = pointWidth * (kVirtualCanvasWidth / 360.0);

          points.add(
            TouchPoints(
              points: Offset(vx, vy),
              paint: Paint()
                ..strokeCap = strokeType
                ..isAntiAlias = true
                ..color = pointColor.withValues(alpha: opacity)
                ..strokeWidth = virtualStrokeWidth,
            ),
          );
        } else {
          points.add(null);
        }
      });
    });

    _socket.on('color-change', (colorString) {
      if (!mounted) return;
      int value = int.parse(colorString, radix: 16);
      Color otherColor = Color(value);
      setState(() {
        selectedColors = otherColor;
      });
    });

    _socket.on('stroke-width', (value) {
      if (!mounted) return;
      setState(() {
        strokeWidth = value.toDouble();
      });
    });

    _socket.on('clear-screen', (data) {
      if (!mounted) return;
      SoundService.instance.playCanvasClear();
      setState(() {
        points.clear();
      });
    });

    _socket.on('msg', (msgData) {
      if (!mounted) return;
      SoundService.instance.playPopChat();
      setState(() {
        messaages.add(msgData);
        gussedUserCtr = msgData['gussedUserCtr'] ?? gussedUserCtr;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 50,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });

    _socket.on('close-input', (_) {
      if (mounted) {
        SoundService.instance.playCorrectGuess();
        setState(() {
          isTextInputReadOnly = true;
        });
      }
    });

    _socket.on('updateScore', (roomData) {
      if (!mounted) return;
      scoreboard.clear();
      for (int i = 0; i < roomData['players'].length; i++) {
        scoreboard.add({
          'username': roomData['players'][i]['nickname'],
          'points': roomData['players'][i]['points'].toString(),
        });
      }
      if (mounted) setState(() {});
    });

    _socket.on('show-leaderboard', (roomPlayers) {
      if (!mounted) return;
      SoundService.instance.playVictory();
      scoreboard.clear();
      for (int i = 0; i < roomPlayers.length; i++) {
        scoreboard.add({
          'username': roomPlayers[i]['nickname'],
          'points': roomPlayers[i]['points'].toString(),
        });
        if (maxPoints < int.parse(scoreboard[i]['points'])) {
          winner = scoreboard[i]['username'];
          maxPoints = int.parse(scoreboard[i]['points']);
        }
      }
      setState(() {
        _timer?.cancel();
        _wordChoiceTimer?.cancel();
        isShowFinalLeaderboard = true;
      });
    });

    _socket.on('user-disconnected', (data) {
      if (!mounted) return;
      scoreboard.clear();
      for (int i = 0; i < data['players'].length; i++) {
        scoreboard.add({
          'username': data['players'][i]['nickname'],
          'points': data['players'][i]['points'].toString(),
        });
      }
      if (mounted) setState(() {});
    });

    _socket.on('notCorrectGame', (data) {
      if (!mounted) return;
      // Only navigate away if initial room join failed (never joined game)
      if (!_hasJoinedRoom && dataOfRoom.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data?.toString() ?? 'Error entering room'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        debugPrint('Ignored notCorrectGame packet during active session: $data');
      }
    });
  }

  @override
  void dispose() {
    _connectionTimeoutTimer?.cancel();
    try {
      _socket.emit('leave-game', {
        'roomName': dataOfRoom['name'] ?? widget.data['name'],
        'nickname': widget.data['nickname'],
      });
      _socket.disconnect();
      _socket.dispose();
    } catch (_) {}
    _timer?.cancel();
    _wordChoiceTimer?.cancel();
    _turnEndedTimer?.cancel();
    _roundBannerTimer?.cancel();
    _scrollController.dispose();
    controller.dispose();
    super.dispose();
  }

  void selectColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Choose Color', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: selectedColors,
            onColorChanged: (color) {
              setState(() {
                selectedColors = color;
                opacity = 1.0;
              });

              String valueString = color
                  .toARGB32()
                  .toRadixString(16)
                  .padLeft(8, '0')
                  .substring(2);

              _socket.emit('color-change', {
                'color': valueString,
                'roomName': dataOfRoom['name'],
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done', style: TextStyle(color: Color(0xFF818CF8))),
          ),
        ],
      ),
    );
  }

  void _sendGuess(String value) {
    if (value.trim().isNotEmpty) {
      Map map = {
        'username': widget.data['nickname'],
        'msg': value.trim(),
        'word': dataOfRoom['word'],
        'roomName': dataOfRoom['name'] ?? widget.data['name'],
        'gussedUserCtr': gussedUserCtr,
        'totalTime': 90,
        'timeTaken': 90 - _start,
      };
      _socket.emit('msg', map);
      controller.clear();
    }
  }

  Widget _buildTopStatusBar(bool isDrawer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Menu button & Circular Timer
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => scaffoldKey.currentState!.openDrawer(),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<bool>(
                valueListenable: SoundService.instance.isMutedNotifier,
                builder: (context, isMuted, child) {
                  return IconButton(
                    icon: Icon(
                      isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: isMuted ? const Color(0xFF64748B) : const Color(0xFF38BDF8),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: isMuted ? 'Unmute Sound FX' : 'Mute Sound FX',
                    onPressed: () => SoundService.instance.toggleMute(),
                  );
                },
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (_start / 90.0).clamp(0.0, 1.0),
                      strokeWidth: 3.5,
                      backgroundColor: const Color(0xFF334155),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _start <= 15 ? const Color(0xFFEF4444) : const Color(0xFF818CF8),
                      ),
                    ),
                    Text(
                      '${_start}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Center: Round Counter
          Column(
            children: [
              const Text(
                'Round #',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${dataOfRoom['currentRound'] ?? 1}/${dataOfRoom['maxRounds'] ?? 2}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Right: Secret Word / Masked Letters
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Secret word',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              isDrawer
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF818CF8)),
                      ),
                      child: Text(
                        dataOfRoom['word']?.toString().toUpperCase() ?? '',
                        style: const TextStyle(
                          color: Color(0xFFA78BFA),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...textBlankWidget,
                        if ((dataOfRoom['word']?.toString().length ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              '(${dataOfRoom['word']?.toString().length})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatarBar() {
    final players = dataOfRoom['players'] as List? ?? [];
    if (players.isEmpty) return const SizedBox.shrink();

    final List<Color> avatarColors = [
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF38BDF8),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = players[index];
          final String nickname = p['nickname'] ?? 'Player';
          final String points = p['points']?.toString() ?? '0';
          final bool isCurrentDrawer = dataOfRoom['turn'] != null &&
              dataOfRoom['turn']['nickname'] == nickname;
          final Color color = avatarColors[index % avatarColors.length];

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentDrawer
                  ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                  : const Color(0xFF1E293B).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentDrawer
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF334155),
                width: isCurrentDrawer ? 2.0 : 1.0,
              ),
              boxShadow: isCurrentDrawer
                  ? [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withValues(alpha: 0.25),
                      child: Text(
                        _avatarEmojis[index % _avatarEmojis.length],
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    if (isCurrentDrawer)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF38BDF8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.brush, size: 8, color: Colors.black),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: TextStyle(
                        color: isCurrentDrawer ? const Color(0xFF38BDF8) : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$points pts',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingToolbar(bool isDrawer) {
    if (!isDrawer) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.brush_rounded, size: 16, color: Color(0xFF818CF8)),
            const SizedBox(width: 8),
            Text(
              '${dataOfRoom['turn']?['nickname'] ?? 'Player'} is drawing...',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final List<Color> quickPalette = [
      Colors.black,
      Colors.white,
      const Color(0xFF6366F1), // Violet
      const Color(0xFF38BDF8), // Sky Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Crimson Red
    ];

    final List<double> strokeWidths = [2.0, 5.0, 9.0, 15.0];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...quickPalette.map((color) {
                    final bool isSelected = selectedColors == color;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          isEraserMode = false;
                          selectedColors = color;
                          opacity = 1.0;
                        });
                        String valueString = color
                            .toARGB32()
                            .toRadixString(16)
                            .padLeft(8, '0')
                            .substring(2);
                        _socket.emit('color-change', {
                          'color': valueString,
                          'roomName': dataOfRoom['name'] ?? widget.data['name'],
                        });
                        _socket.emit('stroke-width', {
                          'value': strokeWidth,
                          'roomName': dataOfRoom['name'] ?? widget.data['name'],
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF818CF8)
                                : (color == Colors.white
                                    ? Colors.grey.shade400
                                    : Colors.transparent),
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF818CF8).withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, size: 20, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: selectColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 18, color: const Color(0xFF334155)),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Undo stroke',
            icon: const Icon(Icons.undo_rounded, size: 20, color: Color(0xFF38BDF8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _undoStroke,
          ),
          IconButton(
            tooltip: isEraserMode ? 'Switch to Pen' : 'Eraser mode',
            icon: Icon(
              isEraserMode ? Icons.edit_rounded : Icons.auto_fix_normal_rounded,
              size: 20,
              color: isEraserMode ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _toggleEraser,
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 18, color: const Color(0xFF334155)),
          const SizedBox(width: 4),
          PopupMenuButton<double>(
            tooltip: 'Brush size',
            initialValue: strokeWidth,
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            onSelected: (val) {
              setState(() => strokeWidth = val);
              _socket.emit('stroke-width', {
                'value': val,
                'roomName': dataOfRoom['name'] ?? widget.data['name'],
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: strokeWidth.clamp(3.0, 10.0),
                    height: strokeWidth.clamp(3.0, 10.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
            itemBuilder: (context) => strokeWidths.map((w) {
              return PopupMenuItem<double>(
                value: w,
                child: Row(
                  children: [
                    Container(
                      width: w.clamp(3.0, 12.0),
                      height: w.clamp(3.0, 12.0),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${w.toInt()} px', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 18, color: const Color(0xFF334155)),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Clear canvas',
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              SoundService.instance.playCanvasClear();
              _socket.emit('clean-screen', dataOfRoom['name'] ?? widget.data['name']);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(bool isDrawer, double canvasHeight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: canvasHeight.isFinite
          ? BoxConstraints(maxHeight: canvasHeight)
          : null,
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: kCanvasAspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double canvasWidth = constraints.maxWidth;
                final double canvasHeight = constraints.maxHeight;

                void emitStrokePoint(Offset localPos) {
                  if (canvasWidth <= 0 || canvasHeight <= 0) return;
                  final double normX = (localPos.dx / canvasWidth).clamp(0.0, 1.0);
                  final double normY = (localPos.dy / canvasHeight).clamp(0.0, 1.0);
                  final double vx = normX * kVirtualCanvasWidth;
                  final double vy = normY * kVirtualCanvasHeight;

                  String valueString = selectedColors
                      .toARGB32()
                      .toRadixString(16)
                      .padLeft(8, '0')
                      .substring(2);

                  _socket.emit('paint', {
                    'details': {
                      'dx': vx,
                      'dy': vy,
                      'vw': kVirtualCanvasWidth,
                      'vh': kVirtualCanvasHeight,
                      'color': valueString,
                      'width': strokeWidth,
                    },
                    'roomName': dataOfRoom['name'] ?? widget.data['name'],
                  });
                }

                return GestureDetector(
                  onPanStart: isDrawer
                      ? (details) => emitStrokePoint(details.localPosition)
                      : null,
                  onPanUpdate: isDrawer
                      ? (details) => emitStrokePoint(details.localPosition)
                      : null,
                  onPanEnd: isDrawer
                      ? (details) {
                          _socket.emit('paint', {
                            'details': null,
                            'roomName': dataOfRoom['name'] ?? widget.data['name'],
                          });
                        }
                      : null,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: MyCustomPainter(
                        pointLists: points,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatFeed() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: messaages.length,
      itemBuilder: (context, index) {
        final msg = messaages[index];
        final bool isCorrect = msg['isCorrect'] == true;
        final bool isClose = msg['isClose'] == true;

        if (isCorrect) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF065F46).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF34D399), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF34D399),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg['msg']?.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (isClose) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF78350F).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  color: Color(0xFFFBBF24),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg['msg']?.toString() ?? "You're very close!",
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.4)),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${msg['username'] ?? ''}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA78BFA),
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: msg['msg']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuessInputField(bool isDrawer) {
    if (isDrawer) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: const Text(
          'Draw the secret word above for everyone to guess!',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final List<String> quickReactions = ['🔥', '😂', '👏', '🎨', '🤔', '⏰', '🎉'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick reaction emoji chips
        Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickReactions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final emoji = quickReactions[i];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isTextInputReadOnly
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _sendGuess(emoji);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  readOnly: isTextInputReadOnly,
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (value) {
                    HapticFeedback.lightImpact();
                    _sendGuess(value);
                  },
                  autocorrect: false,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: isTextInputReadOnly
                        ? 'You already guessed correctly! 🎉'
                        : 'Type your guess here...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isTextInputReadOnly
                          ? const Color(0xFF34D399)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: isTextInputReadOnly
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _sendGuess(controller.text);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Send',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.send_rounded, color: Colors.white, size: 13),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoundBanner() {
    if (!isRoundBannerVisible) return const SizedBox.shrink();
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFDE047), size: 22),
              const SizedBox(width: 8),
              Text(
                'Round ${dataOfRoom['currentRound'] ?? 1} of ${dataOfRoom['maxRounds'] ?? 2}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDrawer = dataOfRoom.isNotEmpty &&
        dataOfRoom['turn'] != null &&
        dataOfRoom['turn']['nickname'] == widget.data['nickname'];

    final bool isHost = (dataOfRoom['players'] as List? ?? []).any(
          (p) => p['nickname'] == widget.data['nickname'] && (p['isPartyLeader'] == true),
        ) || (widget.screenFrom == 'createRoom');

    return Scaffold(
      key: scaffoldKey,
      drawer: PlayerScore(scoreboard),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Deep Slate
              Color(0xFF1E1B4B), // Dark Violet
              Color(0xFF0B0F19), // Midnight
            ],
          ),
        ),
        child: dataOfRoom.isNotEmpty
            ? dataOfRoom['isJoin'] != true
                ? !isShowFinalLeaderboard
                    ? SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isDesktop = constraints.maxWidth > 850;
                            final double screenHeight = constraints.maxHeight;
                            final double canvasHeight = isDesktop
                                ? 440
                                : (screenHeight * 0.36).clamp(220.0, 360.0);

                            if (isDesktop) {
                              // Responsive Desktop Web layout
                              return Center(
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 1100),
                                  child: Stack(
                                    children: [
                                      Column(
                                        children: [
                                          _buildTopStatusBar(isDrawer),
                                          _buildPlayerAvatarBar(),
                                          const SizedBox(height: 6),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                // Left: Canvas & Toolbar
                                                Expanded(
                                                  flex: 6,
                                                  child: Column(
                                                    children: [
                                                      Expanded(
                                                        child: _buildCanvas(isDrawer, double.infinity),
                                                      ),
                                                      _buildFloatingToolbar(isDrawer),
                                                    ],
                                                  ),
                                                ),
                                                // Right: Chat & Guess Input
                                                Expanded(
                                                  flex: 4,
                                                  child: Column(
                                                    children: [
                                                      Expanded(child: _buildChatFeed()),
                                                      _buildGuessInputField(isDrawer),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isTurnEndedOverlay)
                                        _buildTurnEndedOverlay(),
                                      _buildRoundBanner(),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Mobile Android layout (9:16 portrait)
                            return Stack(
                              children: [
                                Column(
                                  children: [
                                    _buildTopStatusBar(isDrawer),
                                    if (isChoosingWord)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFF59E0B),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isDrawer
                                                  ? 'Choose a word above...'
                                                  : '$drawerChoosingName is choosing a word...',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    _buildCanvas(isDrawer, canvasHeight),
                                    _buildFloatingToolbar(isDrawer),
                                    _buildPlayerAvatarBar(),
                                    Expanded(
                                      child: _buildChatFeed(),
                                    ),
                                    _buildGuessInputField(isDrawer),
                                  ],
                                ),
                                if (isTurnEndedOverlay)
                                  _buildTurnEndedOverlay(),
                                _buildRoundBanner(),
                              ],
                            );
                          },
                        ),
                      )
                    : FinalLeaderboard(
                        scoreboard,
                        winner,
                        roomName: dataOfRoom['name']?.toString() ?? widget.data['name']?.toString(),
                        nickname: widget.data['nickname']?.toString(),
                      )
                : WaitingLobbyScreen(
                    occupancy: int.tryParse(dataOfRoom['occupancy'].toString()) ?? 2,
                    noOfPlayers: (dataOfRoom['players'] as List).length,
                    lobbyName: dataOfRoom['name']?.toString() ?? '',
                    players: dataOfRoom['players'] ?? [],
                    isHost: isHost,
                    onStartGameNow: () {
                      _socket.emit('start-game-now', dataOfRoom['name'] ?? widget.data['name']);
                    },
                  )
            : hasConnectionError
                ? _buildConnectionErrorView()
                : _buildConnectingView(),
      ),
    );
  }

  Widget _buildTurnEndedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            elevation: 12,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_off_outlined,
                    size: 48,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The word was "$turnEndedWord"',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$turnEndedNextDrawer will draw next!',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectingView() {
    final serverUrl = ServerConfigService.instance.serverUrl;
    final isCreate = widget.screenFrom == 'createRoom';
    final roomName = widget.data['name'] ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF818CF8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isCreate ? 'Creating Room "$roomName"...' : 'Joining Room "$roomName"...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_sync_rounded, color: Color(0xFF818CF8), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Server: $serverUrl',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                _connectionTimeoutTimer?.cancel();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
              label: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionErrorView() {
    final serverUrl = ServerConfigService.instance.serverUrl;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFF87171),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connection Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Could not reach game server at:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  serverUrl,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Troubleshooting checklist:',
                      style: TextStyle(
                        color: Color(0xFFA78BFA),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Phone and PC must be on the SAME Wi-Fi.\n'
                      '• Server must be running (`node index.js`).\n'
                      '• Check Windows Firewall on port 3000.',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Change IP Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.settings_ethernet_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Change Server IP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () async {
                    await ServerConfigService.showConfigDialog(context);
                    if (mounted) connect();
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Retry Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Retry Connection',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: connect,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Back to Main Menu',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
