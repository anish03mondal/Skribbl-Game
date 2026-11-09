import 'package:flutter/material.dart';
import 'package:skribbl_clone/create_room_screen.dart';
import 'package:skribbl_clone/join_room_screen.dart';
import 'package:skribbl_clone/services/server_config_service.dart';
import 'package:skribbl_clone/services/sound_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF0B0F19),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Server Settings Button (Top Left)
              Positioned(
                top: 12,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF334155),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.dns_rounded,
                      color: Color(0xFF818CF8),
                      size: 20,
                    ),
                    tooltip: 'Server Settings',
                    onPressed: () => ServerConfigService.showConfigDialog(context),
                  ),
                ),
              ),

              // Sound Mute/Unmute Toggle (Top Right)
              Positioned(
                top: 12,
                right: 16,
                child: ValueListenableBuilder<bool>(
                  valueListenable: SoundService.instance.isMutedNotifier,
                  builder: (context, isMuted, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF334155),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: isMuted ? const Color(0xFF64748B) : const Color(0xFF38BDF8),
                          size: 20,
                        ),
                        tooltip: isMuted ? 'Unmute Sound' : 'Mute Sound',
                        onPressed: () => SoundService.instance.toggleMute(),
                      ),
                    );
                  },
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    // Glowing Game Logo
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.draw_rounded,
                        size: 64,
                        color: Color(0xFF818CF8),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // App Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF818CF8), Color(0xFFA78BFA), Color(0xFF38BDF8)],
                      ).createShader(bounds),
                      child: const Text(
                        'SKRIBBL',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtitle / Prompt
                    const Text(
                      'Create/Join Room to play...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                SoundService.instance.playButtonClick();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CreateRoomScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                SoundService.instance.playButtonClick();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const JoinRoomScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded,
                                      color: Color(0xFFA78BFA), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Join',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Active Server Indicator / Shortcut
                    ValueListenableBuilder<String>(
                      valueListenable: ServerConfigService.instance.serverUrlNotifier,
                      builder: (context, currentUrl, child) {
                        final displayUrl = currentUrl.isNotEmpty
                            ? currentUrl
                            : ServerConfigService.instance.serverUrl;
                        return InkWell(
                          onTap: () => ServerConfigService.showConfigDialog(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.public_rounded,
                                  size: 14,
                                  color: Color(0xFF818CF8),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Server: $displayUrl',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 12,
                                  color: Color(0xFFA78BFA),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
