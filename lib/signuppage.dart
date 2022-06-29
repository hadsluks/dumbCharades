import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dumbCharades/classes.dart';
import 'package:dumbCharades/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String name, number, password;
  FocusNode nameF, numberF, passF;
  bool submitted = false;
  DocumentReference userRef;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  List<ProfilePicData> profilePics;
  ProfilePicData selectedProfilePic;
  bool hideBottomNavigation = false;
  bool signUp = true;
  bool isProfileLocal = false, numberVerified = false, waitngForOTP = false;
  int seconds;
  Timer otpTimer;
  bool obscurePass = true;

  @override
  void initState() {
    super.initState();
    getProfilePics();
    name = "";
    number = "";
    password = "";
    nameF = new FocusNode();
    numberF = new FocusNode();
    passF = new FocusNode();
  }

  void sendOTP() {
    setState(() {
      waitngForOTP = true;
    });
    FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: "+91$number",
        timeout: Duration(seconds: 30),
        verificationCompleted: (cred) {
          FirebaseAuth.instance.signInWithCredential(cred);
          toast("Number Verified");
          if (otpTimer != null) otpTimer.cancel();
          if (signUp) {
            submit();
            setState(() {
              waitngForOTP = false;
              numberVerified = true;
            });
          } else {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => HomePage(),
            ));
          }
        },
        verificationFailed: (exec) {
          toast("An Error Occured");
          if (otpTimer != null) otpTimer.cancel();
          setState(() {
            waitngForOTP = false;
            numberVerified = false;
          });
        },
        codeSent: (verfId, [code]) {
          setState(() {
            waitngForOTP = true;
          });
        },
        codeAutoRetrievalTimeout: (verfId) {
          if (otpTimer != null) otpTimer.cancel();
          toast("Failed to Auto-Retrieve the OTP!");
          setState(() {
            waitngForOTP = false;
            numberVerified = false;
          });
        });
    seconds = 30;
    otpTimer = new Timer.periodic(Duration(seconds: 1), (t) {
      if (seconds > 0 && this.mounted)
        setState(() {
          seconds -= 1;
        });
      else
        otpTimer.cancel();
    });
  }

  void toast(String message) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.CENTER,
      backgroundColor: Color(0xfff6322a),
      textColor: Colors.white,
    );
  }

  void getProfilePics() async {
    Firestore firestore = Firestore.instance;
    var sp = await firestore.collection('profilePic').getDocuments();
    profilePics = new List();
    sp.documents.forEach((d) {
      profilePics.add(new ProfilePicData.fromMap(d.data));
    });
  }

  void selectProfilePic() {
    if (profilePics != null) {
      setState(() {
        hideBottomNavigation = true;
      });
      scaffoldKey.currentState.showBottomSheet(
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
                              onTap: () async {
                                Navigator.of(context).pop();
                                getProfilePicFromGallery(ImageSource.camera);
                                await Future.delayed(
                                    Duration(milliseconds: 300));
                                setState(() {
                                  hideBottomNavigation = false;
                                });
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
                              onTap: () async {
                                Navigator.of(context).pop();
                                getProfilePicFromGallery(ImageSource.gallery);
                                await Future.delayed(
                                    Duration(milliseconds: 300));
                                setState(() {
                                  hideBottomNavigation = false;
                                });
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
                                  isProfileLocal = false;
                                  selectedProfilePic = profilePics[i];
                                });
                                Navigator.of(context).pop();
                                await Future.delayed(
                                    Duration(milliseconds: 300));
                                setState(() {
                                  hideBottomNavigation = false;
                                });
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
    isProfileLocal = true;
    File image = await ImagePicker.pickImage(source: source);
    if (image != null) {
      setState(() {
        selectedProfilePic = ProfilePicData(image.path);
      });
    }
  }

  @override
  void dispose() {
    if (otpTimer != null) otpTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.white,
      body: Form(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 100,
              ),
              logo(size),
              SizedBox(
                height: 20,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    signUp ? "SIGN UP" : "LOG IN",
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [
                            Color(0xffeec32d),
                            Color(0xfff6322a),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(
                          Rect.fromLTWH(0.0, 0.0, 50.0, 70.0),
                        ),
                    ),
                  )
                ],
              ),
              SizedBox(height: 15),
              submitted
                  ? !numberVerified
                      ? Column(
                          children: [
                            waitngForOTP
                                ? SizedBox()
                                : Text(
                                    "A One Time Password will be sent to:",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      foreground: Paint()
                                        ..shader = LinearGradient(
                                          colors: [
                                            Color(0xffeec32d),
                                            Color(0xfff6322a),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ).createShader(
                                          Rect.fromLTWH(0.0, 0.0, 50.0, 70.0),
                                        ),
                                    ),
                                  ),
                            SizedBox(height: 10),
                            waitngForOTP
                                ? SizedBox()
                                : Text(
                                    "+91 $number",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      foreground: Paint()
                                        ..shader = LinearGradient(
                                          colors: [
                                            Color(0xffeec32d),
                                            Color(0xfff6322a),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ).createShader(
                                          Rect.fromLTWH(0.0, 0.0, 50.0, 70.0),
                                        ),
                                    ),
                                  ),
                            SizedBox(height: 20),
                            waitngForOTP
                                ? Column(
                                    children: [
                                      Text(
                                        "Code will be auto retrieved in:",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          foreground: Paint()
                                            ..shader = LinearGradient(
                                              colors: [
                                                Color(0xffeec32d),
                                                Color(0xfff6322a),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ).createShader(
                                              Rect.fromLTWH(
                                                  0.0, 0.0, 50.0, 70.0),
                                            ),
                                        ),
                                      ),
                                      Text(
                                        (seconds != null
                                                ? seconds.toString()
                                                : "30") +
                                            " seconds",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          foreground: Paint()
                                            ..shader = LinearGradient(
                                              colors: [
                                                Color(0xffeec32d),
                                                Color(0xfff6322a),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ).createShader(
                                              Rect.fromLTWH(
                                                  0.0, 0.0, 50.0, 70.0),
                                            ),
                                        ),
                                      ),
                                    ],
                                  )
                                : GestureDetector(
                                    onTap: sendOTP,
                                    child: Container(
                                      width: size.width - 200,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xfffd3e40),
                                            Color(0xff960e7a),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                      padding: EdgeInsets.all(2),
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(32),
                                        ),
                                        child: Text(
                                          seconds != null ? "Resend" : "Send",
                                          style: TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        )
                      : Column(
                          children: [
                            GestureDetector(
                              onTap: selectProfilePic,
                              child: Opacity(
                                opacity: 1,
                                child: selectedProfilePic != null
                                    ? Container(
                                        height: 200,
                                        width: 200,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Color(0xfffec183),
                                              Color(0xffff1572),
                                            ],
                                          ),
                                        ),
                                        padding: EdgeInsets.all(2),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                          padding: EdgeInsets.all(15),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            child: isProfileLocal
                                                ? Image.file(
                                                    new File(
                                                      selectedProfilePic.link,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : CachedNetworkImage(
                                                    imageUrl:
                                                        selectedProfilePic.link,
                                                    fit: BoxFit.contain,
                                                    placeholder: (context, s) =>
                                                        Container(
                                                      color: Colors.white,
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 200,
                                        width: 200,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(),
                                          gradient: RadialGradient(
                                            colors: [
                                              Color(0xfffec183),
                                              Color(0xffff1572),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Select Profile Pic",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            FlatButton(
                              onPressed: () async {
                                if (selectedProfilePic != null) {
                                  await uploadProfile();
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => HomePage(),
                                    ),
                                  );
                                } else {
                                  toast("Select a Profile Pic!");
                                }
                              },
                              child: Container(
                                width: size.width - 200,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xfffd3e40),
                                      Color(0xff960e7a),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                padding: EdgeInsets.all(2),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: Text(
                                    "Next",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                  : Column(
                      children: [
                        signUp
                            ? Container(
                                width: size.width - 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xfffd3e40),
                                      Color(0xff960e7a),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                padding: EdgeInsets.all(2),
                                child: Container(
                                  padding: EdgeInsets.only(left: 10, top: 5),
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.white),
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      isDense: true,
                                      hintText: "Enter you Name",
                                      hintStyle: TextStyle(
                                          color: Colors.grey.withOpacity(0.5)),
                                      //labelText: "Name",
                                      labelStyle:
                                          TextStyle(color: Color(0xfffd3e40)),
                                    ),
                                    keyboardType: TextInputType.text,
                                    focusNode: nameF,
                                    onChanged: (s) {
                                      name = s;
                                    },
                                    onSubmitted: (s) {
                                      if (name.length == 0) {
                                        nameF.requestFocus();
                                        toast("Add Your Name");
                                      } else {
                                        numberF.requestFocus();
                                      }
                                    },
                                  ),
                                ),
                              )
                            : SizedBox(),
                        SizedBox(
                          height: 8,
                        ),
                        Container(
                          width: size.width - 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xfffd3e40),
                                Color(0xff960e7a),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          padding: EdgeInsets.all(2),
                          child: Container(
                            padding: EdgeInsets.only(left: 10, top: 5),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                counterText: "",
                                counterStyle: TextStyle(fontSize: 0.1),
                                border: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                isDense: true,
                                hintText: "Enter your mobile number",
                                hintStyle: TextStyle(
                                    color: Colors.grey.withOpacity(0.5)),
                                //labelText: "Mobile No.",
                                labelStyle: TextStyle(color: Color(0xfffd3e40)),
                              ),
                              keyboardType: TextInputType.number,
                              focusNode: numberF,
                              maxLength: 10,
                              maxLengthEnforced: true,
                              onChanged: (s) {
                                number = s;
                              },
                              onSubmitted: (s) {
                                if (number.length < 10) {
                                  numberF.requestFocus();
                                  toast("Mobile Number Invalid");
                                } else {
                                  passF.requestFocus();
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Container(
                          padding: EdgeInsets.only(left: 50),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xfffd3e40),
                                        Color(0xff960e7a),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  padding: EdgeInsets.all(2),
                                  child: Container(
                                    padding: EdgeInsets.only(left: 10, top: 5),
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.white),
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        isDense: true,
                                        hintText: "Enter a strong password...",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.withOpacity(0.5),
                                          fontSize: 15,
                                        ),
                                        //labelText: "Password",
                                        labelStyle:
                                            TextStyle(color: Color(0xfffd3e40)),
                                      ),
                                      keyboardType: TextInputType.text,
                                      focusNode: passF,
                                      obscureText: obscurePass,
                                      onChanged: (s) {
                                        password = s;
                                      },
                                      onSubmitted: (s) {
                                        if (password.length == 0) {
                                          passF.requestFocus();
                                          toast("Please Add Password");
                                        } else {
                                          passF.unfocus();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.remove_red_eye,
                                  color:
                                      obscurePass ? Colors.blue : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePass = !obscurePass;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        FlatButton(
                          onPressed: () async {
                            if (name.length == 0 && signUp) {
                              nameF.requestFocus();
                              toast("Add Your Name");
                            } else if (number.length < 10) {
                              numberF.requestFocus();
                              toast("Mobile Number Invalid");
                            } else if (password.length == 0) {
                              passF.requestFocus();
                              toast("Please Add Password");
                            } else {
                              loadingDialog();
                              if (signUp && await checkMobileNumberExist()) {
                                Navigator.of(context).pop();
                                numberF.requestFocus();
                                toast("Mobile Number Already Existts...");
                              } else {
                                if (!signUp) {
                                  bool subm = await submit();
                                  if (subm) {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      this.submitted = true;
                                    });
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                } else {
                                  Navigator.of(context).pop();
                                  sendOTP();
                                  setState(() {
                                    this.submitted = true;
                                  });
                                }
                              }
                            }
                          },
                          child: Container(
                            width: size.width - 200,
                            height: 45,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xfffd3e40),
                                  Color(0xff960e7a),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            padding: EdgeInsets.all(2),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Text(
                                "Submit",
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: 20),
              submitted
                  ? SizedBox()
                  : Container(
                      width: size.width - 100,
                      child: Row(
                        children: [
                          Expanded(child: Divider(thickness: 1)),
                          Text(!signUp
                              ? "New Here..?"
                              : "Already have an account?"),
                          Expanded(child: Divider(thickness: 1)),
                        ],
                      ),
                    ),
              SizedBox(height: 5),
              submitted
                  ? SizedBox()
                  : Container(
                      width: size.width - 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: !signUp ? "SIGN UP" : "LOG IN",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  setState(() {
                                    signUp = !signUp;
                                  });
                                },
                            ),
                          ),
                        ],
                      ),
                    )
            ],
          ),
        ),
      ),
      bottomNavigationBar: hideBottomNavigation
          ? null
          : Container(
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
    );
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

  Future<bool> checkMobileNumberExist() async {
    var sp = await Firestore.instance
        .collection('users')
        .where("number", isEqualTo: number)
        .getDocuments();
    if (sp.documents.length > 0)
      return true;
    else
      return false;
  }

  Future<bool> submit() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    if (signUp) {
      userRef = Firestore.instance.collection('users').document();
      await userRef.setData({
        'name': name,
        'number': number,
        'password': password,
      });
      await preferences.setString("name", name);
      await preferences.setString("number", number);
      return true;
    } else {
      var sp = await Firestore.instance
          .collection('users')
          .where("number", isEqualTo: number)
          .getDocuments();
      if (sp.documents.length == 0) {
        toast("No Account exists with Provided Mobile Number");
        return false;
      } else {
        var d = sp.documents.first.data;
        if (d['password'].toString() == password) {
          userRef = sp.documents.first.reference;
          name = d['name'];
          var id = d['profilePic'].toString();
          await preferences.setString("profilePic", id);
          await preferences.setString("name", name);
          await preferences.setString("number", number);
          sendOTP();
          return true;
        } else {
          toast("Password Incorrect!!!");
          return false;
        }
      }
    }
  }

  Future<void> uploadProfile() async {
    FirebaseAuth.instance.signInAnonymously();
    if (selectedProfilePic != null) {
      if (isProfileLocal) {
        loadingDialog(message: "Uploading");

        var intList = await FlutterImageCompress.compressAssetImage(
          selectedProfilePic.link,
          format: CompressFormat.jpeg,
          quality: 10,
        );

        var data = Uint8List.fromList(intList);
        var uploadTask = FirebaseStorage.instance
            .ref()
            .child("Profile$number")
            .putData(data);
        var sp = await uploadTask.onComplete;
        var url = (await sp.ref.getDownloadURL()).toString();
        await userRef.updateData({'profilePic': url});
        SharedPreferences preferences = await SharedPreferences.getInstance();
        await preferences.setString("profilePic", url);
      } else {
        loadingDialog();
        await userRef.updateData({'profilePic': selectedProfilePic.link});
        SharedPreferences preferences = await SharedPreferences.getInstance();
        await preferences.setString("profilePic", selectedProfilePic.link);
      }
      Navigator.of(context).pop();
    }
  }
}

/* Container(
                  width: size.width - 100,
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          endIndent: 2,
                        ),
                      ),
                      Text(
                        "OR",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          indent: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  "Sign in",
                ),
                SizedBox(
                  height: 10,
                ),
                GestureDetector(
                  child: Container(
                    height: 45,
                    width: size.width - 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "assets/googleLogo.svg",
                          height: 30,
                          width: 30,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text("GOOGLE"),
                      ],
                    ),
                  ),
                ),
                 */
