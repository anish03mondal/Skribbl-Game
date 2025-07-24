import 'package:flutter/material.dart';
// as IO is giving nickname to the package
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PaintScreen extends StatefulWidget {
  final Map data;
  final String screenFrom;
  const PaintScreen({super.key, required this.data, required this.screenFrom});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  late IO.Socket _socket;
  String dataOfRoom = "";
  @override
  void initState() {
    super.initState();
    connect();
    print(widget.data);
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

    if (widget.screenFrom == 'createRoom') {
      _socket.emit('create-game', widget.data);
    }

    //listen to socket
    _socket.onConnect((data) {
      print('Connected');
      _socket.on('updateRoom', (roomData) {
        //update or rebuild of ui
        setState(() {
          dataOfRoom = roomData;
        });
        if(roomData['isJoin'] != true)
        {
          //start the timer
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(),
    );
  }
}
