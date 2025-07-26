import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:skribbl_clone/models/my_custom_painter.dart';
import 'package:skribbl_clone/models/touch_points.dart';
// as IO is giving nickname to the package
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PaintScreen extends StatefulWidget {
  final Map<String, String> data;
  final String screenFrom;
  const PaintScreen({super.key, required this.data, required this.screenFrom});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  late IO.Socket _socket;
  Map dataOfRoom = {};
  List<TouchPoints> points = [];
  StrokeCap strokeType = StrokeCap.round;
  Color selectedColors = Colors.black;
  double opacity = 1;
  double strokeWidth = 2;
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
    } else {
      _socket.emit('join-game', widget.data);
    }

    //listen to socket
    _socket.onConnect((data) {
      print('Connected');
      _socket.on('updateRoom', (roomData) {
        //update or rebuild of ui
        setState(() {
          dataOfRoom = roomData;
        });
        if (roomData['isJoin'] != true) {
          //start the timer
        }
      });

      _socket.on('points', (point) {
        if (point['details'] != null) {
          setState(() {
            points.add(
              TouchPoints(
                points: Offset(
                  (point['details']['dx']).toDouble(),
                  (point['details']['dy']).toDouble(),
                ),
                paint: Paint()
                  ..strokeCap = strokeType
                  ..isAntiAlias = true
                  ..color = selectedColors.withOpacity(opacity)
                  ..strokeWidth = strokeWidth,
              ),
            );
          });
        }
      });

      _socket.on('color-change', (colorString) {
        int value = int.parse(colorString, radix: 16);
        Color otherColor = Color(value);
        setState(() {
          selectedColors = otherColor;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    void selectColor() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Choose color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selectedColors,
              onColorChanged: (color) {
                String colorString = color.toHexString();
                //only extract the hex part of colorString
                String valueString = color.value
                    .toRadixString(16)
                    .padLeft(8, '0')
                    .substring(2);

                print(colorString);
                print(valueString);

                Map map = {
                  'color': valueString,
                  'roomName': dataOfRoom['name'],
                };
                _socket.emit('color-change', map);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: width,
                height: height * 0.55,
                child: GestureDetector(
                  //onPanUpdate: Called as the user moves their finger (used for drawing).
                  onPanUpdate: (details) {
                    print(details.localPosition.dx);
                    _socket.emit('paint', {
                      'details': {
                        'dx': details.localPosition.dx,
                        'dy': details.localPosition.dy,
                      },
                      'roomName': widget.data['name'],
                    });
                  },
                  //onPanStart: Called when user starts touching the screen.
                  onPanStart: (details) {
                    print(details.localPosition.dx);
                    _socket.emit('paint', {
                      'details': {
                        'dx': details.localPosition.dx,
                        'dy': details.localPosition.dy,
                      },
                      'roomName': widget.data['name'],
                    });
                  },
                  //onPanEnd: Called when the user lifts their finger.
                  onPanEnd: (details) {
                    _socket.emit('paint', {
                      'details': null,
                      'roomName': widget.data['name'],
                    });
                  },
                  child: SizedBox.expand(
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: MyCustomPainter(pointLists: points),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.55 + 16, // canvas height + margin
            left: 16,
            right: 16,
            child: Row(
              children: [
                //To select the color
                IconButton(
                  icon: Icon(Icons.color_lens, color: selectedColors),
                  onPressed: () {
                    selectColor();
                  },
                ),
                Expanded(
                  //to change the value of stroke width
                  child: Slider(
                    min: 1.0,
                    max: 10.0,
                    label: "strokeWidth $strokeWidth",
                    activeColor: selectedColors,
                    value: strokeWidth,
                    onChanged: (double value) {},
                  ),
                ),
                //To clear the screen
                IconButton(
                  icon: Icon(Icons.layers_clear, color: selectedColors),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
