import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController contorller;
  final String hintText;
  const CustomTextField({
    super.key,
    required this.contorller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: contorller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
      ),
    );
  }
}
