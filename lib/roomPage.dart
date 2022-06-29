import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dumbCharades/classes.dart';
import 'package:dumbCharades/gameWaitingPage.dart';
import 'package:dumbCharades/truthOrDareGame.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share/share.dart';

enum GameType {
  DumbCharades,
  TruthOrDare,
}

class RoomPage extends StatefulWidget {
  final Room room;
  final User me;
  final List<ProfilePicData> profilePics;
  RoomPage(
      {@required this.room, @required this.profilePics, @required this.me});
  @override
  _RoomPageState createState() =>
      _RoomPageState(room: room, profilePics: profilePics, me: me);
}

class _RoomPageState extends State<RoomPage> with TickerProviderStateMixin {
  final Room room;
  final List<ProfilePicData> profilePics;
  final User me;
  List<User> players;
  List<bool> selected;
  bool gameStarted = false;
  List<GameData> currentGames;
  List<Message> messages = [];
  TextEditingController messCont = new TextEditingController();
  FocusNode messFocus = new FocusNode();
  CollectionReference roomRef;
  StreamSubscription roomSubs;
  DocumentReference gamesDoc;
  TabController cont;
  int tabIndex = 0;
  bool showGameOptions = false;
  _RoomPageState(
      {@required this.room, @required this.profilePics, @required this.me});

  void subscribeRoomCollection() {
    roomSubs = roomRef.snapshots().listen(spRecieved);
  }

  void spRecieved(QuerySnapshot sp) {
    sp.documentChanges.forEach((doc) {
      var d = doc.document.data;
      if (d['type'] == 'message') {
        DateTime dt;
        if (d['created'] != null) dt = DateTime.parse(d['created'].toString());
        if (dt != null && dt.difference(DateTime.now()).inSeconds <= 60) {
          var m = new Message(
              sender: d['sender'], message: d['message'], created: dt);
          messages.add(m);
        }
      } else if (d['type'] == "games") {
        gamesDoc = doc.document.reference;
      }
      setState(() {});
    });
  }

  void getPlayerDetails() async {
    var sp = await Firestore.instance.collection('users').getDocuments();
    room.players.forEach((pl) {
      var d = sp.documents.firstWhere((doc) => doc.data['number'] == pl).data;
      players.add(new User.fromMap(d, profilePics));
      selected.add(false);
    });
    int i = players.indexWhere((u) => u.number == me.number);
    players.insert(0, players.removeAt(i));
    setState(() {});
  }

  void startGame(GameType gameType) async {
    List<String> generateId(int n) {
      List<String> chars = charsData;
      List<String> ids = new List();
      Random r = new Random();
      while (ids.length < 10) {
        String id = "";
        for (int j = 0; j < 8; j++) {
          id += r.nextInt(10).toString();
        }
        if (!(ids.any((i) => i == id))) ids.add(id);
      }
      return ids;
    }

    List<String> reqPls = new List();
    for (int i = 0; i < players.length; i++) {
      if (selected[i]) {
        reqPls.add(players[i].number);
      }
    }
    if (!(reqPls.any((pl) => me.number == pl)))
      reqPls.add(me.number); //adding my number if not present

    if (reqPls.length >= 2) {
      setState(() {
        gameStarted = true;
      });
      var ids = generateId(5);
      var sp = await Firestore.instance.collection('games').getDocuments();
      List<String> regIds =
          sp.documents.map<String>((e) => e.data['id']).toList();
      ids.removeWhere((i) {
        return regIds.contains(i);
      });
      while (ids.length == 0) {
        var ids = generateId(5);
        ids.removeWhere((i) {
          return regIds.contains(i);
        });
      }
      var id = ids[0]; //generated id for the game

      DocumentReference reqRef = roomRef.document();
      await reqRef.setData({
        'id': id,
        'type': 'request',
        'created': DateTime.now().toLocal().toString(),
        'players': reqPls,
        'gameType': gameType == GameType.DumbCharades
            ? 'Dumb Charades'
            : "Truth or Dare",
        'hostName': me.name,
        'hostNumber': me.number,
      });

      if (gamesDoc == null) {
        gamesDoc = await roomRef.add({"type": "games"});
      }

      CollectionReference gameCol = gamesDoc.collection(id);

      await gameCol.add({
        'number': me.number,
        'type': "isAdmin",
      });
      for (var p in reqPls) {
        gameCol.add({
          'number': p,
          'status': "req",
          'type': 'request',
        });
      }
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GameWaitingPage(
            gameId: id,
            gameCol: gameCol,
            gameType: gameType,
            profilePics: profilePics,
            me: me,
            isAdmin: true,
            allPlayers: players,
            reqRef: reqRef,
          ),
        ),
      );
    } else {
      toast("Atleast 2 players are needed for a game of Dumb Charades!!..",
          Toast.LENGTH_LONG);
    }
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

  void getCurrentGames() async {
    var sp =
        await Firestore.instance.collection("room${room.id}").getDocuments();
    sp.documents.forEach((doc) {
      var d = doc.data;
      if (d['type'].toString() == "request") {
        GameData g = new GameData.fromMap(d, doc.reference);
        setState(() {
          if (g.players.contains(me.number)) currentGames.add(g);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    players = new List();
    selected = new List();
    currentGames = new List();
    roomRef = Firestore.instance.collection('room${room.id}');
    cont = new TabController(length: 3, vsync: this);
    cont.addListener(() {
      setState(() {
        tabIndex = cont.index;
      });
    });
    subscribeRoomCollection();
    getPlayerDetails();
    getCurrentGames();
  }

  @override
  void dispose() {
    roomSubs.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    bool anyselected = selected != null && selected.length > 0
        ? selected.any((sel) => sel)
        : false;
    bool isAdmin = me.number == room.adminNumber;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xfffec183),
              Color(0xffff1572),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: isAdmin && !gameStarted && tabIndex == 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 135,
                        width: size.width,
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: Duration(milliseconds: 250),
                              left: showGameOptions ? 20 : size.width / 2 - 90,
                              top: showGameOptions ? 0 : 35,
                              child: GestureDetector(
                                onTap: !showGameOptions
                                    ? null
                                    : () {
                                        startGame(GameType.DumbCharades);
                                      },
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xfffec183),
                                        Color(0xffff1572),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.all(5),
                                  child: showGameOptions
                                      ? Text(
                                          "DUMB\nCHARADES",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: Duration(milliseconds: 250),
                              right: showGameOptions ? 20 : size.width / 2 - 90,
                              top: showGameOptions ? 0 : 35,
                              child: GestureDetector(
                                onTap: !showGameOptions
                                    ? null
                                    : () {
                                        startGame(GameType.TruthOrDare);
                                      },
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xffff1572),
                                        Color(0xfffec183),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.all(5),
                                  child: showGameOptions
                                      ? Text(
                                          "TRUTH\nor\nDARE",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              left: size.width / 2 - 50,
                              top: 20,
                              child: GestureDetector(
                                onTap: () {
                                  if (!anyselected) {
                                    toast("Select players by long pressing one",
                                        Toast.LENGTH_LONG);
                                  } else {
                                    setState(() {
                                      showGameOptions = !showGameOptions;
                                    });
                                  }
                                },
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.asset(
                                    "assets/start.png",
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : gameStarted ? CircularProgressIndicator() : null,
            body: SingleChildScrollView(
              child: Column(
                children: [
                  logo(size),
                  SizedBox(height: 30),
                  Row(
                    children: [
                      Spacer(flex: 3),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 3.0),
                          ),
                          padding: EdgeInsets.only(
                              left: 4, right: 4, bottom: 6, top: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List<Widget>.generate(
                              4,
                              (i) => Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        width: 1.5, color: Colors.white),
                                  ),
                                ),
                                padding: EdgeInsets.only(bottom: 3),
                                child: Text(
                                  room.id[i],
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20),
                                ),
                              ),
                            ),
                          ),
                        ),
                        flex: 3,
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.share,
                          color: Colors.white,
                          size: 35,
                        ),
                        onPressed: () {
                          Share.share(room.id);
                        },
                      ),
                      Spacer(),
                    ],
                  ),
                  SizedBox(height: 30),
                  TabBar(
                    controller: cont,
                    indicatorColor: Colors.white,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                    unselectedLabelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                    isScrollable: true,
                    tabs: [
                      Tab(
                        text: "Members",
                      ),
                      Tab(
                        text: "Messages",
                      ),
                      Tab(
                        text: "Ongoing Games",
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  Container(
                    height: 500,
                    child: TabBarView(
                      controller: cont,
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 3,
                            scrollDirection: Axis.vertical,
                            children:
                                List<Widget>.generate(players.length + 3, (i) {
                              User p = players != null && players.length > i
                                  ? players[i]
                                  : null;
                              if (p == null)
                                return SizedBox(height: 80, width: 80);
                              else
                                return Column(
                                  children: [
                                    GestureDetector(
                                      onLongPress: anyselected
                                          ? null
                                          : () {
                                              setState(() {
                                                selected[i] = true;
                                              });
                                            },
                                      onTap: anyselected
                                          ? () {
                                              setState(() {
                                                selected[i] = !selected[i];
                                              });
                                            }
                                          : null,
                                      child: Stack(
                                        children: <Widget>[
                                              Container(
                                                height: 80,
                                                width: 80,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: p.number == me.number
                                                        ? Colors.blue[600]
                                                        : selected[i]
                                                            ? Colors.green[300]
                                                            : Colors.white,
                                                    width: p.number == me.number
                                                        ? 3
                                                        : selected[i] ? 3 : 1,
                                                  ),
                                                ),
                                                padding: EdgeInsets.all(5),
                                                margin: EdgeInsets.symmetric(
                                                    horizontal: 10),
                                                child: players != null
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(50),
                                                        child:
                                                            CachedNetworkImage(
                                                          imageUrl: p.profilePic
                                                                  .link ??
                                                              defaultProfilePicLink,
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (context, url) =>
                                                                  Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          ),
                                                        ),
                                                      )
                                                    : Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                              ),
                                            ] +
                                            (selected[i]
                                                ? <Widget>[
                                                    Positioned(
                                                      right: 5,
                                                      top: 5,
                                                      child: Container(
                                                        height: 20,
                                                        width: 20,
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: Colors.green,
                                                        ),
                                                        child: Center(
                                                          child: Icon(
                                                            Icons.check,
                                                            color: Colors.white,
                                                            size: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  ]
                                                : <Widget>[]),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 15,
                                    ),
                                    players != null
                                        ? Text(
                                            p.name,
                                            style:
                                                TextStyle(color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : SizedBox(),
                                  ],
                                );
                            }),
                          ),
                        ),
                        Container(
                          height: size.height * 0.4,
                          child: Column(
                            children: [
                              Container(
                                height: size.height * 0.35,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white,
                                ),
                                padding: EdgeInsets.only(
                                    top: 10, bottom: 5, left: 10, right: 10),
                                margin: EdgeInsets.only(
                                    top: 10, bottom: 5, left: 10, right: 10),
                                child: ListView.builder(
                                  itemCount: messages.length,
                                  itemBuilder: (context, i) {
                                    Message m = messages[i];
                                    String time;
                                    var diff =
                                        DateTime.now().difference(m.created);
                                    if (diff.inSeconds <= 60)
                                      time = "${diff.inSeconds} secs";
                                    else if (diff.inMinutes <= 60)
                                      time = "${diff.inMinutes} mins";
                                    else if (diff.inHours <= 24)
                                      time = "${diff.inHours} hours";
                                    else
                                      time = "${diff.inDays} days";
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width -
                                                100,
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: m.sender + ": ",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: m.message,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 50,
                                            child: Text(
                                              time,
                                              textAlign: TextAlign.end,
                                              style: TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.only(
                                  left: 10,
                                  right: 10,
                                  bottom: 5,
                                  top: 5,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Container(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                          left: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          color: Colors.white,
                                        ),
                                        child: TextField(
                                          controller: messCont,
                                          focusNode: messFocus,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            errorBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            focusedErrorBorder:
                                                InputBorder.none,
                                            hintText: "Message",
                                            hintStyle: TextStyle(
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: IconButton(
                                        icon: Icon(Icons.send,
                                            color:
                                                messCont.value.text.isNotEmpty
                                                    ? Colors.white
                                                    : Colors.grey),
                                        onPressed: () {
                                          if (messCont.value.text.isNotEmpty) {
                                            messFocus.unfocus();
                                            roomRef.add({
                                              'type': 'message',
                                              'sender': me.name,
                                              'message': messCont.value.text,
                                              'created': DateTime.now()
                                                  .toLocal()
                                                  .toString()
                                            });
                                            messCont.clear();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: ListView.builder(
                            itemCount: currentGames.length,
                            itemBuilder: (context, i) {
                              var g = currentGames[i];
                              return Container(
                                height: 50,
                                margin: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
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
                                        builder: (context) => GameWaitingPage(
                                          gameCol: gamesDoc.collection(g.id),
                                          gameId: g.id,
                                          gameType:
                                              g.gameType == "Dumb Charades"
                                                  ? GameType.DumbCharades
                                                  : GameType.TruthOrDare,
                                          profilePics: profilePics,
                                          me: me,
                                          allPlayersNumber: g.players,
                                          reqRef: g.reqRef,
                                          isAdmin: g.hostNumber == me.number,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      color: Colors.white,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 15),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          g.gameType,
                                          style: TextStyle(
                                            fontSize: 15,
                                            foreground: Paint()
                                              ..shader = LinearGradient(
                                                colors: [
                                                  Color(0xfffd3e40),
                                                  Color(0xff960e7a),
                                                ],
                                              ).createShader(
                                                Rect.fromLTWH(
                                                    0.0, 0.0, 200.0, 70.0),
                                              ),
                                          ),
                                        ),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: "Admin: ",
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  foreground: Paint()
                                                    ..shader = LinearGradient(
                                                      colors: [
                                                        Color(0xfffd3e40),
                                                        Color(0xff960e7a),
                                                      ],
                                                    ).createShader(
                                                      Rect.fromLTWH(0.0, 0.0,
                                                          200.0, 70.0),
                                                    ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: g.hostName,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  foreground: Paint()
                                                    ..shader = LinearGradient(
                                                      colors: [
                                                        Color(0xfffd3e40),
                                                        Color(0xff960e7a),
                                                      ],
                                                    ).createShader(
                                                      Rect.fromLTWH(0.0, 0.0,
                                                          200.0, 70.0),
                                                    ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
