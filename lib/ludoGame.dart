import 'dart:math';

import 'package:dumbCharades/classes.dart';
import 'package:flutter/material.dart';

class LudoGame extends StatefulWidget {
  @override
  _LudoGameState createState() => _LudoGameState();
}

class _LudoGameState extends State<LudoGame> {
  List<List<Pointer>> sticks = [];
  int currentTurn = 0, spin;

  @override
  void initState() {
    super.initState();
    sticks = [
      List.generate(
        4,
        (i) => Pointer(
          color: Colors.green,
          colPos: 0,
          isAtHome: true,
          highlight: false,
          istoWin: false,
          pos: i,
        ),
      ),
      List.generate(
        4,
        (i) => Pointer(
          color: Colors.red,
          colPos: 1,
          isAtHome: true,
          highlight: false,
          istoWin: false,
          pos: i,
        ),
      ),
      List.generate(
        4,
        (i) => Pointer(
          color: Colors.blue,
          colPos: 2,
          isAtHome: true,
          highlight: false,
          istoWin: false,
          pos: i,
        ),
      ),
      List.generate(
        4,
        (i) => Pointer(
          color: Colors.yellow,
          colPos: 3,
          isAtHome: true,
          highlight: false,
          istoWin: false,
          pos: i,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    double size = MediaQuery.of(context).size.width - 50,
        bs = size / 15, //small box size
        bS = bs * 6, //big box size
        padding = size * 0.475 / 12,
        cs = size * 0.475 / 5, //circle size
        ins = bS - 2 * padding, //inside square size
        sp = (ins - 2 * cs); //space inside square

    List<Color> colors = [Colors.green, Colors.red, Colors.blue, Colors.yellow];

    List<Offset> boxes = [];
    boxes = boxes + List.generate(5, (i) => Offset(bs * (i + 1), bs * 6));
    boxes = boxes + List.generate(6, (i) => Offset(bs * 6, bs * (6 - i - 1)));
    boxes = boxes + List.generate(2, (i) => Offset(bs * (6 + i + 1), 0));
    boxes = boxes + List.generate(5, (i) => Offset(bs * 8, bs * (i + 1)));
    boxes = boxes + List.generate(6, (i) => Offset(bs * (9 + i), bs * 6));
    boxes = boxes + List.generate(2, (i) => Offset(bs * 14, bs * (i + 7)));
    boxes = boxes + List.generate(5, (i) => Offset(bs * (13 - i), bs * 8));
    boxes = boxes + List.generate(6, (i) => Offset(bs * 8, bs * (9 + i)));
    boxes = boxes + List.generate(2, (i) => Offset(bs * (7 - i), bs * 14));
    boxes = boxes + List.generate(5, (i) => Offset(bs * 6, bs * (13 - i)));
    boxes = boxes + List.generate(6, (i) => Offset(bs * (5 - i), bs * 8));
    boxes = boxes + List.generate(2, (i) => Offset(0, bs * (7 - i)));

    List<List<Offset>> toWin = [
      List.generate(6, (i) => Offset(bs * (i + 1), bs * 7)),
      List.generate(6, (i) => Offset(bs * 7, bs * (i + 1))),
      List.generate(6, (i) => Offset(bs * (13 - i), bs * 7)),
      List.generate(6, (i) => Offset(bs * 7, bs * (13 - i))),
    ];

    List<List<Offset>> homes = [
      [
        Offset(padding + sp / 4, padding + sp / 4),
        Offset(padding + 3 * sp / 4 + cs, padding + sp / 4),
        Offset(padding + sp / 4, padding + 3 * sp / 4 + cs),
        Offset(padding + 3 * sp / 4 + cs, padding + 3 * sp / 4 + cs),
      ],
      [
        Offset(bs * 9 + padding + sp / 4, padding + sp / 4),
        Offset(bs * 9 + padding + 3 * sp / 4 + cs, padding + sp / 4),
        Offset(bs * 9 + padding + sp / 4, padding + 3 * sp / 4 + cs),
        Offset(bs * 9 + padding + 3 * sp / 4 + cs, padding + 3 * sp / 4 + cs),
      ],
      [
        Offset(bs * 9 + padding + sp / 4, bs * 9 + padding + sp / 4),
        Offset(bs * 9 + padding + 3 * sp / 4 + cs, bs * 9 + padding + sp / 4),
        Offset(bs * 9 + padding + sp / 4, bs * 9 + padding + 3 * sp / 4 + cs),
        Offset(bs * 9 + padding + 3 * sp / 4 + cs,
            bs * 9 + padding + 3 * sp / 4 + cs),
      ],
      [
        Offset(padding + sp / 4, bs * 9 + padding + sp / 4),
        Offset(padding + 3 * sp / 4 + cs, bs * 9 + padding + sp / 4),
        Offset(padding + sp / 4, bs * 9 + padding + 3 * sp / 4 + cs),
        Offset(padding + 3 * sp / 4 + cs, bs * 9 + padding + 3 * sp / 4 + cs),
      ],
    ];
    List<int> firstPos = [0, 13, 26, 39], winEntryPoints = [51, 11, 25, 38];
    List<Pointer> allSticks = [];
    for (var s in sticks) for (var p in s) allSticks.add(p);

    void moveStick(int i) {
      int sp = spin;
      var s = sticks[currentTurn][i];
      spin = null;
      if (s.isAtHome) {
        if (sp == 6) {
          s.isAtHome = false;
          s.pos = firstPos[s.colPos];
        }
      } else {
        if (s.istoWin) {
          if (s.pos + sp < toWin.length) {
            s.pos += sp;
          }
        } else {
          if (s.pos <= winEntryPoints[s.colPos] &&
              s.pos + sp >= winEntryPoints[s.colPos]) {
            sp -= winEntryPoints[s.colPos] + 1 - s.pos;
            s.istoWin = true;
            s.pos = sp;
          } else {
            s.pos = (s.pos + sp) % boxes.length;
          }
        }
      }
      for (var s in sticks[currentTurn]) s.highlight = false;
      currentTurn = (currentTurn + 1) % 4;
      print("done");
      setState(() {});
    }

    return SafeArea(
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
            children: [
              Expanded(
                child: Container(),
              ),
              LayoutBuilder(
                builder: (context, cons) {
                  return Container(
                    height: size,
                    width: size,
                    child: Stack(
                      children: <Widget>[
                            Column(
                              children: [
                                Container(
                                  height: bs * 6,
                                  child: Row(
                                    children: [
                                      Container(
                                        height: bs * 6,
                                        width: bs * 6,
                                        child: Container(
                                          color: Colors.green,
                                          padding: EdgeInsets.all(padding),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.green,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: bs * 6,
                                        width: bs * 3,
                                        child: Container(
                                          color: Colors.white,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: List<Widget>.generate(
                                              6,
                                              (j) => Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: List<Widget>.generate(
                                                  3,
                                                  (i) {
                                                    return Container(
                                                      height: bs,
                                                      width: bs,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            width: 0.1),
                                                        color:
                                                            (i == 1 && j > 0) ||
                                                                    (i == 2 &&
                                                                        j == 1)
                                                                ? Colors.red
                                                                : Colors.white,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: bs * 6,
                                        width: bs * 6,
                                        child: Container(
                                          color: Colors.red,
                                          padding: EdgeInsets.all(padding),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.red,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: bs * 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        height: bs * 3,
                                        width: bs * 6,
                                        child: Container(
                                          color: Colors.white,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: List<Widget>.generate(
                                              3,
                                              (i) => Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: List<Widget>.generate(
                                                  6,
                                                  (j) {
                                                    return Container(
                                                      height: bs,
                                                      width: bs,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            width: 0.1),
                                                        color:
                                                            (i == 1 && j > 0) ||
                                                                    (i == 0 &&
                                                                        j == 1)
                                                                ? Colors.green
                                                                : Colors.white,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: bs * 3,
                                        width: bs * 3,
                                        child: Container(
                                          color: Colors.grey,
                                          child: CustomPaint(
                                            painter: DrawTriangle([
                                              Colors.red,
                                              Colors.green,
                                              Colors.yellow,
                                              Colors.blue
                                            ]),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: bs * 3,
                                        width: bs * 6,
                                        child: Container(
                                          color: Colors.white,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: List<Widget>.generate(
                                              3,
                                              (i) => Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: List<Widget>.generate(
                                                  6,
                                                  (j) {
                                                    return Container(
                                                      height: bs,
                                                      width: bs,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            width: 0.1),
                                                        color:
                                                            (i == 1 && j > 0) ||
                                                                    (i == 0 &&
                                                                        j == 1)
                                                                ? Colors.blue
                                                                : Colors.white,
                                                      ),
                                                    );
                                                  },
                                                ).reversed.toList(),
                                              ),
                                            ).reversed.toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: bs * 6,
                                  child: Row(
                                    children: [
                                      Container(
                                        height: bs * 6,
                                        width: bs * 6,
                                        child: Container(
                                          color: Colors.yellow,
                                          padding: EdgeInsets.all(padding),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.yellow,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.yellow,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.yellow,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.yellow,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: bs * 6,
                                        width: bs * 3,
                                        child: Container(
                                          color: Colors.white,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: List<Widget>.generate(
                                              6,
                                              (j) => Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: List<Widget>.generate(
                                                  3,
                                                  (i) {
                                                    return Container(
                                                      height: bs,
                                                      width: bs,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            width: 0.1),
                                                        color:
                                                            (i == 1 && j > 0) ||
                                                                    (i == 2 &&
                                                                        j == 1)
                                                                ? Colors.yellow
                                                                : Colors.white,
                                                      ),
                                                    );
                                                  },
                                                ).reversed.toList(),
                                              ),
                                            ).reversed.toList(),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: bs * 6,
                                        width: bs * 6,
                                        child: Container(
                                          color: Colors.blue,
                                          padding: EdgeInsets.all(padding),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.blue,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      height: cs,
                                                      width: cs,
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] +
                          List<Widget>.generate(
                            allSticks.length,
                            (i) {
                              var s = allSticks[i],
                                  pos = s.isAtHome
                                      ? homes[s.colPos][s.pos]
                                      : s.istoWin
                                          ? toWin[s.colPos][s.pos]
                                          : boxes[s.pos],
                                  color = s.color;
                              return AnimatedPositioned(
                                duration: Duration(milliseconds: 500),
                                top: pos.dy,
                                left: pos.dx,
                                child: GestureDetector(
                                  onTap: s.highlight &&
                                          currentTurn == s.colPos &&
                                          spin != null
                                      ? () {
                                          moveStick(i % 4);
                                        }
                                      : null,
                                  child: Container(
                                    height: s.isAtHome ? cs : bs,
                                    width: s.isAtHome ? cs : bs,
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.all(
                                        s.isAtHome ? (cs - bs + 4) / 2 : 2),
                                    child: Container(
                                      height: bs,
                                      width: bs,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        color:
                                            s.highlight ? Colors.grey : color,
                                        size: bs - 5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  );
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    RaisedButton(
                      onPressed: spin != null
                          ? null
                          : () {
                              setState(() {
                                spin = Random().nextInt(6) + 1;
                                for (var s in sticks[currentTurn]) {
                                  if (s.isAtHome) {
                                    if (spin == 6) s.highlight = true;
                                  } else if (s.istoWin) {
                                    if (s.pos + spin <
                                        toWin[currentTurn].length)
                                      s.highlight = true;
                                  } else
                                    s.highlight = true;
                                }
                                if (!sticks[currentTurn]
                                    .any((s) => s.highlight)) {
                                  spin = null;
                                  currentTurn = (currentTurn + 1) % 4;
                                }
                              });
                            },
                      color: colors[currentTurn],
                      child: Text(
                        "Spin",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    spin != null
                        ? Text(
                            spin.toString(),
                            style: TextStyle(color: Colors.white),
                          )
                        : SizedBox()
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Pointer {
  Color color;
  final int colPos;
  int pos;
  bool isAtHome, istoWin, highlight;
  Pointer(
      {this.color,
      this.pos,
      this.colPos,
      this.isAtHome,
      this.highlight,
      this.istoWin});
}
