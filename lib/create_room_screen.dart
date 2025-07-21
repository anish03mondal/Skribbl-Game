import 'package:flutter/material.dart';
import 'package:skribbl_clone/widgets/custom_text_field.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
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
        ],
      ),
    );
  }
}
