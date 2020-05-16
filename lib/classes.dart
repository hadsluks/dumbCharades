import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  Room(
      {@required this.adminName,
      @required this.adminNumber,
      @required this.id,
      @required this.players,
      @required this.name});

  Room.fromMap(Map<String, dynamic> d) {
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
  String team, player, movie;
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
  "Bade Miyan Chote Miyan"
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
