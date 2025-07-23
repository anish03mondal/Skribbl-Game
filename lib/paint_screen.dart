import 'package:flutter/material.dart';
// as IO is giving nickname to the package
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PaintScreen extends StatefulWidget {
  const PaintScreen({super.key});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  late IO.Socket _socket;
  @override
  void initState() {
    super.initState();
    connect();
  }

  //Socket io client connection
  //Its purpose is to set up and connect a Socket.IO client to a server.
  void connect() {
    //initializing connection on the backend server running on given ip address and port
    _socket = IO.io('http://10.0.2.2:3000', <String, dynamic>{
      //This tells the socket to use only WebSocket as the transport protocol
      'transports': ['websocket'],
      //Don’t connect immediately after initializing.
      'autoconnect': false,
    });
    //Manually starts the connection to the Socket.IO server.
    _socket.connect();

    //listen to socket
    _socket.onConnect((data) {
      print('Connected');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
