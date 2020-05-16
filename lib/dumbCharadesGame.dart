import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dumbCharades/classes.dart';
import 'package:flutter/material.dart';

class DumbCharadesGame extends StatefulWidget {
  final int myVideoId;
  final List<User> teamA, teamB;
  final bool isAdmin;
  final String gameId;
  final User me;
  final DocumentReference denRef;
  DumbCharadesGame({
    @required this.myVideoId,
    @required this.teamA,
    @required this.teamB,
    @required this.isAdmin,
    @required this.gameId,
    @required this.me,
    @required this.denRef,
  });
  @override
  _DumbCharadesGameState createState() => _DumbCharadesGameState(
        gameId: gameId,
        isAdmin: isAdmin,
        me: me,
        myVideoId: myVideoId,
        teamA: teamA,
        teamB: teamB,
      );
}

class _DumbCharadesGameState extends State<DumbCharadesGame> {
  final _remoteUsers = List<int>();
  bool _isInChannel = false;
  final int myVideoId;
  final List<User> teamA, teamB;
  final bool isAdmin;
  final String gameId;
  final User me;
  _DumbCharadesGameState({
    @required this.myVideoId,
    @required this.teamA,
    @required this.teamB,
    @required this.isAdmin,
    @required this.gameId,
    @required this.me,
  });

  StreamSubscription gameSubs;

  final DenData den = new DenData();
  List<VideoScreen> teamAVideoScreens, teamBVideoScreens;

  List<Message> answers;
  TextEditingController ansCont;
  FocusNode ansFocus;
  bool answering = false;
  List<String> suggestionList;
  String myTeam;

  void subscribeGameCollection() {
    gameSubs = Firestore.instance
        .collection(widget.gameId)
        .snapshots()
        .listen(spRecieved);
  }

  void spRecieved(QuerySnapshot sp) {
    sp.documentChanges.forEach((doc) {
      var d = doc.document.data;
      if (d['type'] == "den") {
        String answerBy = d['answerBy'].toString();
        if (answerBy != null && myTeam == den.team) {
          gotCorrectAnswer(answerBy);
        }
        den.team = d['team'];
        den.player = d['player'];
        den.movie = d['movie'];
      } else if (d['type'] == 'answer') {
        DateTime dt;
        if (d['created'] != null) dt = DateTime.parse(d['created'].toString());
        if (dt != null && dt.difference(DateTime.now()).inSeconds <= 60) {
          var m = new Message(
              sender: d['sender'].toString(),
              message: d['message'].toString(),
              created: dt);
          answers.add(m);
          if (widget.isAdmin) checkIfCorrectAnswer(m);
        }
      }
      setState(() {});
    });
  }

  void newDen() {
    answers = new List();
  }

  void gotCorrectAnswer(String answerBy) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                height: 100,
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                    Text(
                      "Correct Answer",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            onWillPop: () async => false));
    Timer(Duration(milliseconds: 500), () {
      Navigator.of(context).pop();
    });
  }

  void checkIfCorrectAnswer(Message answer) {
    if (answer.message == den.movie) {
      String team, player, movie;
      if (den.team == "teamA") {
        team = "teamB";
        player = teamB[Random().nextInt(teamB.length)].number;
        while (player == den.player) {
          player = teamB[Random().nextInt(teamB.length)].number;
        }
      } else if (den.team == "teamB") {
        team = "teamA";
        player = teamA[Random().nextInt(teamA.length)].number;
        while (player == den.player) {
          player = teamA[Random().nextInt(teamA.length)].number;
        }
      }
      movie = movies[Random().nextInt(movies.length)];
      while (movie == den.movie) {
        movie = movies[Random().nextInt(movies.length)];
      }
      widget.denRef.updateData({
        'movie': movie,
        'player': player,
        'team': team,
        'answerBy': answer.sender
      });
    }
  }

  void addVideoScreen(int uid) {
    int t = (uid / 100).round(), index = uid % 100;
    if (t == 1) {
      teamAVideoScreens.removeWhere((vs) => vs.uid == uid);
      var p = teamA[index];
      var v = VideoScreen(uid: uid, player: p, isLocal: p.number == me.number);
      teamAVideoScreens.add(v);
    } else if (t == 2) {
      teamBVideoScreens.removeWhere((vs) => vs.uid == uid);
      var p = teamB[index];
      var v = VideoScreen(uid: uid, player: p, isLocal: p.number == me.number);
      teamBVideoScreens.add(v);
    }
  }

  void _toggleChannel() async {
    if (_isInChannel) {
      _isInChannel = false;
      await AgoraRtcEngine.leaveChannel();
      await AgoraRtcEngine.stopPreview();
    } else {
      _isInChannel = true;
      await AgoraRtcEngine.startPreview();
      await AgoraRtcEngine.joinChannel(null, 'harsh', null, widget.myVideoId);
    }
    setState(() {});
  }

  void _addAgoraEventHandlers() {
    AgoraRtcEngine.onJoinChannelSuccess =
        (String channel, int uid, int elapsed) {
      print("Joined Channel $uid");
    };

    AgoraRtcEngine.onLeaveChannel = () {
      setState(() {
        print("Left Channel");
        _remoteUsers.clear();
      });
    };

    AgoraRtcEngine.onUserJoined = (int uid, int elapsed) {
      addVideoScreen(uid);
      setState(() {});
    };

    AgoraRtcEngine.onUserOffline = (int uid, int reason) {
      teamAVideoScreens.removeWhere((vs) => vs.uid == uid);
      teamBVideoScreens.removeWhere((vs) => vs.uid == uid);
      setState(() {});
    };

    AgoraRtcEngine.onFirstRemoteVideoFrame =
        (int uid, int width, int height, int elapsed) {
      print("First Remote Video Frame Rendered");
    };
  }

  Future<void> _initAgoraRtcEngine() async {
    await AgoraRtcEngine.create('c16abbe55c284c0e84adaec9247b1d6b');
    await AgoraRtcEngine.enableVideo();
    await AgoraRtcEngine.enableAudio();
    // AgoraRtcEngine.setParameters('{\"che.video.lowBitRateStreamParameter\":{\"width\":320,\"height\":180,\"frameRate\":15,\"bitRate\":140}}');
    await AgoraRtcEngine.setChannelProfile(ChannelProfile.Communication);
    VideoEncoderConfiguration config = VideoEncoderConfiguration();
    config.orientationMode = VideoOutputOrientationMode.FixedPortrait;
    await AgoraRtcEngine.setVideoEncoderConfiguration(config);
    _addAgoraEventHandlers();
    addVideoScreen(myVideoId);
    _toggleChannel();
  }

  @override
  void initState() {
    super.initState();
    teamAVideoScreens = new List<VideoScreen>();
    teamBVideoScreens = new List<VideoScreen>();
    answers = new List();
    ansCont = new TextEditingController(text: "");
    ansFocus = new FocusNode();
    suggestionList = new List();
    if (teamA.any((pl) => pl.number == me.number))
      myTeam = "teamA";
    else if (teamB.any((pl) => pl.number == me.number)) myTeam = "teamB";
    _initAgoraRtcEngine();
    subscribeGameCollection();
  }

  @override
  void dispose() {
    gameSubs.cancel();
    if (_isInChannel) _toggleChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMyDen = den.player == me.number, isMyTeamDen = den.team == myTeam;
    AgoraRenderWidget denPlayerRtcWidget;
    if (den.team == "teamA") {
      if (teamAVideoScreens.any((pl) => pl.player.number == den.player))
        denPlayerRtcWidget = teamAVideoScreens
            .firstWhere((pl) => pl.player.number == den.player)
            .screen;
    } else if (den.team == "teamB") {
      if (teamBVideoScreens.any((pl) => pl.player.number == den.player))
        denPlayerRtcWidget = teamBVideoScreens
            .firstWhere((pl) => pl.player.number == den.player)
            .screen;
    }
    bool validAnswer = movies.contains(ansCont.value.text);

    var denPlayerName;
    if (den != null)
      denPlayerName =
          (teamA + teamB).firstWhere((pl) => pl.number == den.player).name;
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: GestureDetector(
          onTap: () {
            if (!FocusScope.of(context).hasPrimaryFocus)
              FocusScope.of(context).unfocus();
            setState(() {
              answering = false;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xfffec183), Color(0xffff1572)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Spacer(),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.625,
                    child: Stack(
                      children: [
                        Container(
                          child: denPlayerRtcWidget != null
                              ? Column(
                                  children: [
                                    isMyTeamDen && !isMyDen
                                        ? Text(
                                            "Guess the Movie Name ..",
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                            ),
                                          )
                                        : RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: den.movie,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    Expanded(
                                      flex: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border:
                                              Border.all(color: Colors.white),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: denPlayerRtcWidget,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: EdgeInsets.symmetric(vertical: 5),
                                      child: Text(
                                        denPlayerName,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : SizedBox.expand(
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 100),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white),
                                      color: Colors.black,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
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
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        !(answering && suggestionList.length > 0)
                            ? Expanded(
                                child: Container(
                                  padding: EdgeInsets.only(
                                      top: 10, bottom: 5, left: 10, right: 10),
                                  margin: EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ListView.builder(
                                    itemBuilder: (context, i) {
                                      if (i == 0)
                                        return Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          child: Text(
                                            "Answers:",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    TextDecoration.underline),
                                          ),
                                        );
                                      Message m = answers[i - 1];
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: m.sender + ": ",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
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
                                      );
                                    },
                                    itemCount: answers.length + 1,
                                  ),
                                ),
                              )
                            : Expanded(
                                child: Container(
                                  padding: EdgeInsets.only(
                                      top: 10, bottom: 5, left: 10, right: 10),
                                  margin: EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ListView.builder(
                                    itemCount: suggestionList.length,
                                    itemBuilder: (context, i) {
                                      return GestureDetector(
                                        onTap: () {
                                          FocusScope.of(context).unfocus();
                                          setState(() {
                                            ansCont.text = suggestionList[i];
                                            suggestionList = new List();
                                            answering = false;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 3, horizontal: 10),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                  width: 0.5,
                                                  color: Colors.grey[300]),
                                            ),
                                          ),
                                          child: Text(suggestionList[i]),
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
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white,
                                  ),
                                  child: TextField(
                                    controller: ansCont,
                                    focusNode: ansFocus,
                                    enableInteractiveSelection: false,
                                    enabled:
                                        isMyTeamDen && !isMyDen && !validAnswer,
                                    onTap: () {
                                      setState(() {
                                        answering = true;
                                      });
                                    },
                                    onChanged: (s) {
                                      setState(() {
                                        if (s.length > 0) {
                                          suggestionList =
                                              new List.from(movies);
                                          suggestionList.retainWhere((m) => (m
                                              .toLowerCase()
                                              .startsWith(s.toLowerCase())));
                                        } else
                                          answering = false;
                                      });
                                    },
                                    onEditingComplete: () {
                                      setState(() {
                                        answering = false;
                                      });
                                    },
                                    onSubmitted: (s) {
                                      setState(() {
                                        answering = false;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      hintText: "Your Answer Here...",
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              validAnswer
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        ansCont.clear();
                                        setState(() {});
                                      },
                                    )
                                  : SizedBox(),
                              Expanded(
                                child: IconButton(
                                  icon: Icon(Icons.send,
                                      color: validAnswer
                                          ? Colors.white
                                          : Colors.grey[500]),
                                  onPressed: validAnswer
                                      ? () {
                                          if (ansCont.value.text.length > 0) {
                                            ansFocus.unfocus();
                                            Firestore.instance
                                                .collection(widget.gameId)
                                                .add({
                                              'type': 'answer',
                                              'sender': me.name,
                                              'message': ansCont.value.text,
                                              'created': DateTime.now()
                                                  .toLocal()
                                                  .toString()
                                            });
                                            ansCont.clear();
                                          }
                                        }
                                      : null,
                                ),
                              ),
                            ],
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
