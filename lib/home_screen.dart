import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          Text(
            "Create/Join Room to play...",
            style: TextStyle(fontSize: 24, color: Colors.black),
          ),

          //It creates a blank space that's 10% of the screen height.
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),

          Row(
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue
                ),
                child: Text("Create", style: TextStyle(color: Colors.white)),
              ),

              ElevatedButton(
                onPressed: () {},
                child: Text("Join", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
