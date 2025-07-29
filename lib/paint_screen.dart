import 'dart:async';

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
  List<Widget> textBlankWidget = [];
  ScrollController _scrollController = ScrollController();
  List<Map> messaages = [];
  TextEditingController controller = TextEditingController();
  int gussedUserCtr = 0;
  int _start = 90;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    connect();
    print(widget.data);
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer time) {
      if (_start == 0) {
        _socket.emit('change-turn', dataOfRoom['name']);
        setState(() {
          _timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void renderTextBlank(String text) {
    textBlankWidget.clear();
    for (int i = 0; i < text.length; i++) {
      textBlankWidget.add(
        Text(
          '_',
          style: TextStyle(
            fontSize: 30,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
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
        print(roomData['word']);
        setState(() {
          renderTextBlank(roomData['word']);
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
      _socket.on('stroke-width', (value) {
        setState(() {
          strokeWidth = value.toDouble();
        });
      });

      _socket.on('clear-screen', (data) {
        setState(() {
          points.clear();
        });
      });

      _socket.on('msg', (msgData) {
        setState(() {
          messaages.add(msgData);
          gussedUserCtr = msgData['gussedUserCtr'];
        });

        if (gussedUserCtr == dataOfRoom['players'].length - 1) {
          _socket.emit('change-turn', dataOfRoom['name']);
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 40,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      });

      _socket.on('change-turn', (data) {
        String oldWord = dataOfRoom['word'];
        showDialog(
          context: context,
          builder: (context) {
            Future.delayed(Duration(seconds: 3), () {
              setState(() {
                dataOfRoom = data;
                renderTextBlank(data['word']);
                gussedUserCtr = 0;
                _start = 90;
                points.clear();
              });
              Navigator.of(context).pop();
            });
            return AlertDialog(title: Center(child: Text('Word was $oldWord')));
          },
        );
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
                setState(() {
                  selectedColors = color;
                  opacity =
                      1.0; // Optional: Reset to full opacity to avoid fading
                });

                String valueString = color.value
                    .toRadixString(16)
                    .padLeft(8, '0')
                    .substring(2);

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
      body: SafeArea(
        child: Column(
          children: [
            // Drawing canvas
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.55,
              child: GestureDetector(
                onPanUpdate: (details) {
                  _socket.emit('paint', {
                    'details': {
                      'dx': details.localPosition.dx,
                      'dy': details.localPosition.dy,
                    },
                    'roomName': widget.data['name'],
                  });
                },
                onPanStart: (details) {
                  _socket.emit('paint', {
                    'details': {
                      'dx': details.localPosition.dx,
                      'dy': details.localPosition.dy,
                    },
                    'roomName': widget.data['name'],
                  });
                },
                onPanEnd: (details) {
                  _socket.emit('paint', {
                    'details': null,
                    'roomName': widget.data['name'],
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: MyCustomPainter(pointLists: points),
                    ),
                  ),
                ),
              ),
            ),

            // Controls row (color picker, slider, clear)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.color_lens, color: selectedColors),
                    onPressed: selectColor,
                  ),
                  Expanded(
                    child: Slider(
                      min: 1.0,
                      max: 10.0,
                      label: "strokeWidth $strokeWidth",
                      activeColor: selectedColors,
                      value: strokeWidth,
                      onChanged: (value) {
                        Map map = {
                          'value': value,
                          'roomName': dataOfRoom['name'],
                        };
                        _socket.emit('stroke-width', map);
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.layers_clear, color: selectedColors),
                    onPressed: () {
                      _socket.emit('clean-screen', dataOfRoom['name']);
                    },
                  ),
                ],
              ),
            ),

            // Word blanks just below the slider
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: textBlankWidget.map((widget) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: widget,
                );
              }).toList(),
            ),
            //Displaying messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: messaages.length,
                itemBuilder: (context, index) {
                  var msg = messaages[index].values;
                  return ListTile(
                    title: Text(
                      msg.elementAt(0),
                      style: TextStyle(
                        fontSize: 19,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      msg.elementAt(1),
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8,
              ),
              child: TextField(
                controller: controller,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Map map = {
                      'username': widget.data['nickname'],
                      'msg': value.trim(),
                      'word': dataOfRoom['word'],
                      'roomName': widget.data['name'],
                      'gussedUserCtr': gussedUserCtr,
                    };
                    _socket.emit('msg', map);
                    controller.clear();
                  }
                },
                autocorrect: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: Color(0xffF5F5FA),
                  hintText: 'Your Guess',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            FloatingActionButton(
              onPressed: () {},
              elevation: 7,
              backgroundColor: Colors.white,
              child: Text(
                '$_start',
                style: TextStyle(color: Colors.black, fontSize: 25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
