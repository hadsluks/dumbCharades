import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dumbCharades/classes.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';

class DumbCharadesGame extends StatefulWidget {
  final bool isAdmin;
  final CollectionReference gameCol;
  final String gameId;
  final User me;
  final DocumentReference denRef;
  final List<User> players;
  DumbCharadesGame({
    @required this.isAdmin,
    @required this.gameCol,
    @required this.gameId,
    @required this.me,
    @required this.denRef,
    @required this.players,
  });
  @override
  _DumbCharadesGameState createState() => _DumbCharadesGameState(
        gameCol: gameCol,
        isAdmin: isAdmin,
        me: me,
        players: players,
      );
}

class _DumbCharadesGameState extends State<DumbCharadesGame>
    with WidgetsBindingObserver {
  bool _isInChannel = false;
  final bool isAdmin;
  final List<User> players;
  final CollectionReference gameCol;
  final User me;
  _DumbCharadesGameState({
    @required this.isAdmin,
    @required this.gameCol,
    @required this.players,
    @required this.me,
  });

  StreamSubscription gameSubs;

  final DenData den = new DenData();

  List<AgoraRenderWidget> videoScreens = [];

  List<Message> answers = [];
  TextEditingController ansCont;
  FocusNode ansFocus;
  bool answering = false;
  List<String> suggestionList = [];
  Map<String, DocumentReference> scoreRef = {};
  Map<String, int> scores = {};
  Map<String, int> videoIds = {};
  //VideoRecording rec;
  bool recStatus = false;
  ScreenshotController _screenshotController = new ScreenshotController();
  List<String> mySS = [];

  void uploadScreenShots() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    var currentSSList = List<String>.from(mySS);
    var prevList = pref.getStringList("mySS") ?? [];
    prevList += currentSSList;
    String id = widget.gameId;
    await pref.setStringList("mySS", prevList);
    FirebaseStorage storage = FirebaseStorage.instance;
    currentSSList.forEach((path) async {
      String name = path.split("/").last;
      if (name.endsWith(".png")) {
        var data = await File(path).readAsBytes();
        storage.ref().child(id).child(name).putData(data);
      }
    });
  }

  void captureScreenShot() async {
    final directory = (await getApplicationDocumentsDirectory()).path;
    String fileName = DateTime.now().toIso8601String();
    String path = '$directory/${widget.gameId}/$fileName.png';
    var ssFile = await _screenshotController.capture(path: path);
    if (ssFile != null && await ssFile.exists()) {
      print(ssFile.path + "  Exists!!");
      mySS.add(ssFile.path);
    }
  }

  void setVideoIds() {
    var list = players.map<String>((e) => e.number).toList();
    list.sort();
    for (int i = 0; i < list.length; i++) {
      videoIds.addAll({list[i]: (i + 1) * 100});
    }
  }

  void addScoreRef() {
    var db = gameCol;
    for (var u in players) {
      db.add({"type": "score", "player": u.number, "score": 0}).then((value) {
        scoreRef.addAll({u.number: value});
      });
    }
  }

  void subscribeGameCollection() {
    gameSubs = gameCol.snapshots().listen(spRecieved);
  }

  void spRecieved(QuerySnapshot sp) {
    sp.documentChanges.forEach((doc) {
      var d = doc.document.data;
      if (d['type'] == "den") {
        String answerBy = d['answerBy'];
        if (answerBy != null) {
          gotCorrectAnswer(answerBy);
        }
        den.player = d['player'];
        den.movie = d['movie'];
        newDen();
      } else if (d['type'] == 'request' && d['status'] == 'exit') {
        players.removeWhere((pl) => pl.number == d['number']);
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
      } else if (d['type'] == "score") {
        scores.addAll({d['player']: d['score']});
      }
      setState(() {});
    });
  }

  void newDen() {
    answers = new List();
    if (!_isInChannel) {
      _toggleChannel();
    }
    if (den.player == me.number) {
      AgoraRtcEngine.enableLocalVideo(true).then((value) {
        captureScreenShot();
      });
      /* if (rec.isRecording) {
        if (rec.ispaused) rec.resumeRecording();
      } else if (recStatus) {
        rec.startRecording(widget.gameId ?? widget.gameCol.id);
      } */
    } else {
      AgoraRtcEngine.enableLocalVideo(false);
      /* if (rec.isRecording && !rec.ispaused) {
        rec.pauseRecording();
      } */
    }
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
                      "Correct Answer by: $answerBy",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            onWillPop: () async => false));
    Timer(Duration(milliseconds: 2000), () {
      Navigator.of(context).pop();
    });
  }

  void checkIfCorrectAnswer(Message answer) {
    if (answer.message == den.movie) {
      String player, movie;
      player = players[Random().nextInt(players.length)].number;
      while (player == den.player) {
        player = players[Random().nextInt(players.length)].number;
      }
      movie = movies[Random().nextInt(movies.length)];
      while (movie == den.movie) {
        movie = movies[Random().nextInt(movies.length)];
      }
      widget.denRef.updateData({
        'movie': movie,
        'player': player,
        'answerBy': players.firstWhere((p) => p.number == answer.sender).name
      });

      int newScore = scores[answer.sender] + 100;
      scoreRef[answer.sender].updateData({"score": newScore});
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

  void getRecordingStatus() async {
    recStatus =
        (await SharedPreferences.getInstance()).getBool("recordGame") ?? false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print(state);
    /* if (state == AppLifecycleState.resumed) {
      if (rec.ispaused) rec.resumeRecording();
    } else if (state == AppLifecycleState.paused) {
      if (rec.isRecording && !rec.ispaused) rec.pauseRecording();
    } */
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    answers = new List();
    ansCont = new TextEditingController(text: "");
    ansFocus = new FocusNode();
    suggestionList = new List();
    //rec = new VideoRecording();
    setVideoIds();
    _initAgoraRtcEngine();
    subscribeGameCollection();
    //getRecordingStatus();
    if (isAdmin) addScoreRef();
  }

  @override
  void dispose() {
    uploadScreenShots();
    WidgetsBinding.instance.removeObserver(this);
    gameSubs.cancel();
    if (_isInChannel) _toggleChannel();
    AgoraRtcEngine.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMyDen = den.player == me.number;

    bool validAnswer = movies.contains(ansCont.value.text);

    String denPlayerName;
    if (players.any((element) => element.number == den.player)) {
      denPlayerName =
          players.firstWhere((element) => element.number == den.player).name;
    }
    AgoraRenderWidget curretVideoScreen;

    if (videoScreens.isNotEmpty &&
        den != null &&
        videoScreens.any((e) => e.uid == videoIds[den.player])) {
      curretVideoScreen =
          videoScreens.firstWhere((e) => e.uid == videoIds[den.player]);
    }

    int myScore = scores[me.number];

    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          showExitDialog();
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
              body: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        "My Score: ${myScore ?? 0}",
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.625,
                      child: Container(
                        child: curretVideoScreen != null
                            ? Column(
                                children: [
                                  !isMyDen
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
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  Expanded(
                                    flex: 6,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Screenshot(
                                          controller: _screenshotController,
                                          child: curretVideoScreen,
                                        ),
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
                    ),
                    isMyDen
                        ? FloatingActionButton(
                            child: Icon(Icons.autorenew),
                            tooltip: "Switch Camera",
                            heroTag: "switchCamera",
                            backgroundColor: Color(0xfffec183),
                            onPressed: () {
                              AgoraRtcEngine.switchCamera();
                            },
                          )
                        : SizedBox(height: 40),
                    SizedBox(height: 5),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.25,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          !(answering && suggestionList.length > 0)
                              ? Expanded(
                                  child: Container(
                                    padding: EdgeInsets.only(
                                        top: 10,
                                        bottom: 5,
                                        left: 10,
                                        right: 10),
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
                                                  text: players
                                                          .firstWhere((p) =>
                                                              p.number ==
                                                              m.sender)
                                                          .name +
                                                      ": ",
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
                                        top: 10,
                                        bottom: 5,
                                        left: 10,
                                        right: 10),
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
                                      enabled: !isMyDen && !validAnswer,
                                      onTap: () {
                                        setState(() {
                                          answering = true;
                                        });
                                      },
                                      onChanged: (s) {
                                        setState(() {
                                          if (s.length > 0) {
                                            answering = true;
                                            suggestionList =
                                                new List.from(movies);
                                            suggestionList.retainWhere((m) => (m
                                                .toLowerCase()
                                                .contains(s.toLowerCase())));
                                          } else {
                                            answering = false;
                                            suggestionList = [];
                                          }
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
                                              gameCol.add({
                                                'type': 'answer',
                                                'sender': me.number,
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
