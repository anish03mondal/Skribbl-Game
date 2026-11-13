import 'package:flutter/material.dart';
import 'package:skribbl_clone/paint_screen.dart';
import 'package:skribbl_clone/services/server_config_service.dart';
import 'package:skribbl_clone/services/sound_service.dart';
import 'package:skribbl_clone/widgets/custom_text_field.dart';

class CreateRoomScreen extends StatefulWidget {
  final String? initialRoomName;
  final String? initialNickname;
  const CreateRoomScreen({super.key, this.initialRoomName, this.initialNickname});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  String? _maxRoundsValue;
  String? _roomSizeValue;

  @override
  void initState() {
    super.initState();
    if (widget.initialNickname != null) {
      _nameController.text = widget.initialNickname!;
    }
    if (widget.initialRoomName != null) {
      _roomNameController.text = widget.initialRoomName!;
    }
    SoundService.instance.playLobbyBgm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  void createRoom() {
    if (_nameController.text.isNotEmpty &&
        _roomNameController.text.isNotEmpty &&
        _maxRoundsValue != null &&
        _roomSizeValue != null) {
      SoundService.instance.playButtonClick();
      SoundService.instance.stopLobbyBgm();
      Map<String, dynamic> data = {
        "nickname": _nameController.text.trim(),
        "name": _roomNameController.text.trim(),
        "occupancy": int.parse(_roomSizeValue!),
        "maxRounds": int.parse(_maxRoundsValue!),
      };
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaintScreen(data: data, screenFrom: 'createRoom'),
        ),
      );
    }
  }

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button, Title & Mute Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Create Room',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.dns_rounded, color: Color(0xFF818CF8), size: 20),
                              tooltip: 'Server Settings',
                              onPressed: () => ServerConfigService.showConfigDialog(context),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: SoundService.instance.isMutedNotifier,
                              builder: (context, isMuted, child) {
                                return IconButton(
                                  icon: Icon(
                                    isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                    color: isMuted ? const Color(0xFF64748B) : const Color(0xFF38BDF8),
                                    size: 22,
                                  ),
                                  tooltip: isMuted ? 'Unmute Sound' : 'Mute Sound',
                                  onPressed: () => SoundService.instance.toggleMute(),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Centered Arcade Pop BGM Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note_rounded, size: 14, color: Color(0xFFEC4899)),
                          SizedBox(width: 5),
                          Text(
                            'Arcade Pop BGM',
                            style: TextStyle(
                              color: Color(0xFFEC4899),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Inputs
                    CustomTextField(
                      contorller: _nameController,
                      hintText: "Enter your nickname",
                    ),

                    const SizedBox(height: 16),

                    CustomTextField(
                      contorller: _roomNameController,
                      hintText: "Enter room name",
                    ),

                    const SizedBox(height: 20),

                    // Dropdown: Max Rounds
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: const Color(0xFF1E293B),
                          isExpanded: true,
                          value: _maxRoundsValue,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF818CF8)),
                          items: <String>["2", "5", "10", "15"]
                              .map<DropdownMenuItem<String>>(
                                (String value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    '$value Rounds',
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                  ),
                                ),
                              )
                              .toList(),
                          hint: const Text(
                            'Select number of Rounds',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          onChanged: (String? value) {
                            setState(() {
                              _maxRoundsValue = value;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dropdown: Room Size
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: const Color(0xFF1E293B),
                          isExpanded: true,
                          value: _roomSizeValue,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF818CF8)),
                          items: <String>["2", "3", "4", "5", "6", "7", "8"]
                              .map<DropdownMenuItem<String>>(
                                (String value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    '$value Players Max',
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                  ),
                                ),
                              )
                              .toList(),
                          hint: const Text(
                            'Select room size',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          onChanged: (String? value) {
                            setState(() {
                              _roomSizeValue = value;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
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
                          onPressed: createRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Create Room",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
