import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoRecording {
  List<CameraDescription> _cameras;
  CameraController _controller;
  String _dirPath, currentVideoPath;
  CameraDescription _currentCamera;

  Future<void> getFilePath() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    _dirPath = '${extDir.path}/recordings/';
    await Directory(_dirPath).create(recursive: true);
  }

  VideoRecording() {
    initialise();
    getFilePath();
  }

  void initialise() async {
    _cameras = await availableCameras();
    if (_cameras.any((c) => c.lensDirection == CameraLensDirection.front)) {
      _currentCamera = _cameras
          .firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    } else if (_cameras
        .any((c) => c.lensDirection == CameraLensDirection.back)) {
      _currentCamera = _cameras
          .firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    }
    if (_currentCamera != null) {
      _controller = CameraController(_currentCamera, ResolutionPreset.high);
      _controller.initialize().catchError((e) {
        print("Error  $e");
      });
    }
  }

  void changeCamera() {
    if (_currentCamera != null) {
      if (_currentCamera.lensDirection == CameraLensDirection.front) {
        if (_cameras.any((c) => c.lensDirection == CameraLensDirection.back)) {
          _currentCamera = _cameras
              .firstWhere((c) => c.lensDirection == CameraLensDirection.back);
        }
      } else if (_currentCamera.lensDirection == CameraLensDirection.back) {
        if (_cameras.any((c) => c.lensDirection == CameraLensDirection.front)) {
          _currentCamera = _cameras
              .firstWhere((c) => c.lensDirection == CameraLensDirection.front);
        }
      }
    }
    print(_controller);
  }

  bool get isRecording => _controller.value.isRecordingVideo;

  bool get ispaused => _controller.value.isRecordingPaused;

  Future<bool> startRecording(String gameId) async {
    if (_dirPath == null) await getFilePath();
    print(_controller);
    if (_controller != null && !isRecording) {
      currentVideoPath = _dirPath + "$gameId.mp4";
      bool error = false;
      await _controller
          .startVideoRecording(currentVideoPath)
          .catchError((e) async {
        error = true;
        print("error $e");
        if (e.code == "fileExists") {
          await File(currentVideoPath).delete();
          //startRecording(gameId);
        } else if (e.code == "Uninitialized CameraController") {
          await _controller.initialize();
        }
      });
      if (!error) print("Recording Started");
      return !error;
    }
    return false;
  }

  Future<bool> pauseRecording() async {
    if (_controller != null && isRecording) {
      bool error = false;
      await _controller.pauseVideoRecording().catchError((e) {
        error = true;
      });
      if (!error) print("Recording Paused");
      return !error;
    }
    return false;
  }

  Future<bool> resumeRecording() async {
    if (_controller != null && isRecording) {
      bool error = false;
      await _controller.resumeVideoRecording().catchError((e) {
        error = true;
      });
      if (!error) print("Recording Resumed");
      return !error;
    }
    return false;
  }

  Future<bool> stopRecording() async {
    if (_controller != null && isRecording) {
      bool error = false;
      await _controller.stopVideoRecording().catchError((e) {
        error = true;
      });
      if (!error) {
        saveRecording();
      }
      if (!error) print("Recording Stopped");
      return !error;
    }
    return false;
  }

  void saveRecording() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    List<String> videos = pref.getStringList("recordedVideos") ?? [];
    videos.add(currentVideoPath);
    pref.setStringList("recordedVideos", videos);
    print("Recording Saved");
  }
}

class User {
  String name, number;
  ProfilePicData profilePic;
  User({@required this.name, @required this.number, @required this.profilePic});
  User.fromMap(Map<String, dynamic> d, List<ProfilePicData> profilePics) {
    this.name = d['name'];
    this.number = d['number'];
    this.profilePic = ProfilePicData(d['profilePic']);
  }
}

class ProfilePicData {
  String link;
  ProfilePicData.fromMap(Map<String, dynamic> data) {
    this.link = data['link'];
  }
  ProfilePicData(this.link);
}

class Room {
  String id, adminName, adminNumber, name;
  List<String> players;
  DocumentReference ref;
  DocumentReference gamesRef;
  Room(
      {@required this.adminName,
      @required this.adminNumber,
      @required this.id,
      @required this.players,
      @required this.name,
      @required this.ref});

  Room.fromMap(Map<String, dynamic> d, this.ref) {
    this.adminName = d['adminName'];
    this.adminNumber = d['adminNumber'];
    this.name = d['name'];
    this.id = d['id'];
    this.players = List<String>.generate(
        d['players'].length, (i) => d['players'][i].toString());
  }
}

class GameData {
  DateTime created;
  String id, gameType, hostName, hostNumber;
  List<String> players;
  DocumentReference reqRef;
  GameData.fromMap(Map<String, dynamic> d, this.reqRef) {
    this.created = d['created'] != null ? DateTime.parse(d['created']) : null;
    this.id = d['id'].toString();
    this.gameType = d['gameType'].toString();
    this.hostName = d['hostName'].toString();
    this.hostNumber = d['hostNumber'].toString();
    this.players =
        d['players'] != null ? List<String>.from(d['players']) : null;
  }
}

class Message {
  String sender, message;
  DateTime created;
  Message(
      {@required this.sender, @required this.message, @required this.created});
}

class DenData {
  String player, movie;
}

class VideoScreen {
  int uid;
  User player;
  AgoraRenderWidget screen;
  VideoScreen(
      {@required this.uid, @required this.player, @required bool isLocal}) {
    this.screen = AgoraRenderWidget(
      uid,
      local: isLocal,
      preview: !isLocal,
    );
  }
}

var charsData = [
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z'
];

Widget logo(Size size) {
  return Container(
    width: size.width,
    height: 120,
    child: Stack(
      children: [
        Positioned(
          left: size.width / 2,
          right: 60,
          top: 0,
          child: Container(
            width: size.width - 100,
            height: 80,
            alignment: Alignment.centerRight,
            child: Image.asset(
              "assets/name2.png",
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: 50,
          right: 50,
          top: 20,
          child: Container(
            width: size.width - 100,
            height: 100,
            child: Image.asset(
              "assets/name1.png",
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ],
    ),
  );
}

List<String> movies = [
  "Andaz Apna Apna",
  "Golmaal",
  "Bade Miyan Chote Miyan",
  "Hera Pheri",
  "De Dana Dan",
  "Singh is King",
  "Main Hoon Na",
  "Delhi Belly",
  "Mere Baap Pehle Aap",
  "Albert Pinto Ko Gussa Kyon Ata Hai",
  "Luv Shuv Tey Chicken Khurana",
  "Manorama Six Feet Under",
  "Via Darjeeling",
  "36 China Town",
  "Hazaaron Khwaishein Aisi",
  "Hamari Adhuri Kahani",
  "Ajab Prem Ki Ghazab Kahani",
  "Happy Bhag Jayegi",
  "Shubh Mangal Zyada Saavdhan",
  "Yaadon Ki Baaraat",
  "Matru Ki Bijlee Ka Mandola",
  "Malang",
  "Street Dancer",
  "Tanhaji",
  "Chhapaak",
  "Shirin Farhad Ki Toh Nikal Padi",
  "Kabir Singh",
  "URI : The Surgical Strike",
  "Good Newwz",
  "Chhichhore",
  "Dream Girl",
  "marjaavaan",
  "Batla House",
  "The Sky is Pink",
  "Kalank",
  "Manikarnika : The Queen Of Jhansi",
  "Pati Patni Aur Woh",
  "De De Pyaar De",
  "Ek Ladki Ko Dekha Toh Aisa Laga",
  "Luka Chuppi",
  "Lage Raho Munna Bhai",
  "Zindagi Na Milegi Dobara",
  "Dangal",
  "Dear Zindagi",
  "Gangs Of Wasseypur",
  "Hum Aapke Hain Kaun",
  "The Lunchbox",
  "Jab We Met",
  "Rang De Basanti",
  "Patthar Ke Sanam",
  "Black Friday",
  "Kuch Kuch Hota Hai",
  "Omkara",
  "Mera Naam Joker",
  "Kal Ho Na Ho",
  "Bajrangi Bhaijaan",
  "Veer-Zaara",
  "Maine Pyaar Kiya",
  "Udaan",
  "Love Aaj Kal",
  "Haider",
  "Dil Chahta Hai",
  "Drishyam",
  "Guru",
  "Sparsh",
  "Guide",
  "Vaastav",
  "Kaagaz Ke Phool",
  "AirLift",
  "Dhadak",
  "Mumbai Meri Jaan",
  "Befikre",
  "Oye Lucky Lucky Oye",
  "Manjhi : The Mountain Man",
  "Chhoti Si Baat",
  "Dilwale Dulhania Le Jayenge",
  "Parinda",
  "Bajirao Mastani",
  "Vicky Donor",
  "Lootera",
  "Neeraja",
  "Nil Battey Sannata",
  "Pad Man",
  "Jaane Tu Ya Jaane Na",
  "Veere Di Wedding",
  "Sui Dhaaga",
  "Manmarziyaan",
  "Meri Pyaari Bindu",
  "OK Jaanu",
  "Baghban",
  "Jai Ho",
  "Half Girlfriend",
  "Raees",
  "Badrinath Ki Dulhania",
  "Haseena Parker",
  "Hasee Toh Phasee",
  "Mausam",
  "Bareilly Ki Barfi",
  "Phata Poster Nikhla Hero",
  "Main Tera Hero",
];

String defaultProfilePicLink =
    "https://firebasestorage.googleapis.com/v0/b/dumb-charades-a1d05.appspot.com/o/buggsBunny.png?alt=media&token=85b03b9e-e7b1-468b-a15b-0ab86a1a9ea4";

class DrawTriangle extends CustomPainter {
  Paint _paint;
  List<Color> colors;
  DrawTriangle(this.colors) {
    _paint = Paint()..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, _paint..color = colors[0]);

    path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, _paint..color = colors[1]);

    path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, _paint..color = colors[2]);

    path = Path();
    path.moveTo(size.width, size.height);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, _paint..color = colors[3]);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

//Dumb Charades Game, TeamA, TeamB, video Screens....
/*Positioned(
                          left: 5,
                          height: MediaQuery.of(context).size.height * 0.625,
                          width: MediaQuery.of(context).size.width * 0.2,
                          child: Container(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: teamAVideoScreens.length + 1,
                              itemBuilder: (context, i) {
                                if (i == 0)
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Text(
                                      "TEAM A",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  );
                                else {
                                  var pl = teamAVideoScreens[i - 1];
                                  var screen = pl.screen;
                                  if (pl.player.number == den.player)
                                    return Container();
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      LayoutBuilder(
                                        builder: (context, cons) {
                                          double width =
                                              cons.biggest.width - 20;
                                          return Container(
                                            height: width,
                                            width: width,
                                            margin: EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 10),
                                            child: screen,
                                          );
                                        },
                                      ),
                                      Container(
                                        margin:
                                            EdgeInsets.symmetric(vertical: 5),
                                        child: Text(
                                          pl.player.name,
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          right: 5,
                          height: MediaQuery.of(context).size.height * 0.625,
                          width: MediaQuery.of(context).size.width * 0.2,
                          child: Container(
                            child: ListView.builder(
                              itemCount: teamBVideoScreens.length + 1,
                              itemBuilder: (context, i) {
                                if (i == 0)
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Text(
                                      "TEAM B",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  );
                                else {
                                  var pl = teamBVideoScreens[i - 1];
                                  var screen = pl.screen;
                                  if (pl.player.number == den.player)
                                    return Container();
                                  return Column(
                                    children: [
                                      LayoutBuilder(builder: (context, cons) {
                                        double width = cons.biggest.width - 20;
                                        return Container(
                                          height: width,
                                          width: width,
                                          margin: EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 10),
                                          child: screen,
                                        );
                                      }),
                                      Container(
                                        margin:
                                            EdgeInsets.symmetric(vertical: 5),
                                        child: Text(
                                          pl.player.name,
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                       */
