import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dumbCharades/classes.dart';
import 'package:dumbCharades/dumbCharadesGame.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GameWaitingPage extends StatefulWidget {
  final String gameId;
  final List<ProfilePicData> profilePics;
  final List<String> allPlayersNumber;
  final User me;
  final List<User> allPlayers;
  final DocumentReference reqRef;
  final bool isAdmin;
  GameWaitingPage({
    @required this.gameId,
    @required this.profilePics,
    @required this.me,
    this.allPlayers,
    this.allPlayersNumber,
    this.reqRef,
    @required this.isAdmin,
  });
  @override
  _GameWaitingPageState createState() => _GameWaitingPageState(
      profilePics: profilePics, me: me, allPlayers: allPlayers);
}

class _GameWaitingPageState extends State<GameWaitingPage>
    with TickerProviderStateMixin {
  List<User> allPlayers;
  final List<ProfilePicData> profilePics;
  final User me;
  List<User> playersJoined, playersWaiting;
  List<User> teamA, teamB;
  List<Message> messages;
  _GameWaitingPageState(
      {@required this.profilePics,
      @required this.me,
      @required this.allPlayers});
  StreamSubscription gameSubs;
  TextEditingController messCont;
  FocusNode messFocus;
  bool isAdmin, gameStarted = false;
  Timer startTimer;
  int startSecRem = 0;
  DocumentReference denRef;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  TabController cont;
  int tabIndex = 0;

  void subscribeGameCollection() {
    gameSubs = Firestore.instance
        .collection(widget.gameId)
        .snapshots()
        .listen(spRecieved);
  }

  void spRecieved(QuerySnapshot sp) {
    sp.documentChanges.forEach((doc) {
      var d = doc.document.data;
      if (d['type'] == 'gameStart') {
        gameStarted = true;
        DateTime st = DateTime.parse(d['startTime']);
        startSecRem = st.difference(DateTime.now()).inSeconds;
        startGameTimer();
      } else if (d['type'] == "teamA") {
        List<String> players =
            List<String>.generate(d['players'].length, (i) => d['players'][i]);
        teamA = new List();
        for (var number in players) {
          var user = allPlayers.firstWhere((pl) => pl.number == number);
          if (!teamA.any((pl) => pl.number == number)) teamA.add(user);
        }
      } else if (d['type'] == "teamB") {
        List<String> players =
            List<String>.generate(d['players'].length, (i) => d['players'][i]);
        teamB = new List();
        for (var number in players) {
          var user = allPlayers.firstWhere((pl) => pl.number == number);
          if (!teamB.any((pl) => pl.number == number)) teamB.add(user);
        }
      } else if (d['type'] == "isAdmin" &&
          d['number'].toString() == me.number) {
        isAdmin = true;
      } else if (d['type'] == 'message') {
        DateTime dt;
        if (d['created'] != null) dt = DateTime.parse(d['created'].toString());
        if (dt != null && dt.difference(DateTime.now()).inSeconds <= 60) {
          var m = new Message(
              sender: d['sender'], message: d['message'], created: dt);
          messages.add(m);
        }
      } else if (d['type'] == 'request') {
        var user = allPlayers.firstWhere((pl) => pl.number == d['number']);
        if (user.number == me.number &&
            (d['status'] == "req" ||
                d['status'] == "rej" ||
                d['status'] == "exit")) {
          doc.document.reference.updateData({'status': "acc"});
          playersWaiting.removeWhere((pl) => pl.number == user.number);
          if (!(playersJoined.any((pl) => pl.number == user.number)))
            playersJoined.add(user);
        } else {
          if (d['status'] == "req") {
            playersJoined.removeWhere((pl) => pl.number == user.number);
            if (!(playersWaiting.any((pl) => pl.number == user.number)))
              playersWaiting.add(user);
          } else if (d['status'] == "acc") {
            playersWaiting.removeWhere((pl) => pl.number == user.number);
            if (!(playersJoined.any((pl) => pl.number == user.number)))
              playersJoined.add(user);
          } else if (d['status'] == 'rej' || d['status'] == 'exit') {
            toast("${user.name} rejected the request or exited the game",
                Toast.LENGTH_LONG);
            playersWaiting.removeWhere((pl) => pl.number == user.number);
            playersJoined.removeWhere((pl) => pl.number == user.number);
          }
        }
      }
      setState(() {});
    });
  }

  void startGameTimer() {
    startTimer = new Timer.periodic(Duration(seconds: 1), (t) {
      startSecRem -= 1;
      if (startSecRem <= 0) stopGameTimer();
      if (this.mounted) setState(() {});
    });
  }

  void stopGameTimer() {
    startTimer.cancel();
    int myVideoId;
    if (teamA.any((pl) => pl.number == me.number)) {
      myVideoId = 100 + teamA.indexWhere((pl) => pl.number == me.number);
    } else if (teamB.any((pl) => pl.number == me.number)) {
      myVideoId = 200 + teamB.indexWhere((pl) => pl.number == me.number);
    }
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DumbCharadesGame(
          myVideoId: myVideoId,
          teamA: teamA,
          teamB: teamB,
          isAdmin: widget.isAdmin,
          gameId: widget.gameId,
          me: me,
          denRef: denRef,
        ),
      ),
    );
  }

  void getAllPlayers() async {
    var sp = await Firestore.instance.collection('users').getDocuments();
    widget.allPlayersNumber.forEach((pl) {
      var d = sp.documents.firstWhere((doc) => doc.data['number'] == pl).data;
      allPlayers.add(new User.fromMap(d, profilePics));
    });
    subscribeGameCollection();
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

  @override
  void initState() {
    super.initState();
    messCont = new TextEditingController();
    messages = new List();
    messFocus = new FocusNode();
    playersJoined = new List();
    playersWaiting = new List();
    teamA = new List();
    teamB = new List();
    cont = new TabController(length: 2, vsync: this);
    cont.addListener(() {
      setState(() {
        tabIndex = cont.index;
      });
    });
    isAdmin = widget.isAdmin != null ? widget.isAdmin : false;
    if (allPlayers == null) {
      allPlayers = new List();
      getAllPlayers();
    } else {
      subscribeGameCollection();
    }
  }

  @override
  void dispose() {
    if (gameSubs != null) gameSubs.cancel();
    if (startTimer != null && startTimer.isActive) startTimer.cancel();
    super.dispose();
  }

  void showExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.red,
        title: Text(
          "Sure to Exit?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        content: Text(
          "You can't return to this game again!!",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        actions: [
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
                  "Cancel",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              exitGame();
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
                  "Exit",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void exitGame() async {
    Firestore.instance
        .collection(widget.gameId)
        .where('number', isEqualTo: me.number)
        .getDocuments()
        .then((sp) {
      if (sp.documents.length > 0) {
        var doc = sp.documents.first;
        doc.reference.updateData({'status': "exit"});
      }
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return WillPopScope(
      onWillPop: () async {
        showExitDialog();
        return false;
      },
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xffeec32d),
                Color(0xfff6322a),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              key: scaffoldKey,
              backgroundColor: Colors.transparent,
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
              floatingActionButton: isAdmin && !gameStarted && tabIndex == 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (playersJoined.length >= 4) {
                              startGame();
                            } else {
                              toast(
                                  "Atleast 4 players are needed to start a game",
                                  Toast.LENGTH_LONG);
                            }
                          },
                          child: Container(
                            height: 115,
                            width: 160,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 15,
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
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 15,
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
                                  ),
                                ),
                                Positioned(
                                  left: 25,
                                  top: 0,
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
                              ],
                            ),
                          ),
                        )
                      ],
                    )
                  : null,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                        logo(size),
                        SizedBox(height: 30),
                      ] +
                      (gameStarted
                          ? <Widget>[
                              Container(
                                width: size.width - 50,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        thickness: 1.0,
                                        endIndent: 5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      "Game Starting in:",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Divider(
                                        thickness: 1.0,
                                        color: Colors.white,
                                        indent: 5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              Container(
                                height: 250,
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        scrollDirection: Axis.vertical,
                                        itemCount: teamA.length + 1,
                                        itemBuilder: (context, i) {
                                          if (i == 0)
                                            return Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 5),
                                              child: Text(
                                                "TEAM A",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            );
                                          User p = teamA[i - 1];
                                          return Column(
                                            children: [
                                              Stack(
                                                children: [
                                                  Container(
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color:
                                                              Colors.green[300],
                                                          width: 3),
                                                    ),
                                                    padding: EdgeInsets.all(5),
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10),
                                                    child: playersJoined != null
                                                        ? ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        50),
                                                            child:
                                                                CachedNetworkImage(
                                                              imageUrl: p
                                                                  .profilePic
                                                                  .link,
                                                              fit: BoxFit.cover,
                                                              placeholder:
                                                                  (context,
                                                                          url) =>
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
                                                  Positioned(
                                                    right: 5,
                                                    top: 5,
                                                    child: Container(
                                                      height: 20,
                                                      width: 20,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
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
                                                ],
                                              ),
                                              SizedBox(
                                                height: 15,
                                              ),
                                              playersJoined != null
                                                  ? Text(
                                                      p.name,
                                                      style: TextStyle(
                                                          color: Colors.white),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )
                                                  : SizedBox(),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    Container(
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: VerticalDivider(
                                              thickness: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            startSecRem.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                              child: VerticalDivider(
                                            thickness: 2,
                                            color: Colors.white,
                                          )),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        scrollDirection: Axis.vertical,
                                        itemCount: teamB.length + 1,
                                        itemBuilder: (context, i) {
                                          if (i == 0)
                                            return Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 5),
                                              child: Text(
                                                "TEAM B",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            );
                                          User p = teamB[i - 1];
                                          return Column(
                                            children: [
                                              Stack(
                                                children: [
                                                  Container(
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color:
                                                              Colors.green[300],
                                                          width: 3),
                                                    ),
                                                    padding: EdgeInsets.all(5),
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10),
                                                    child: playersJoined != null
                                                        ? ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        50),
                                                            child:
                                                                CachedNetworkImage(
                                                              imageUrl: p
                                                                  .profilePic
                                                                  .link,
                                                              fit: BoxFit.cover,
                                                              placeholder:
                                                                  (context,
                                                                          url) =>
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
                                                  Positioned(
                                                    right: 5,
                                                    top: 5,
                                                    child: Container(
                                                      height: 20,
                                                      width: 20,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
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
                                                ],
                                              ),
                                              SizedBox(
                                                height: 15,
                                              ),
                                              playersJoined != null
                                                  ? Text(
                                                      p.name,
                                                      style: TextStyle(
                                                          color: Colors.white),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )
                                                  : SizedBox(),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          : <Widget>[
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
                                tabs: [
                                  Tab(
                                    text: "Players",
                                  ),
                                  Tab(
                                    text: "Messages",
                                  ),
                                ],
                              ),
                              SizedBox(height: 30),
                              Container(
                                height: size.height * 0.4,
                                child: TabBarView(
                                  controller: cont,
                                  children: [
                                    GridView.count(
                                      crossAxisCount: 3,
                                      scrollDirection: Axis.vertical,
                                      children: List<Widget>.generate(
                                              playersJoined.length, (i) {
                                            User p = playersJoined != null &&
                                                    playersJoined.length > i
                                                ? playersJoined[i]
                                                : null;
                                            if (p == null)
                                              return SizedBox(
                                                  height: 80, width: 80);
                                            else
                                              return Column(
                                                children: [
                                                  Stack(
                                                    children: [
                                                      Container(
                                                        height: 80,
                                                        width: 80,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                              color: Colors
                                                                  .green[300],
                                                              width: 3),
                                                        ),
                                                        padding:
                                                            EdgeInsets.all(5),
                                                        margin: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 10),
                                                        child:
                                                            playersJoined !=
                                                                    null
                                                                ? ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            50),
                                                                    child:
                                                                        CachedNetworkImage(
                                                                      imageUrl: p
                                                                          .profilePic
                                                                          .link,
                                                                      fit: BoxFit
                                                                          .cover,
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
                                                              color:
                                                                  Colors.white,
                                                              size: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height: 15,
                                                  ),
                                                  playersJoined != null
                                                      ? Text(
                                                          p.name,
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        )
                                                      : SizedBox(),
                                                ],
                                              );
                                          }) +
                                          List<Widget>.generate(
                                              playersWaiting.length, (i) {
                                            User p = playersWaiting != null &&
                                                    playersWaiting.length > i
                                                ? playersWaiting[i]
                                                : null;
                                            if (p == null)
                                              return SizedBox(
                                                  height: 80, width: 80);
                                            else
                                              return Column(
                                                children: [
                                                  Stack(
                                                    children: [
                                                      Container(
                                                        height: 80,
                                                        width: 80,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                              color:
                                                                  Colors.yellow,
                                                              width: 3),
                                                        ),
                                                        padding:
                                                            EdgeInsets.all(5),
                                                        margin: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 10),
                                                        child:
                                                            playersJoined !=
                                                                    null
                                                                ? ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            50),
                                                                    child:
                                                                        CachedNetworkImage(
                                                                      imageUrl: p
                                                                          .profilePic
                                                                          .link,
                                                                      fit: BoxFit
                                                                          .cover,
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
                                                            color:
                                                                Colors.yellow,
                                                          ),
                                                          padding:
                                                              EdgeInsets.all(7),
                                                          child: Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              backgroundColor:
                                                                  Colors.yellow,
                                                              strokeWidth: 1.0,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height: 15,
                                                  ),
                                                  playersWaiting != null
                                                      ? Text(
                                                          p.name,
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        )
                                                      : SizedBox(),
                                                ],
                                              );
                                          }) +
                                          (this.isAdmin
                                              ? <Widget>[
                                                  GestureDetector(
                                                    onTap: addPeople,
                                                    child: Container(
                                                      height: 80,
                                                      width: 80,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                            color: Colors.blue,
                                                            width: 6),
                                                      ),
                                                      padding:
                                                          EdgeInsets.all(5),
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 10),
                                                      child: Icon(
                                                        Icons.add,
                                                        size: 40,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                ]
                                              : <Widget>[]),
                                    ),
                                    Column(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              color: Colors.white,
                                            ),
                                            padding: EdgeInsets.only(
                                                top: 10,
                                                bottom: 5,
                                                left: 10,
                                                right: 10),
                                            margin: EdgeInsets.only(
                                                top: 10,
                                                bottom: 5,
                                                left: 10,
                                                right: 10),
                                            child: ListView.builder(
                                              itemCount: messages.length,
                                              itemBuilder: (context, i) {
                                                Message m = messages[i];
                                                String time;
                                                var diff = DateTime.now()
                                                    .difference(m.created);
                                                if (diff.inSeconds <= 60)
                                                  time =
                                                      "${diff.inSeconds} secs";
                                                else if (diff.inMinutes <= 60)
                                                  time =
                                                      "${diff.inMinutes} mins";
                                                else if (diff.inHours <= 24)
                                                  time =
                                                      "${diff.inHours} hours";
                                                else
                                                  time = "${diff.inDays} days";
                                                return Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Container(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width -
                                                            100,
                                                        child: RichText(
                                                          text: TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text: m.sender +
                                                                    ": ",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text: m.message,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 14,
                                                                  color: Colors
                                                                      .black,
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
                                                          textAlign:
                                                              TextAlign.end,
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
                                                        BorderRadius.circular(
                                                            20),
                                                    color: Colors.white,
                                                  ),
                                                  child: TextField(
                                                    controller: messCont,
                                                    focusNode: messFocus,
                                                    decoration: InputDecoration(
                                                      border: InputBorder.none,
                                                      disabledBorder:
                                                          InputBorder.none,
                                                      enabledBorder:
                                                          InputBorder.none,
                                                      errorBorder:
                                                          InputBorder.none,
                                                      focusedBorder:
                                                          InputBorder.none,
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
                                                      color: Colors.white),
                                                  onPressed: () {
                                                    if (messCont
                                                            .value.text.length >
                                                        0) {
                                                      messFocus.unfocus();
                                                      Firestore.instance
                                                          .collection(
                                                              widget.gameId)
                                                          .add({
                                                        'type': 'message',
                                                        'sender': me.name,
                                                        'message':
                                                            messCont.value.text,
                                                        'created':
                                                            DateTime.now()
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
                                  ],
                                ),
                              ),
                            ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void addPeople() {
    List<User> playersToBeShown = new List.from(allPlayers);
    (playersJoined + playersWaiting).forEach((pl) {
      playersToBeShown.removeWhere((p) => p.number == pl.number);
    });
    List<bool> requests = playersToBeShown.map<bool>((pl) => false).toList();

    Future<void> sendRequest() async {
      var doc = await widget.reqRef.get();
      List<String> players = List.from(doc.data['players']);
      for (int i = 0; i < playersToBeShown.length; i++) {
        var p = playersToBeShown[i];
        if (requests[i]) {
          if (!players.contains(p.number)) {
            players.add(p.number);
            await Firestore.instance.collection(widget.gameId).add({
              'number': p.number,
              'status': "req",
              'type': 'request',
            });
          }
        }
      }
      await widget.reqRef.updateData({'players': players});
    }

    scaffoldKey.currentState.showBottomSheet((context) {
      return AddPeopleBottomSheet(
        playersToBeShown: playersToBeShown,
        requests: requests,
        sendRequests: sendRequest,
      );
    }, backgroundColor: Colors.transparent);
  }

  void startGame() async {
    widget.reqRef.delete();
    Random r = new Random();
    int i;
    while (playersJoined.length > 0) {
      if (teamA.length == teamB.length) {
        i = r.nextInt(playersJoined.length);
        teamA.add(playersJoined.removeAt(i));
      } else if (teamA.length > teamB.length) {
        i = r.nextInt(playersJoined.length);
        teamB.add(playersJoined.removeAt(i));
      }
    }
    var cRef = Firestore.instance.collection(widget.gameId);
    var pl = teamA.map<String>((e) => e.number).toList();
    await cRef.add({'type': 'teamA', 'players': pl});
    pl = teamB.map<String>((e) => e.number).toList();
    await cRef.add({'type': 'teamB', 'players': pl});
    var st = DateTime.now().add(
      Duration(seconds: 15),
    );
    String denTeam = "teamA",
        denPlayer = teamA[r.nextInt(teamA.length)].number,
        movieName = movies[Random().nextInt(movies.length)];
    cRef.add({
      'type': 'gameStart',
      'startTime': st.toLocal().toString(),
    });
    denRef = await cRef.add({
      'type': "den",
      'team': denTeam,
      'player': denPlayer,
      'movie': movieName,
    });
  }
}

class AddPeopleBottomSheet extends StatefulWidget {
  final List<User> playersToBeShown;
  final List<bool> requests;
  final Function sendRequests;
  AddPeopleBottomSheet(
      {@required this.playersToBeShown,
      @required this.requests,
      @required this.sendRequests});
  @override
  _AddPeopleBottomSheetState createState() => _AddPeopleBottomSheetState(
      playersToBeShown: playersToBeShown, requests: requests);
}

class _AddPeopleBottomSheetState extends State<AddPeopleBottomSheet> {
  final List<User> playersToBeShown;
  final List<bool> requests;
  _AddPeopleBottomSheetState(
      {@required this.playersToBeShown, @required this.requests});
  bool sending = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xffeec32d),
            Color(0xfff6322a),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            width: MediaQuery.of(context).size.width / 2,
            child: Divider(
              thickness: 10,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: playersToBeShown.length,
              itemBuilder: (context, i) {
                var p = playersToBeShown[i];
                return Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  margin: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(color: Colors.blue, fontSize: 20),
                      ),
                      RaisedButton(
                        onPressed: () {
                          setState(() {
                            requests[i] = !requests[i];
                          });
                        },
                        child: Text(
                          requests[i] ? "Cancel" : "Request",
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        color: requests[i] ? Colors.red : Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          GestureDetector(
            onTap: sending
                ? null
                : () async {
                    setState(() {
                      sending = true;
                    });
                    await widget.sendRequests();
                    Navigator.of(context).pop();
                  },
            child: Container(
              width: MediaQuery.of(context).size.width - 100,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: sending ? Colors.grey : Colors.blue,
              ),
              alignment: Alignment.center,
              child: Text(
                requests.any((r) => r) ? "Send" : "Done",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
