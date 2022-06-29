import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dumbCharades/classes.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyDrawer extends StatefulWidget {
  final User me;
  final GlobalKey<ScaffoldState> scaffoldKey;
  MyDrawer(this.me, this.scaffoldKey);
  @override
  _MyDrawerState createState() => _MyDrawerState(me);
}

class _MyDrawerState extends State<MyDrawer> {
  final User me;
  _MyDrawerState(this.me);
  bool recordGame, videoExpanded = false;
  List<String> recordedVideos = [];
  List<ProfilePicData> profilePics = [];
  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  void getRecordState() async {
    recordGame =
        (await SharedPreferences.getInstance()).getBool("recordGame") ?? false;
    setState(() {});
  }

  getRecordedVideos() async {
    recordedVideos = (await SharedPreferences.getInstance())
            .getStringList("recordedVideos") ??
        [];
    setState(() {});
  }

  void getProfilePics() async {
    Firestore firestore = Firestore.instance;
    var sp = await firestore.collection('profilePic').getDocuments();
    profilePics = new List();
    sp.documents.forEach((d) {
      profilePics.add(new ProfilePicData.fromMap(d.data));
    });
  }

  @override
  void initState() {
    super.initState();
    //getRecordState();
    //getRecordedVideos();
    getProfilePics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        alignment: Alignment.centerRight,
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
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12.0, bottom: 8.0),
              padding: EdgeInsets.all(5),
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(width: 0.1, color: Colors.grey),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: me.profilePic.link,
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: Text(
                me.name,
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: Divider(
                color: Colors.white,
                thickness: 0.3,
                endIndent: 15,
                indent: 15,
              ),
            ),
            ListTile(
              onTap: selectProfilePic,
              leading: Icon(
                Icons.account_circle,
                color: Colors.white,
              ),
              title: Text(
                "Change Profile Pic",
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            /* ListTile(
              leading: Icon(
                Icons.mic_none,
                color: Colors.white,
              ),
              title: Text(
                "Record my games",
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              onTap: () async {
                await (await SharedPreferences.getInstance())
                    .setBool("recordGame", !recordGame);
                setState(() {
                  recordGame = !recordGame;
                });
              },
              trailing: recordGame != null
                  ? Switch(
                      value: recordGame,
                      onChanged: (val) async {
                        await (await SharedPreferences.getInstance())
                            .setBool("recordGame", val);
                        setState(() {
                          recordGame = val;
                        });
                      },
                      activeColor: Color(0xfffec183),
                      activeTrackColor: Color(0xfffec183).withOpacity(0.5),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.blueGrey,
                    )
                  : null,
            ), */
            /* ListTile(
              onTap: () {
                setState(() {
                  videoExpanded = !videoExpanded;
                });
              },
              leading: Icon(
                Icons.video_library,
                color: Colors.white,
              ),
              title: Text(
                "Recorded games",
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              trailing: ExpandIcon(
                onPressed: (val) {
                  setState(() {
                    videoExpanded = !val;
                  });
                },
                isExpanded: videoExpanded,
                color: Colors.white,
              ),
            ), */
            /* videoExpanded
                ? Expanded(
                    child: ListView.builder(
                      itemCount: recordedVideos.length,
                      itemBuilder: (context, i) {
                        return ListTile(
                          onTap: () {
                            OpenFile.open(recordedVideos[i]);
                          },
                          contentPadding: EdgeInsets.only(left: 40, right: 10),
                          title: Text(
                            recordedVideos[i].split("/").last,
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          trailing: Icon(
                            Icons.launch,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  )
                : SizedBox(), */
          ],
        ),
      ),
    );
  }

  void selectProfilePic() async {
    if (profilePics != null) {
      _scaffoldKey.currentState.showBottomSheet(
        (context) {
          return Container(
            height: 400,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(50),
                topRight: Radius.circular(50),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(15.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: MediaQuery.of(context).size.width - 200,
                    alignment: Alignment.center,
                    child: Divider(
                      thickness: 5.0,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(
                    height: 15,
                  ),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      children: <Widget>[
                            GestureDetector(
                              child: Container(
                                padding: EdgeInsets.all(4),
                                margin: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Icon(
                                      Icons.camera,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      "Open Camera",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white),
                                    )
                                  ],
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                getProfilePicFromGallery(ImageSource.camera);
                              },
                            ),
                            GestureDetector(
                              child: Container(
                                padding: EdgeInsets.all(4),
                                margin: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      "Choose From Gallery",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white),
                                    )
                                  ],
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                getProfilePicFromGallery(ImageSource.gallery);
                              },
                            ),
                          ] +
                          new List<Widget>.generate(
                            profilePics.length,
                            (i) => GestureDetector(
                              child: Container(
                                padding: EdgeInsets.all(4),
                                margin: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: CachedNetworkImage(
                                    imageUrl: profilePics[i].link,
                                    placeholder: (context, s) => Container(
                                      color: Colors.white,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              onTap: () async {
                                setState(() {
                                  me.profilePic = profilePics[i];
                                });
                                uploadProfile(false);
                                Navigator.of(context).pop();
                                await Future.delayed(
                                    Duration(milliseconds: 300));
                              },
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      );
    }
  }

  void getProfilePicFromGallery(ImageSource source) async {
    File image = await ImagePicker.pickImage(source: source);
    if (image != null) {
      setState(() {
        me.profilePic = ProfilePicData(image.path);
      });
      uploadProfile(true);
    }
  }

  void uploadProfile(bool isLocal) async {
    if (isLocal) {
      loadingDialog(message: "Uploading");

      var intList = await FlutterImageCompress.compressAssetImage(
        me.profilePic.link,
        format: CompressFormat.jpeg,
        quality: 10,
      );

      var data = Uint8List.fromList(intList);
      var uploadTask = FirebaseStorage.instance
          .ref()
          .child("Profile${me.number}")
          .putData(data);
      var sp = await uploadTask.onComplete;
      var url = (await sp.ref.getDownloadURL()).toString();
      setState(() {
        me.profilePic = ProfilePicData(url);
      });
      Navigator.pop(context);
    }
    var sp = await Firestore.instance
        .collection("users")
        .where("number", isEqualTo: me.number)
        .getDocuments();
    if (sp.documents.length > 0) {
      var doc = sp.documents.first;
      doc.reference.updateData({"profilePic": me.profilePic.link});
      await (await SharedPreferences.getInstance())
          .setString("profilePic", me.profilePic.link);
    }
  }

  void loadingDialog({String message}) {
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
            (message != null ? message : "Loading") + "...",
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
        onWillPop: () async => false,
      ),
    );
  }
}
