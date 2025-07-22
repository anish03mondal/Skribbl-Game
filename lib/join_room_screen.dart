import 'package:flutter/material.dart';
import 'package:skribbl_clone/widgets/custom_text_field.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  late String? _maxRoundsValue;
  late String? _roomSizeValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Join Room',
            style: TextStyle(fontSize: 30, color: Colors.black),
          ),

          SizedBox(height: MediaQuery.of(context).size.height * 0.08),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            child: CustomTextField(
              contorller: _nameController,
              hintText: "Enter your name",
            ),
          ),
          SizedBox(height: 20),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            child: CustomTextField(
              contorller: _roomNameController,
              hintText: "Enter your room name",
            ),
          ),

          SizedBox(height: 40),

          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text(
              "Join",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
