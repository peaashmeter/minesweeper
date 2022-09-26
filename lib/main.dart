import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: Minesweeper()));
}

class Minesweeper extends StatefulWidget {
  const Minesweeper({Key? key}) : super(key: key);

  @override
  State<Minesweeper> createState() => _MinesweeperState();
}

class _MinesweeperState extends State<Minesweeper> {
  late List<Cell> cells = [];
  late int size;
  late int minesCount;
  late Timer timer;
  late TimerWidget timerWidget;

  @override
  void initState() {
    setupGame(15);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(
                  Icons.coronavirus_rounded,
                  color: Colors.red,
                ),
                Text(
                  '${minesCount - cells.where((c) => c.state == CellStates.flagged).length}',
                  style: const TextStyle(
                      leadingDistribution: TextLeadingDistribution.even,
                      height: 10,
                      fontSize: 20),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: timerWidget,
          )
        ]),
      ),
      body: Stack(children: [
        Container(
          color: Colors.black,
        ),
        Center(
          child: SizedBox(
            width: 30.0 * size,
            height: 30.0 * size,
            child: GridView.count(
              crossAxisCount: size,
              children: List.generate(
                size * size,
                (i) => cells[i].widget(),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void setupGame(int s) {
    size = s;
    timerWidget = const TimerWidget(time: 0);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          timerWidget = TimerWidget(time: timer.tick);
        });
      }
    });

    minesCount = (size * size * 0.1).round();

    cells.addAll(List.generate(
        size * size,
        (i) => Cell(false, Point(i % size, i ~/ size), openEmptyCells,
            manageCellState, cells)));
    List<int> mines = [];
    while (mines.length < minesCount) {
      var n = Random().nextInt(size * size);
      if (mines.contains(n)) {
        continue;
      }
      mines.add(n);
    }
    for (var mine in mines) {
      cells[mine].withMine = true;
    }
  }

  void resetGame() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Minesweeper(),
        ));
  }

  void openEmptyCells(Cell initiator) {
    if (checkIfLose(initiator)) return;

    if (initiator.state == CellStates.flagged ||
        initiator.state == CellStates.opened) {
      return;
    }

    setState(() {
      initiator.state = CellStates.opened;
    });

    if (checkWinCondition()) return;

    if (initiator.findMinesNear() > 0) return;

    try {
      if (initiator.position.x != 0) {
        openEmptyCells(cells.firstWhere((c) =>
            c.position.x == initiator.position.x - 1 &&
            c.position.y == initiator.position.y));
      }
      if (initiator.position.x != size - 1) {
        openEmptyCells(cells.firstWhere((c) =>
            c.position.x == initiator.position.x + 1 &&
            c.position.y == initiator.position.y));
      }
      if (initiator.position.y != 0) {
        openEmptyCells(cells.firstWhere((c) =>
            c.position.y == initiator.position.y - 1 &&
            c.position.x == initiator.position.x));
      }
      if (initiator.position.y != size - 1) {
        openEmptyCells(cells.firstWhere((c) =>
            c.position.y == initiator.position.y + 1 &&
            c.position.x == initiator.position.x));
      }
    } catch (e) {
      return;
    }

    checkWinCondition();
  }

  void manageCellState(Cell cell) {
    if (cell.state == CellStates.closed) {
      return setState(() {
        cell.state = CellStates.flagged;
        checkWinCondition();
      });
    }
    if (cell.state == CellStates.flagged) {
      return setState(() {
        cell.state = CellStates.closed;
        checkWinCondition();
      });
    }
  }

  bool checkIfLose(Cell initiator) {
    final loseDialog = AlertDialog(
      backgroundColor: Colors.blueGrey[900],
      title: const Text(
        'You lose :(',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
            onPressed: () => resetGame(),
            child: const Text('Restart', style: TextStyle(color: Colors.white)))
      ],
    );

    if (initiator.withMine) {
      timer.cancel();
      setState(() {
        for (var cell in cells) {
          cell.state = CellStates.opened;
        }
      });
      showDialog(
        context: context,
        builder: (context) => loseDialog,
      ).then((value) => resetGame());
      return true;
    }
    return false;
  }

  bool checkWinCondition() {
    final winDialog = AlertDialog(
      backgroundColor: Colors.blueGrey[900],
      title: const Text(
        'You win!',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
            onPressed: () => resetGame(),
            child: const Text('Restart', style: TextStyle(color: Colors.white)))
      ],
    );

    if (cells
            .where((c) => c.withMine && c.state == CellStates.closed)
            .isEmpty &&
        cells
            .where((c) => !c.withMine && c.state != CellStates.opened)
            .isEmpty) {
      showDialog(
        context: context,
        builder: (context) => winDialog,
      ).then((value) => resetGame());
      return true;
    }
    return false;
  }
}

enum CellStates { closed, flagged, opened }

class Cell {
  CellStates state;
  bool withMine;
  final Point<int> position;
  final List<Cell> cells;
  final void Function(Cell cell) tapCallback;
  final void Function(Cell cell) longPressCallback;

  Cell(this.withMine, this.position, this.tapCallback, this.longPressCallback,
      this.cells,
      [this.state = CellStates.closed]);

  Widget widget() {
    late Widget cell;
    switch (state) {
      case CellStates.closed:
        cell = Container(color: Colors.blueGrey[700]);
        break;
      case CellStates.flagged:
        cell = Container(
          color: Colors.green,
        );
        break;
      case CellStates.opened:
        cell = Container(
            key: UniqueKey(),
            color: Colors.blueGrey[900],
            child: withMine
                ? const Icon(
                    Icons.coronavirus_rounded,
                  )
                : findMinesNear() > 0
                    ? Center(
                        child: Text(
                          findMinesNear().toString(),
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink());
        break;

      default:
        throw Exception('Че за фигня, это вообще как $state');
    }

    return GestureDetector(
      onLongPress: () => longPressCallback(this),
      onTap: (() {
        tapCallback(this);
      }),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: cell,
      ),
    );
  }

  int findMinesNear() {
    var cells_ = cells
        .where((e) => e.withMine)
        .where((c) => ((c.position.x - position.x).abs() <= 1 &&
            (c.position.y - position.y).abs() <= 1))
        .toList();
    return cells_.length;
  }
}

class TimerWidget extends StatelessWidget {
  final int time;
  const TimerWidget({Key? key, required this.time}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.timer_outlined,
          color: Colors.yellow,
        ),
        Text(
          '$time',
          style: const TextStyle(
              leadingDistribution: TextLeadingDistribution.even,
              height: 10,
              fontSize: 20),
        )
      ],
    );
  }
}
