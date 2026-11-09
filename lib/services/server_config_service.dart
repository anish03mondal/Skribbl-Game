import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfigService {
  ServerConfigService._internal();
  static final ServerConfigService instance = ServerConfigService._internal();

  static const String _prefKey = 'skribbl_server_url';
  
  /// Official worldwide cloud server on Render
  static const String officialCloudUrl = 'https://skribbl-game-1.onrender.com';

  final ValueNotifier<String> serverUrlNotifier = ValueNotifier<String>('');

  String get serverUrl => serverUrlNotifier.value.isNotEmpty
      ? serverUrlNotifier.value
      : officialCloudUrl;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      // If user had an old local loopback or local IP, automatically upgrade them to the worldwide cloud server
      if (saved != null &&
          saved.trim().isNotEmpty &&
          !saved.contains('10.0.2.2') &&
          !saved.contains('192.168.')) {
        serverUrlNotifier.value = _normalizeUrl(saved.trim());
      } else {
        serverUrlNotifier.value = officialCloudUrl;
        await prefs.setString(_prefKey, officialCloudUrl);
      }
    } catch (_) {
      serverUrlNotifier.value = officialCloudUrl;
    }
  }

  Future<void> setServerUrl(String url) async {
    final normalized = _normalizeUrl(url);
    serverUrlNotifier.value = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, normalized);
    } catch (_) {}
  }

  static String _normalizeUrl(String input) {
    String trimmed = input.trim();
    if (trimmed.isEmpty) return officialCloudUrl;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Displays an in-game modal to view and customize the server IP/URL.
  static Future<void> showConfigDialog(BuildContext context) async {
    final controller = TextEditingController(text: instance.serverUrl);
    final focusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.public_rounded, color: Color(0xFF818CF8), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Server Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connected to the global cloud server so anyone in the world can play together across mobile data & Wi-Fi.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        labelText: 'Server URL',
                        labelStyle: const TextStyle(color: Color(0xFF818CF8)),
                        hintText: officialCloudUrl,
                        hintStyle: const TextStyle(color: Color(0xFF475569)),
                        prefixIcon: const Icon(Icons.link, color: Color(0xFF818CF8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Presets:',
                      style: TextStyle(
                        color: Color(0xFFA78BFA),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _presetChip(
                          label: '🌍 Cloud Server (Global)',
                          url: officialCloudUrl,
                          controller: controller,
                          onSelected: () => setDialogState(() {}),
                        ),
                        _presetChip(
                          label: 'PC Wi-Fi (192.168.0.112)',
                          url: 'http://192.168.0.112:3000',
                          controller: controller,
                          onSelected: () => setDialogState(() {}),
                        ),
                        _presetChip(
                          label: 'Emulator (10.0.2.2)',
                          url: 'http://10.0.2.2:3000',
                          controller: controller,
                          onSelected: () => setDialogState(() {}),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await instance.setServerUrl(controller.text);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _presetChip({
    required String label,
    required String url,
    required TextEditingController controller,
    required VoidCallback onSelected,
  }) {
    final bool isSelected = controller.text.trim() == url;
    return InkWell(
      onTap: () {
        controller.text = url;
        onSelected();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? const Color(0xFFA78BFA) : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
