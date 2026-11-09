import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:skribbl_clone/home_screen.dart';

/// Concept 4: Cosmic Neon Starburst Animated Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _sparksController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Timer> _timers = [];
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Progress Controller (2.4s matching audio)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    // 2. Cosmic Rays Subtle Rotation (continuous)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    // 3. Logo Starburst Pulse Controller (triggered on impact)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 4. Starburst Sparks Explosion Controller
    _sparksController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _progressController.forward();
    _playAudio();

    // Trigger starburst impact animations at t = 1.25s
    _timers.add(Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      _pulseController.forward(from: 0.0);
      _sparksController.forward(from: 0.0);
    }));

    // Auto navigate after completion
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _timers.add(Timer(const Duration(milliseconds: 300), () {
          _navigateToHome();
        }));
      }
    });
  }

  Future<void> _playAudio() async {
    try {
      await _audioPlayer.setVolume(0.9);
      await _audioPlayer.play(AssetSource('audio/starburst_splash.wav'));
    } catch (e) {
      // Graceful fallback for browser autoplay policies
      debugPrint('Audio playback notice: $e');
    }
  }

  void _navigateToHome() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _progressController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _sparksController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: GestureDetector(
        onTap: _navigateToHome, // Tap anywhere to skip into game
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. High-Resolution Starburst Artwork Background
            Image.asset(
              'assets/images/splash_neon_burst.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF2E1065),
                        Color(0xFF0B0F19),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 2. Cosmic Rays / Stardust Tracers Painter
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _StarburstRaysPainter(
                    rotationProgress: _rotationController.value,
                  ),
                );
              },
            ),

            // 3. Starburst Sparks Explosion Painter
            AnimatedBuilder(
              animation: _sparksController,
              builder: (context, child) {
                if (_sparksController.value <= 0.01) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: _StarburstSparksPainter(
                    progress: _sparksController.value,
                  ),
                );
              },
            ),

            // 4. Subtle Dark Bottom Gradient Scrim
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 240,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0B0F19).withValues(alpha: 0.8),
                      const Color(0xFF0B0F19),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Center Content: Metallic SKRIBBL Logo with Starburst Pulse
            Positioned(
              left: 20,
              right: 20,
              bottom: 125,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _progressAnimation,
                  _pulseController,
                ]),
                builder: (context, child) {
                  final double pulse = _pulseController.value;
                  final double progress = _progressAnimation.value;
                  final bool isImpact = pulse > 0.02 && pulse < 0.98;

                  // Starburst impact scale pop
                  final double scale = isImpact
                      ? 1.0 + (math.sin(pulse * math.pi) * 0.16)
                      : (1.0 + 0.02 * math.sin(progress * math.pi));

                  return Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Futuristic Metallic Glowing Logo
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isImpact
                                ? [
                                    const Color(0xFFF472B6), // Neon Pink
                                    const Color(0xFFC084FC), // Violet
                                    const Color(0xFF38BDF8), // Electric Cyan
                                    const Color(0xFFFBBF24), // Amber Gold
                                  ]
                                : [
                                    const Color(0xFFC084FC),
                                    const Color(0xFF818CF8),
                                    const Color(0xFF38BDF8),
                                  ],
                          ).createShader(bounds),
                          child: Text(
                            'SKRIBBL',
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5.0,
                              color: Colors.white,
                              shadows: [
                                BoxShadow(
                                  color: isImpact
                                      ? const Color(0xFFEC4899).withValues(alpha: 0.95)
                                      : const Color(0xFFA855F7).withValues(alpha: 0.8),
                                  blurRadius: isImpact ? 32 : 18,
                                  spreadRadius: isImpact ? 6 : 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Subtitle
                        Text(
                          'Draw. Guess. Win.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.2,
                            color: progress >= 0.9
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 6. Bottom Neon Progress Bar & Status Text
            Positioned(
              left: 32,
              right: 32,
              bottom: 40,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  final double progress = _progressAnimation.value;
                  final String statusText;
                  final Color statusColor;

                  if (progress < 0.3) {
                    statusText = 'Charging cosmic engine...';
                    statusColor = const Color(0xFF38BDF8);
                  } else if (progress < 0.6) {
                    statusText = 'Warping to game lobby...';
                    statusColor = const Color(0xFFA855F7);
                  } else if (progress < 0.92) {
                    statusText = 'Syncing starburst lobby...';
                    statusColor = const Color(0xFFEC4899);
                  } else {
                    statusText = 'Connected! Entering arena... 💥';
                    statusColor = const Color(0xFF10B981);
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing Neon Progress Bar
                      Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.01, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF38BDF8), // Cyan
                                        Color(0xFFA855F7), // Purple
                                        Color(0xFFEC4899), // Pink
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEC4899).withValues(alpha: 0.9),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Status Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for Cosmic Rays & Starburst Tracers
class _StarburstRaysPainter extends CustomPainter {
  final double rotationProgress;

  _StarburstRaysPainter({required this.rotationProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.36);
    final double maxRadius = math.min(size.width * 0.42, 160.0);

    const int rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final double angle = (i / rayCount) * 2 * math.pi + (rotationProgress * 2 * math.pi);
      final double rayLength = maxRadius * (0.6 + 0.4 * math.sin(angle * 2));
      final double endX = center.dx + math.cos(angle) * rayLength;
      final double endY = center.dy + math.sin(angle) * rayLength;

      final Color rayColor = (i % 2 == 0)
          ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
          : const Color(0xFFEC4899).withValues(alpha: 0.15);

      final Paint linePaint = Paint()
        ..color = rayColor
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center, Offset(endX, endY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarburstRaysPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress;
  }
}

// Custom Painter for Starburst Sparks Explosion
class _StarburstSparksPainter extends CustomPainter {
  final double progress;

  _StarburstSparksPainter({required this.progress});

  static const List<Color> _sparkColors = [
    Color(0xFF38BDF8), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFFA855F7), // Violet
    Color(0xFFFBBF24), // Gold
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.36);
    const int count = 28;

    for (int i = 0; i < count; i++) {
      final double angle = (i / count) * 2 * math.pi;
      final double distance = (50.0 + (i % 5) * 22.0) * progress;
      final double px = center.dx + math.cos(angle) * distance;
      final double py = center.dy + math.sin(angle) * distance;

      final double alpha = (1.0 - progress).clamp(0.0, 1.0);
      final Color color = _sparkColors[i % _sparkColors.length];

      final Paint sparkPaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      // Glow halo
      canvas.drawCircle(
        Offset(px, py),
        4.5 * (1.0 - progress * 0.5),
        Paint()
          ..color = color.withValues(alpha: alpha * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );

      // Core particle
      canvas.drawCircle(Offset(px, py), 2.5 * (1.0 - progress * 0.5), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarburstSparksPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
