import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dumbCharades/classes.dart';
import 'package:flutter/material.dart';

enum TurnCall { truth, dare }

class Turn {
  String asker, answerer;
  int index;
  bool completed;
  TurnCall call;
  String question, answer;
  bool answerByVideo;
  Turn(this.asker, this.answerer, this.index) {
    completed = false;
    answerByVideo = false;
  }
}

class TruthOrDareGame extends StatefulWidget {
  //final String gameId = "91916330";
  final CollectionReference gameCol;
  final List<User> allPlayers;
  final User me;
  final bool isAdmin;
  TruthOrDareGame(
      {@required this.allPlayers,
      @required this.gameCol,
      @required this.me,
      @required this.isAdmin});
  @override
  _TruthOrDareGameState createState() =>
      _TruthOrDareGameState(allPlayers, gameCol, me, isAdmin);
}

class _TruthOrDareGameState extends State<TruthOrDareGame> {
  _TruthOrDareGameState(this.allPlayers, this.gameCol, this.me, this.isAdmin);
  final List<User> allPlayers;
  List<User> players = [];
  final User me;
  final bool isAdmin;
  Map<String, num> userPos = {};
  BottleWidget bottle = new BottleWidget();
  StreamSubscription gameSubs;
  final CollectionReference gameCol;
  DocumentReference turnRef;
  Turn curTurn;
  TextEditingController quesController = new TextEditingController(),
      ansController = new TextEditingController();

  List<AgoraRenderWidget> videoScreens = [];
  Map<String, int> videoIds = {};
  bool _isInChannel = false;

  void subscribeGameCollection() {
    gameSubs = gameCol.snapshots().listen(spRecieved);
  }

  void spRecieved(QuerySnapshot sp) {
    sp.documentChanges.forEach((doc) {
      var d = doc.document.data;
      if (d['type'] == "players") {
        var list = List<String>.from(d['players']);
        players = [];
        for (var u in list) {
          if (allPlayers.any((element) => element.number == u))
            players
                .add(allPlayers.firstWhere((element) => element.number == u));
        }
        setUserPos();
        setState(() {});
      } else if (d['type'] == "turn") {
        String asker = d['asker'].toString(),
            answerer = d['answerer'].toString();
        print("snapshot asker: $asker,  answerer: $answerer");
        if (curTurn == null || d['index'] > curTurn.index) {
          newTurn(asker, answerer);
          turnRef = doc.document.reference;
        } else {
          curTurn.completed = d['completed'] ?? false;
          curTurn.call = d['call'] == "truth"
              ? TurnCall.truth
              : d['call'] == "dare" ? TurnCall.dare : null;
          curTurn.question = d['question'];
          curTurn.answer = d['answer'];
          if (curTurn.answer == "--video--") {
            curTurn.answerByVideo = true;
          }
          setState(() {});
        }
      }
    });
  }

  void setVideoIds() {
    var list = players.map<String>((e) => e.number).toList();
    list.sort();
    for (int i = 0; i < list.length; i++) {
      videoIds.addAll({list[i]: (i + 1) * 100});
    }
  }

  void addVideoScreen(int uid, {bool isLocal = false}) {
    videoScreens.add(AgoraRenderWidget(
      uid,
      local: isLocal,
    ));
  }

  void _toggleChannel() async {
    if (_isInChannel) {
      _isInChannel = await AgoraRtcEngine.leaveChannel();
      await AgoraRtcEngine.stopPreview();
    } else {
      await AgoraRtcEngine.startPreview();
      _isInChannel = await AgoraRtcEngine.joinChannel(
          null, gameCol.id, null, videoIds[me.number]);
      addVideoScreen(videoIds[me.number], isLocal: true);
    }
  }

  void _addAgoraEventHandlers() {
    AgoraRtcEngine.onJoinChannelSuccess =
        (String channel, int uid, int elapsed) {
      print("Joined Channel $uid");
    };

    AgoraRtcEngine.onLeaveChannel = () {};

    AgoraRtcEngine.onUserJoined = (int uid, int elapsed) {
      addVideoScreen(uid);
      setState(() {});
    };

    AgoraRtcEngine.onUserOffline = (int uid, int reason) {
      videoScreens.removeWhere((element) => element.uid == uid);
      setState(() {});
    };

    AgoraRtcEngine.onFirstRemoteVideoFrame =
        (int uid, int width, int height, int elapsed) {
      print("First Remote Video Frame Rendered");
    };
  }

  Future<void> _initAgoraRtcEngine() async {
    await AgoraRtcEngine.create('c16abbe55c284c0e84adaec9247b1d6b');
    _addAgoraEventHandlers();
    await AgoraRtcEngine.enableVideo();
    await AgoraRtcEngine.enableLocalVideo(false);
    await AgoraRtcEngine.disableAudio();
    AgoraRtcEngine.setParameters(
        '{\"che.video.lowBitRateStreamParameter\":{\"width\":320,\"height\":180,\"frameRate\":15,\"bitRate\":140}}');
    await AgoraRtcEngine.setChannelProfile(ChannelProfile.Communication);
    VideoEncoderConfiguration config = VideoEncoderConfiguration();
    config.orientationMode = VideoOutputOrientationMode.FixedPortrait;
    await AgoraRtcEngine.setVideoEncoderConfiguration(config);
    if (!_isInChannel) _toggleChannel();
  }

  @override
  void initState() {
    super.initState();
    setVideoIds();
    _initAgoraRtcEngine();
    subscribeGameCollection();
  }

  @override
  void dispose() {
    gameSubs.cancel();
    if (_isInChannel) _toggleChannel();
    AgoraRtcEngine.destroy();
    super.dispose();
  }

  void setUserPos() {
    num toRadians(num degree) {
      return degree * 2 * pi / 360;
    }

    var diff = 360 / players.length;
    for (int i = 0; i < players.length; i++) {
      userPos.addAll({players[i].number: toRadians(i * diff)});
    }
  }

  void nextTurn() async {
    int i, j;
    do {
      i = Random().nextInt(players.length);
    } while (curTurn != null && players[i].number == curTurn.answerer);
    String ans, ask;
    int n = (players.length / 2).round(), l = players.length;
    if (players.length % 2 == 0) {
      j = (i + n) % l;
    } else {
      j = (i + n) % l;
      if (j > 0) j -= Random().nextInt(2);
    }
    ans = players[i].number;
    ask = players[j].number;
    print("$i  $j");
    if (turnRef == null) {
      turnRef = await gameCol.add({
        "type": "turn",
        "asker": players[j].number,
        "answerer": players[i].number,
        "index": 0,
        "completed": false,
      });
    } else {
      turnRef.setData({
        "type": "turn",
        "asker": players[j].number,
        "answerer": players[i].number,
        "index": curTurn.index + 1,
        "completed": false,
      });
    }
  }

  void newTurn(String asker, String answerer) async {
    int index = curTurn == null ? 0 : curTurn.index + 1;
    curTurn = new Turn(asker, answerer, index);
    rotateBottle(answerer);
    await Future.delayed(Duration(milliseconds: 2100));
    setState(() {});
  }

  void rotateBottle(String player) {
    double finalPos = 1 - userPos[player] / (2 * pi);
    bottle.rotate(finalPos);
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    double bs = size.width;
    double length = bs - 80;
    bool iamAns = false, iamAsk = false;
    User denPlayer, asker;
    if (curTurn != null &&
        players.any((element) => element.number == curTurn.answerer)) {
      denPlayer =
          players.firstWhere((element) => element.number == curTurn.answerer);
    }
    if (curTurn != null &&
        players.any((element) => element.number == curTurn.asker)) {
      asker = players.firstWhere((element) => element.number == curTurn.asker);
    }
    if (curTurn != null) {
      iamAns = curTurn.answerer == me.number;
      iamAsk = curTurn.asker == me.number;
    }
    return WillPopScope(
      onWillPop: () async {
        showExitDialog();
        return false;
      },
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
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            child: Column(
              children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    Container(
                      height: bs,
                      width: bs,
                      child: Stack(
                        children: <Widget>[
                              Positioned(
                                child: bottle,
                                left: bs / 2 - 60,
                                bottom: bs / 2 - 20,
                              ),
                            ] +
                            new List<Widget>.generate(players.length, (index) {
                              User u = players[index];
                              double left = bs / 2 +
                                      (length / 2) * cos(userPos[u.number]) -
                                      40,
                                  bottom = bs / 2 +
                                      (length / 2) * sin(userPos[u.number]) -
                                      40;
                              left = max(left, 0);
                              bottom = max(bottom, 0);
                              return Positioned(
                                left: left,
                                bottom: bottom,
                                child: UserTile(
                                  players[index],
                                  borderColor: curTurn != null
                                      ? (curTurn.asker == u.number
                                          ? Colors.blue
                                          : curTurn.answerer == u.number
                                              ? Colors.red
                                              : null)
                                      : null,
                                ),
                              );
                            }),
                      ),
                    ),
                    isAdmin
                        ? RaisedButton(
                            onPressed: (turnRef == null ||
                                    (turnRef != null && curTurn.completed))
                                ? () {
                                    nextTurn();
                                  }
                                : null,
                            child: Text(
                              "Rotate",
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            color: Colors.blueAccent,
                            elevation: 20,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          )
                        : SizedBox(),
                  ] +
                  (curTurn == null || curTurn.completed
                      ? <Widget>[]
                      : (iamAns
                          ? <Widget>[
                              curTurn.call == null
                                  ? Text(
                                      "Its your turn.....Choose:",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    )
                                  : SizedBox(),
                              curTurn.call == null
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        RaisedButton(
                                          onPressed: () {
                                            turnRef
                                                .updateData({"call": "truth"});
                                            setState(() {
                                              curTurn.call = TurnCall.truth;
                                            });
                                          },
                                          child: Text(
                                            "TRUTH",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 25,
                                            ),
                                          ),
                                          color: Colors.blueAccent,
                                          elevation: 20,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                        RaisedButton(
                                          onPressed: () {
                                            turnRef
                                                .updateData({"call": "dare"});
                                            setState(() {
                                              curTurn.call = TurnCall.dare;
                                            });
                                          },
                                          child: Text(
                                            "DARE",
                                            style: TextStyle(
                                              fontSize: 25,
                                              color: Colors.white,
                                            ),
                                          ),
                                          color: Colors.blueAccent,
                                          elevation: 20,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        )
                                      ],
                                    )
                                  : curTurn.question == null
                                      ? Text(
                                          "Waiting for ${asker.name} to give you a " +
                                              (curTurn.call == TurnCall.truth
                                                  ? "Truth Question"
                                                  : "Dare"),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        )
                                      : SizedBox(),
                              curTurn.question != null
                                  ? Text(
                                      asker.name +
                                          "\'s Question: " +
                                          curTurn.question,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    )
                                  : SizedBox(),
                              curTurn.question != null && curTurn.answer == null
                                  ? Column(
                                      children: [
                                        curTurn.call == TurnCall.truth
                                            ? Row(
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
                                                            BorderRadius
                                                                .circular(20),
                                                        color: Colors.white,
                                                      ),
                                                      child: TextField(
                                                        enableInteractiveSelection:
                                                            false,
                                                        controller:
                                                            ansController,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              InputBorder.none,
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
                                                          hintText:
                                                              "Write your answer here....",
                                                          hintStyle: TextStyle(
                                                            color: Colors
                                                                .grey[400],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: IconButton(
                                                      icon: Icon(Icons.send,
                                                          color: ansController
                                                                  .value
                                                                  .text
                                                                  .isNotEmpty
                                                              ? Colors.white
                                                              : Colors
                                                                  .grey[500]),
                                                      onPressed: ansController
                                                              .value
                                                              .text
                                                              .isEmpty
                                                          ? null
                                                          : () {
                                                              turnRef
                                                                  .updateData({
                                                                "answer":
                                                                    ansController
                                                                        .value
                                                                        .text
                                                              });
                                                              setState(() {
                                                                curTurn.answer =
                                                                    ansController
                                                                        .value
                                                                        .text;
                                                              });
                                                              ansController
                                                                  .clear();
                                                            },
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox(),
                                        curTurn.call == TurnCall.truth
                                            ? Container(
                                                width: size.width * 0.5,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Divider(
                                                        color: Colors.white,
                                                        thickness: 2,
                                                        endIndent: 5,
                                                      ),
                                                    ),
                                                    Text(
                                                      "OR",
                                                      style: TextStyle(
                                                          color: Colors.white),
                                                    ),
                                                    Expanded(
                                                      child: Divider(
                                                        color: Colors.white,
                                                        thickness: 2,
                                                        indent: 5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : SizedBox(),
                                        RaisedButton(
                                          onPressed: () {
                                            turnRef.updateData(
                                                {"answer": "--video--"});
                                            setState(() {
                                              curTurn.answer = "--video--";
                                            });
                                            ansController.clear();
                                          },
                                          child: Text(
                                            "Answer in Video Call",
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                          color: Colors.blueAccent,
                                          elevation: 20,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        )
                                      ],
                                    )
                                  : SizedBox(),
                              curTurn.answer != null
                                  ? Text(
                                      "Your Answer: " + curTurn.answer,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    )
                                  : SizedBox(),
                            ]
                          : (iamAsk
                              ? <Widget>[
                                  curTurn.call == null && denPlayer != null
                                      ? Text(
                                          "Waiting for ${denPlayer.name} to choose..",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        )
                                      : curTurn.call != null
                                          ? Text(
                                              "${denPlayer.name} chose " +
                                                  (curTurn.call ==
                                                          TurnCall.truth
                                                      ? "Truth"
                                                      : "Dare"),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                            )
                                          : SizedBox(),
                                  SizedBox(height: 10),
                                  curTurn.call != null &&
                                          curTurn.question == null
                                      ? Row(
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
                                                  enableInteractiveSelection:
                                                      false,
                                                  controller: quesController,
                                                  onChanged: (s) {},
                                                  onSubmitted: (s) {},
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
                                                    hintText: "Write a " +
                                                        (curTurn.call ==
                                                                TurnCall.truth
                                                            ? "Truth Question"
                                                            : "Dare") +
                                                        " Here....",
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
                                                    color: quesController.value
                                                            .text.isNotEmpty
                                                        ? Colors.white
                                                        : Colors.grey[500]),
                                                onPressed: quesController
                                                        .value.text.isEmpty
                                                    ? null
                                                    : () {
                                                        turnRef.updateData({
                                                          "question":
                                                              quesController
                                                                  .value.text
                                                        });
                                                        setState(() {
                                                          curTurn.question =
                                                              quesController
                                                                  .value.text;
                                                        });
                                                        quesController.clear();
                                                      },
                                              ),
                                            ),
                                          ],
                                        )
                                      : SizedBox(),
                                  curTurn.question != null
                                      ? Text(
                                          "Your Question: " + curTurn.question,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        )
                                      : SizedBox(),
                                  curTurn.answer != null
                                      ? Text(
                                          denPlayer.name +
                                              "\'s Answer: " +
                                              curTurn.answer,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        )
                                      : SizedBox(),
                                  curTurn.answer != null
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            RaisedButton(
                                              onPressed: () {
                                                turnRef.updateData(
                                                    {"completed": true});
                                                setState(() {
                                                  curTurn.completed = true;
                                                });
                                              },
                                              child: Text(
                                                "Accept Answer",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              color: Colors.blueAccent,
                                              elevation: 20,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                            /* RaisedButton(
                                        onPressed: () {
                                          turnRef.updateData({"call": "dare"});
                                          setState(() {
                                            curTurn.call = TurnCall.dare;
                                          });
                                        },
                                        child: Text(
                                          "Reject Answer",
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        color: Colors.blueAccent,
                                        elevation: 20,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ) */
                                          ],
                                        )
                                      : SizedBox(),
                                ]
                              : <Widget>[
                                  curTurn != null &&
                                          curTurn.call == null &&
                                          denPlayer != null
                                      ? Text(
                                          "Waiting for ${denPlayer.name} to choose..",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        )
                                      : curTurn != null && curTurn.call != null
                                          ? Text(
                                              "${denPlayer.name} chose " +
                                                  (curTurn.call ==
                                                          TurnCall.truth
                                                      ? "Truth"
                                                      : "Dare"),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                            )
                                          : SizedBox(),
                                  curTurn != null && curTurn.question != null
                                      ? Text(
                                          asker.name +
                                              "\'s Question: " +
                                              curTurn.question,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        )
                                      : SizedBox(),
                                ]))),
            ),
          ),
        ),
      ),
    );
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
    /* if (rec.isRecording) {
      rec.stopRecording();
    } */
    widget.gameCol
        .where("type", isEqualTo: "request")
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
}

class BottleWidget extends StatefulWidget {
  _BottleWidgetState bottle = new _BottleWidgetState();
  void rotate(double finalPos) {
    bottle.rotate(finalPos);
  }

  @override
  _BottleWidgetState createState() => bottle;
}

class _BottleWidgetState extends State<BottleWidget>
    with SingleTickerProviderStateMixin {
  AnimationController animationController;
  Animation<double> animation;

  void rotate(double finalPos) {
    animation = new Tween<double>(begin: 0, end: 5 + finalPos)
        .animate(animationController);
    animationController.reset();
    animationController.forward();
  }

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..addListener(() => setState(() {}));
    animation = new Tween<double>(begin: 0.0).animate(animationController);
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: animation,
      child: Container(
        height: 40,
        width: 120,
        child: CustomPaint(
          painter: SpriteBottleShape(),
          /* child: Center(
            child: Text(
              "Sprite",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ), */
          willChange: true,
        ),
      ),
    );
  }
}

class SpriteBottleShape extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = Colors.green;
    var path = Path();
    double c = 3;
    path.moveTo(c, 0);
    path.lineTo(size.width - 40, 0);
    path.lineTo(size.width - 20, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.3);
    path.arcToPoint(Offset(size.width, size.height * 0.7),
        radius: Radius.circular(size.height * 0.05));
    path.lineTo(size.width, size.height * 0.7);
    path.lineTo(size.width - 20, size.height * 0.7);
    path.lineTo(size.width - 40, size.height);
    path.lineTo(c, size.height);
    path.lineTo(0, size.height - c);
    path.lineTo(0, c);
    path.close();
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.white;
    paint.strokeWidth = 0.5;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class BeerBottleShape extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = Color(0xffffcc00);
    var path = Path();
    double c = 3;
    double w = size.width, h = size.height;
    path.moveTo(c, 0);
    path.lineTo(w - 40, 0);
    path.lineTo(w - 40 + c, c);
    path.lineTo(w - 40 + c, h * 0.3);
    path.lineTo(w, h * 0.3);
    /* path.arcToPoint(Offset(w, h * 0.7),
        radius: Radius.circular(h * 0.05)); */
    path.lineTo(w, h * 0.7);
    path.lineTo(w - 40 + c, h * 0.7);
    path.lineTo(w - 40 + c, h - c);
    path.lineTo(w - 40, h);
    path.lineTo(c, h);
    path.lineTo(0, h - c);
    path.lineTo(0, c);
    path.close();
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.white;
    paint.strokeWidth = 0.5;
    canvas.drawPath(path, paint);
    path.reset();
    path.moveTo(w - 15, h * 0.3);
    path.lineTo(w, h * 0.3);
    path.lineTo(w, h * 0.7);
    path.lineTo(w - 15, h * 0.7);
    //path.lineTo(w - 10, h * 0.3);
    path.close();
    paint.color = Colors.black;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class UserTile extends StatelessWidget {
  final User user;
  Color borderColor;
  UserTile(this.user, {this.borderColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 5)
            : null,
      ),
      padding: EdgeInsets.all(5),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: CachedNetworkImage(
              imageUrl: user.profilePic.link ?? defaultProfilePicLink,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          Text(
            user.name.split(" ")[0],
            style: TextStyle(fontSize: 6.6),
          ),
        ],
      ),
    );
  }
}
