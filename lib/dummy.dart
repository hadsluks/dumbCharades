import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as a;
import 'package:dumbCharades/classes.dart';
import 'package:dumbCharades/truthOrDareGame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DummyPage extends StatefulWidget {
  @override
  _DummyPageState createState() => _DummyPageState();
}

class _DummyPageState extends State<DummyPage> {
  bool _isInChannel = false;
  final _infoStrings = <String>[];
  VideoRecording vr;

  static final _sessions = List<VideoSession>();
  String dropdownValue = 'Off';
  static TextStyle textStyle = TextStyle(fontSize: 18, color: Colors.blue);
  final List<String> voices = [
    'Off',
    'Oldman',
    'BabyBoy',
    'BabyGirl',
    'Zhubajie',
    'Ethereal',
    'Hulk'
  ];

  /// remote user list
  final _remoteUsers = List<int>();

  Widget _voiceDropdown() {
    return Scaffold(
      body: Center(
        child: DropdownButton<String>(
          value: dropdownValue,
          onChanged: (String newValue) {
            setState(() {
              dropdownValue = newValue;
              VoiceChanger voice =
                  VoiceChanger.values[(voices.indexOf(dropdownValue))];
              AgoraRtcEngine.setLocalVoiceChanger(voice);
            });
          },
          items: voices.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _toggleChannel() async {
    if (_isInChannel) {
      _isInChannel = false;
      await AgoraRtcEngine.leaveChannel();
      await AgoraRtcEngine.stopPreview();
    } else {
      _isInChannel = true;
      await AgoraRtcEngine.startPreview();
      await AgoraRtcEngine.joinChannel(null, 'harsh', null, 0);
    }
    setState(() {});
  }

  Widget _viewRows() {
    return Row(
      children: <Widget>[
        for (final widget in _renderWidget)
          Expanded(
            child: Container(
              child: widget,
            ),
          )
      ],
    );
  }

  Iterable<Widget> get _renderWidget sync* {
    yield AgoraRenderWidget(0, local: true, preview: false);

    for (final uid in _remoteUsers) {
      yield AgoraRenderWidget(uid);
    }
  }

  VideoSession _getVideoSession(int uid) {
    return _sessions.firstWhere((session) {
      return session.uid == uid;
    });
  }

  List<Widget> _getRenderViews() {
    return _sessions.map((session) => session.view).toList();
  }

  Widget _buildInfoList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemExtent: 24,
      itemBuilder: (context, i) {
        return ListTile(
          title: Text(_infoStrings[i]),
        );
      },
      itemCount: _infoStrings.length,
    );
  }

  void _addAgoraEventHandlers() {
    AgoraRtcEngine.onJoinChannelSuccess =
        (String channel, int uid, int elapsed) {
      setState(() {
        String info = 'onJoinChannel: ' + channel + ', uid: ' + uid.toString();
        _infoStrings.add(info);
      });
    };

    AgoraRtcEngine.onError = (err) {
      print(err.toString() + "error!!!");
    };

    AgoraRtcEngine.onLeaveChannel = () {
      setState(() {
        _infoStrings.add('onLeaveChannel');
        _remoteUsers.clear();
      });
    };

    AgoraRtcEngine.onUserJoined = (int uid, int elapsed) {
      setState(() {
        String info = 'userJoined: ' + uid.toString();
        _infoStrings.add(info);
        _remoteUsers.add(uid);
      });
    };

    AgoraRtcEngine.onUserOffline = (int uid, int reason) {
      setState(() {
        String info = 'userOffline: ' + uid.toString();
        _infoStrings.add(info);
        _remoteUsers.remove(uid);
      });
    };

    AgoraRtcEngine.onFirstRemoteVideoFrame =
        (int uid, int width, int height, int elapsed) {
      setState(() {
        String info = 'firstRemoteVideo: ' +
            uid.toString() +
            ' ' +
            width.toString() +
            'x' +
            height.toString();
        _infoStrings.add(info);
      });
    };
  }

  Future<void> _initAgoraRtcEngine() async {
    AgoraRtcEngine.create('c16abbe55c284c0e84adaec9247b1d6b');
    _addAgoraEventHandlers();
    AgoraRtcEngine.enableVideo();
    //AgoraRtcEngine.enableLocalVideo(false);
    AgoraRtcEngine.enableAudio();
    // AgoraRtcEngine.setParameters('{\"che.video.lowBitRateStreamParameter\":{\"width\":320,\"height\":180,\"frameRate\":15,\"bitRate\":140}}');
    AgoraRtcEngine.setChannelProfile(ChannelProfile.Communication);
    VideoEncoderConfiguration config = VideoEncoderConfiguration();
    config.orientationMode = VideoOutputOrientationMode.FixedPortrait;
    AgoraRtcEngine.setVideoEncoderConfiguration(config);
  }

  BottleWidget b = new BottleWidget();

  @override
  void initState() {
    super.initState();
    vr = new VideoRecording();
    _initAgoraRtcEngine();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Agora Flutter SDK'),
        ),
        body: Container(
          child: Column(
            children: [
              Container(height: 320, child: _viewRows()),
              OutlineButton(
                child: Text(_isInChannel ? 'Leave Channel' : 'Join Channel',
                    style: textStyle),
                onPressed: _toggleChannel,
              ),
              Container(height: 100, child: _voiceDropdown()),
              /* SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    RaisedButton(
                      onPressed: () async {
                        var st = await vr.startRecording("10101010");
                        print("Started  $st");
                      },
                      child: Text("Start"),
                    ),
                    RaisedButton(
                      onPressed: () async {
                        var st = await vr.pauseRecording();
                        print("Paused  $st");
                      },
                      child: Text("Pause"),
                    ),
                    RaisedButton(
                      onPressed: () async {
                        var st = await vr.stopRecording();
                        print("Stopped  $st");
                      },
                      child: Text("Stop"),
                    ),
                    RaisedButton(
                      onPressed: () async {
                        OpenFile.open(
                            "/data/user/0/com.script.scriptGames/app_flutter/recordings/2020-06-01T19:51:14.418589.mp4");
                      },
                      child: Text("Open"),
                    ),
                    RaisedButton(
                      onPressed: () async {
                        vr.changeCamera();
                      },
                      child: Text("Switch Camera"),
                    ),
                  ],
                ),
              ), */

              RaisedButton(
                onPressed: () {},
              ),
              Expanded(child: Container(child: _buildInfoList())),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoSession {
  int uid;
  Widget view;
  int viewId;

  VideoSession(int uid, Widget view) {
    this.uid = uid;
    this.view = view;
  }
}
