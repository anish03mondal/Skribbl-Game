import 'package:flutter/material.dart';
import 'package:skribbl_clone/join_room_screen.dart';
import 'package:skribbl_clone/paint_screen.dart';
import 'package:skribbl_clone/widgets/custom_text_field.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  late String? _maxRoundsValue;
  late String? _roomSizeValue;

  void createRoom() {
    if (_nameController.text.isNotEmpty &&
        _roomNameController.text.isNotEmpty &&
        _maxRoundsValue != null &&
        _roomSizeValue != null) {
      Map data = {
        "nickname": _nameController.text,
        "name": _roomNameController,
        "occupancy": _maxRoundsValue,
        "maxRounds": _roomSizeValue,
      };
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
            PaintScreen(data: data, screenFrom: 'createRoom')
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Create Room',
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

          SizedBox(height: 20),

          DropdownButton<String>(
            focusColor: Color(0xffF5F5FA),
            items: <String>["2", "5", "10", "15"]
                .map<DropdownMenuItem<String>>(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                )
                .toList(),
            hint: Text(
              'Select the number of Rounds',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            onChanged: (String? value) {
              // Handle value change
              setState(() {
                _maxRoundsValue = value;
              });
            },
          ),
          SizedBox(height: 20),

          DropdownButton<String>(
            focusColor: Color(0xffF5F5FA),
            items: <String>["2", "3", "4", "5", "6", "7", "8"]
                .map<DropdownMenuItem<String>>(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                )
                .toList(),
            hint: Text(
              'Select the room size',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            onChanged: (String? value) {
              // Handle value change
              setState(() {
                _roomSizeValue = value;
              });
            },
          ),
          SizedBox(height: 40),

          ElevatedButton(
            onPressed: () {
              createRoom();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text(
              "Create",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
