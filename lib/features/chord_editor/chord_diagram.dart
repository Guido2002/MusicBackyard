import 'package:flutter/material.dart';

import '../../app/localization/context_l10n.dart';

class ChordShape {
  const ChordShape(this.frets, {this.base = 1, this.barre});
  final List<int> frets;
  final int base;
  final int? barre;
}

const shapes = <String, List<ChordShape>>{
  'C': [
    ChordShape([-1, 3, 2, 0, 1, 0]),
    ChordShape([-1, 3, 5, 5, 5, 3], base: 3, barre: 3),
  ],
  'D': [
    ChordShape([-1, -1, 0, 2, 3, 2]),
  ],
  'E': [
    ChordShape([0, 2, 2, 1, 0, 0]),
  ],
  'F': [
    ChordShape([1, 3, 3, 2, 1, 1], barre: 1),
  ],
  'G': [
    ChordShape([3, 2, 0, 0, 0, 3]),
    ChordShape([3, 2, 0, 0, 3, 3]),
  ],
  'A': [
    ChordShape([-1, 0, 2, 2, 2, 0]),
  ],
  'B': [
    ChordShape([-1, 2, 4, 4, 4, 2], base: 2, barre: 2),
  ],
  'Am': [
    ChordShape([-1, 0, 2, 2, 1, 0]),
  ],
  'Em': [
    ChordShape([0, 2, 2, 0, 0, 0]),
  ],
  'Dm': [
    ChordShape([-1, -1, 0, 2, 3, 1]),
  ],
  'Bm': [
    ChordShape([-1, 2, 4, 4, 3, 2], base: 2, barre: 2),
  ],
  'F#m': [
    ChordShape([2, 4, 4, 2, 2, 2], base: 2, barre: 2),
  ],
  'Bb': [
    ChordShape([-1, 1, 3, 3, 3, 1], barre: 1),
  ],
  'C7': [
    ChordShape([-1, 3, 2, 3, 1, 0]),
  ],
  'G7': [
    ChordShape([3, 2, 0, 0, 0, 1]),
  ],
  'A7': [
    ChordShape([-1, 0, 2, 0, 2, 0]),
  ],
  'D7': [
    ChordShape([-1, -1, 0, 2, 1, 2]),
  ],
  'E7': [
    ChordShape([0, 2, 0, 1, 0, 0]),
  ],
  'Cmaj7': [
    ChordShape([-1, 3, 2, 0, 0, 0]),
  ],
  'Am7': [
    ChordShape([-1, 0, 2, 0, 1, 0]),
  ],
  'Em7': [
    ChordShape([0, 2, 0, 0, 0, 0]),
  ],
  'Dsus4': [
    ChordShape([-1, -1, 0, 2, 3, 3]),
  ],
  'Cadd9': [
    ChordShape([-1, 3, 2, 0, 3, 0]),
  ],
  'C/E': [
    ChordShape([0, 3, 2, 0, 1, 0]),
  ],
};
Future<void> showChordDiagram(BuildContext context, String chord) async {
  final alternatives = shapes[chord];
  var index = 0;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(chord),
        content: alternatives == null
            ? Text(ctx.l.noChordShape)
            : SizedBox(
                width: 220,
                height: 270,
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        size: const Size(210, 230),
                        painter: ChordPainter(
                          alternatives[index],
                          Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (alternatives.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: ctx.l.previous,
                            onPressed: () => set(
                              () => index = (index - 1) % alternatives.length,
                            ),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('${index + 1}/${alternatives.length}'),
                          IconButton(
                            tooltip: ctx.l.next,
                            onPressed: () => set(
                              () => index = (index + 1) % alternatives.length,
                            ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l.close),
          ),
        ],
      ),
    ),
  );
}

class ChordPainter extends CustomPainter {
  ChordPainter(this.shape, this.color);
  final ChordShape shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final left = size.width * .2,
        top = 35.0,
        dx = size.width * .13,
        dy = (size.height - 55) / 5;
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(left + i * dx, top),
        Offset(left + i * dx, top + 5 * dy),
        paint,
      );
    }
    for (var i = 0; i < 6; i++) {
      paint.strokeWidth = i == 0 && shape.base == 1 ? 4 : 1.2;
      canvas.drawLine(
        Offset(left, top + i * dy),
        Offset(left + 5 * dx, top + i * dy),
        paint,
      );
    }
    void label(String text, Offset at) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, at);
    }

    label('${shape.base}', Offset(2, top + dy * .2));
    if (shape.barre != null) {
      final first = shape.frets.indexOf(shape.barre!),
          last = shape.frets.lastIndexOf(shape.barre!);
      paint.strokeWidth = 13;
      paint.strokeCap = StrokeCap.round;
      final y = top + (shape.barre! - shape.base + .5) * dy;
      canvas.drawLine(
        Offset(left + first * dx, y),
        Offset(left + last * dx, y),
        paint,
      );
    }
    for (var i = 0; i < 6; i++) {
      final fret = shape.frets[i];
      if (fret <= 0) {
        label(fret < 0 ? '×' : '○', Offset(left + i * dx - 5, 9));
      } else {
        canvas.drawCircle(
          Offset(left + i * dx, top + (fret - shape.base + .5) * dy),
          7,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ChordPainter old) =>
      old.shape != shape || old.color != color;
}
