import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dumbCharades/classes.dart';
import 'package:dumbCharades/gameWaitingPage.dart';
import 'package:dumbCharades/roomPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int page = 0;
  User me;
  List<ProfilePicData> profilePics;
  List<Room> myRooms;
  StreamSubscription roomSub;
  List<StreamSubscription> roomSubs;
  bool isInGame = false;

  void getProfilePics() async {
    Firestore firestore = Firestore.instance;
    var sp = await firestore.collection('profilePic').getDocuments();
    sp.documents.forEach((d) {
      profilePics.add(new ProfilePicData.fromMap(d.data));
    });
    getMyAccount();
  }

  void getMyAccount() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    String name = preferences.getString('name'),
        number = preferences.getString('number'),
        profilelink = preferences.getString('profilePic');
    ProfilePicData profile = ProfilePicData(profilelink);
    me = new User(name: name, number: number, profilePic: profile);
    getMyRooms();
  }

  void getMyRooms() async {
    roomSub = Firestore.instance
        .collection('rooms')
        .where('players', arrayContains: me.number)
        .snapshots()
        .listen((sp) {
      sp.documents.forEach((doc) {
        addRoom(new Room.fromMap(doc.data));
      });
      setState(() {});
    });
  }

  addRoom(Room r) {
    if (myRooms.any((rm) => rm.id == r.id)) {
      int i = myRooms.indexWhere((rm) => rm.id == r.id);
      myRooms[i] = r;
    } else {
      myRooms.add(r);
      String id = "room" + r.id;
      roomSubs.add(
          Firestore.instance.collection(id).snapshots().listen(roomSPRecieved));
    }
  }

  void roomSPRecieved(QuerySnapshot sp) {
    sp.documents.forEach((doc) {
      var d = doc.data;
      String type = d['type'].toString(), created = d['created'].toString();
      DateTime dt;
      if (created != null) dt = DateTime.parse(created);
      if (DateTime.now().difference(dt).inMinutes <= 5 &&
          type != null &&
          type == "request" &&
          !isInGame) {
        var players = List<String>.generate(
          d['players'].length,
          (i) => d['players'][i].toString(),
        );
        String hostName = d['hostName'],
            hostNumber = d['hostNumber'],
            gameType = d['gameType'];
        if (players.contains(me.number) && hostNumber != me.number)
          roomRequestDialog(
              d['id'].toString(), players, hostName,hostNumber, gameType, doc.reference);
      }
    });
  }

  void roomRequestDialog(String gameId, List<String> playerNumbers,
      String hostName,String hostNumber, String gameType, DocumentReference reqRef) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        child: Dialog(
          child: Container(
            height: 200,
            width: MediaQuery.of(context).size.width - 50,
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [Color(0xfffec183), Color(0xffff1572)],
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: 5),
                Container(
                  alignment: Alignment.center,
                  child: Text(
                    "Request",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                    ),
                  ),
                ),
                SizedBox(height: 15),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: hostName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(
                        text: " is inviting you for a game of ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      TextSpan(
                        text: gameType,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Number of Players: ${playerNumbers.length}",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 30,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            "Reject",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GameWaitingPage(
                              gameId: gameId,
                              profilePics: profilePics,
                              me: me,
                              allPlayersNumber: playerNumbers,
                              reqRef: reqRef,
                              isAdmin: hostNumber==me.number,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 30,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            "Accept",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onWillPop: () async => false,
      ),
    );
  }

  void toast(String message, Toast length) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.CENTER,
      backgroundColor: Color(0xfff6322a),
      textColor: Colors.white,
      toastLength: length,
    );
  }

  void checkPermissions() async {
    if (!(await Permission.camera.status).isGranted) {
      var st = await Permission.camera.request();
      print(st);
    }
    if (!(await Permission.microphone.status).isGranted) {
      var st = await Permission.microphone.request();
      print(st);
    }
    if (!(await Permission.phone.status).isGranted) {
      var st = await Permission.phone.request();
      print(st);
    }
    if (!(await Permission.storage.status).isGranted) {
      var st = await Permission.storage.request();
      print(st);
    }
  }

  @override
  void initState() {
    super.initState();
    myRooms = new List();
    profilePics = new List();
    roomSubs = new List();
    checkPermissions();
    getProfilePics();
  }

  @override
  void dispose() {
    super.dispose();
    roomSub.cancel();
    roomSubs.forEach((s) => s.cancel());
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Container(
            width: size.width,
            height: 56,
            child: Stack(
              children: [
                Positioned(
                  left: size.width / 2,
                  right: 60,
                  top: 0,
                  child: Container(
                    width: size.width - 100,
                    height: 45,
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
                  top: 5,
                  child: Container(
                    width: size.width - 100,
                    height: 50,
                    child: Image.asset(
                      "assets/name1.png",
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 54,
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xfffec183),
                      Color(0xffff1572),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.all(2),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        colors: [
                          Color(0xfffec183),
                          Color(0xffff1572),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(rect);
                    },
                    child: Icon(
                      Icons.dehaze,
                      size: 35,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
          ],
        ),
        bottomNavigationBar: Container(
          color: Colors.transparent,
          height: size.width / 3,
          width: size.width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Image.asset(
                  "assets/bottom1.png",
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(
                width: 5,
              ),
              Expanded(
                child: Image.asset(
                  "assets/bottom2.png",
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(
                width: 5,
              ),
              Expanded(
                child: Image.asset(
                  "assets/bottom3.png",
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: joinRoom,
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            Color(0xffeec32d),
                            Color(0xfff6322a),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          tileMode: TileMode.clamp,
                        ),
                      ),
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Join Room",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: createRoom,
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            Color(0xfffec183),
                            Color(0xffff1572),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          tileMode: TileMode.clamp,
                        ),
                      ),
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Create Room",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(height: 2, color: Color(0xfffec183)),
                ),
                SizedBox(width: 5),
                Text(
                  "Previous Rooms",
                  style: TextStyle(
                    fontSize: 20,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [
                          Color(0xfffec183),
                          Color(0xffff1572),
                        ],
                      ).createShader(
                        Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                      ),
                  ),
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 2,
                    color: Color(0xffff1572),
                  ),
                ),
              ],
            ),
            Expanded(
              flex: 3,
              child: ListView.builder(
                itemBuilder: (context, i) {
                  if (myRooms.length == 0)
                    return Text(
                      "No Rooms yet\nJoin one of your friend's or create one",
                      textAlign: TextAlign.center,
                    );
                  var r = myRooms[i];
                  return Container(
                    height: 50,
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xffeec32d),
                          Color(0xfff6322a),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        tileMode: TileMode.clamp,
                      ),
                    ),
                    padding: EdgeInsets.all(2),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RoomPage(
                              room: r,
                              profilePics: profilePics,
                              me: me,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: Colors.white,
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                        child: Row(
                          children: [
                            Text(
                              r.name,
                              style: TextStyle(
                                fontSize: 25,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [
                                      Color(0xfffd3e40),
                                      Color(0xff960e7a),
                                    ],
                                  ).createShader(
                                    Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                                  ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                itemCount: myRooms.length > 0 ? myRooms.length : 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void joinRoom() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        String id = "";
        TextEditingController con = new TextEditingController(text: "");
        return Dialog(
          child: Container(
            height: 200,
            width: MediaQuery.of(context).size.width - 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [Color(0xfffec183), Color(0xffff1572)],
              ),
            ),
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                SizedBox(height: 10),
                Text(
                  "Enter Room Number",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Form(
                  child: Container(
                    height: 80,
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 3.0),
                    ),
                    padding:
                        EdgeInsets.only(left: 5, right: 5, bottom: 6, top: 2),
                    child: TextField(
                      onChanged: (s) {
                        id = s;
                      },
                      autofocus: true,
                      maxLength: 4,
                      maxLengthEnforced: true,
                      cursorColor: Colors.white,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 25),
                        counterText: "",
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        disabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedErrorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () async {
                    loadingDialog();
                    print(id);
                    var sp = await Firestore.instance
                        .collection('rooms')
                        .where('id', isEqualTo: id)
                        .getDocuments();
                    if (sp.documents.length == 1) {
                      var d = sp.documents.first.data;
                      List<String> players = new List<String>.generate(
                        d['players'].length,
                        (i) => d['players'][i].toString(),
                      );
                      if (players.contains(me.number)) {
                        toast("Yoy are already a member of the Room",
                            Toast.LENGTH_SHORT);
                      } else {
                        players.add(me.number);
                        await sp.documents.first.reference
                            .updateData({'players': players});
                      }
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    } else {
                      toast("Invalid Room ID", Toast.LENGTH_SHORT);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                    ),
                    child: Text(
                      "Join",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: [Color(0xfffec183), Color(0xffff1572)],
                          ).createShader(
                            Rect.fromLTWH(0.0, 0.0, 100, 40),
                          ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }

  void loadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WillPopScope(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Color(0xffeec32d),
          content: Text(
            "Loading...",
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
        onWillPop: () async => false,
      ),
    );
  }

  void createRoom() {
    List<String> generateId(int n) {
      List<String> chars = charsData;
      List<String> ids = new List();
      Random r = new Random();
      while (ids.length < 10) {
        String id = "";
        for (int j = 0; j < 4; j++) {
          bool isAlph = r.nextBool();
          if (isAlph) {
            id += chars[r.nextInt(26)];
          } else {
            id += r.nextInt(10).toString();
          }
        }
        if (!(ids.any((i) => i == id))) ids.add(id);
      }
      return ids;
    }

    showDialog(
      context: context,
      builder: (context) {
        String name = "";
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Color(0xffeec32d),
          content: TextField(
            decoration: InputDecoration(
              hintText: "Room Name",
            ),
            onChanged: (s) {
              name = s;
            },
          ),
          actions: [
            FlatButton(
              onPressed: () async {
                if (name.length == 0) {
                  toast("Add a name", Toast.LENGTH_SHORT);
                } else {
                  var ids = generateId(10);
                  loadingDialog();
                  var sp = await Firestore.instance
                      .collection('rooms')
                      .getDocuments();
                  List<String> regIds = sp.documents
                      .map<String>((e) => e.data['id'].toString())
                      .toList();
                  ids.removeWhere((i) {
                    return regIds.contains(i);
                  });
                  while (ids.length == 0) {
                    ids = generateId(10);
                    ids.removeWhere((i) {
                      return regIds.contains(i);
                    });
                  }
                  String id = ids[0];
                  await Firestore.instance
                      .collection('rooms')
                      .document()
                      .setData({
                    'adminNumber': me.number,
                    'adminName': me.name,
                    'name': name,
                    'id': id,
                    'players': [me.number],
                  });
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              },
              child: Text(
                "CREATE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
