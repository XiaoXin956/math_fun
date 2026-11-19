import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 手写答案画板：孩子在上面手写答案，可清空，可导出 base64 PNG 提交给家长批改。
class HandwritingPad extends StatefulWidget {
  final Size size;

  const HandwritingPad({super.key, this.size = const Size(340, 220)});

  @override
  HandwritingPadState createState() => HandwritingPadState();
}

class HandwritingPadState extends State<HandwritingPad> {
  final List<List<ui.Offset>> strokes = [];
  List<ui.Offset>? current;
  final _boundaryKey = GlobalKey<RenderRepaintBoundary>();

  void _down(PointerDownEvent e) {
    setState(() {
      current = [e.position];
    });
  }

  void _move(PointerMoveEvent e) {
    if (current == null) return;
    setState(() {
      current!.add(e.position);
    });
  }

  void _up(PointerUpEvent e) {
    setState(() {
      if (current != null && current!.isNotEmpty) {
        strokes.add(current!);
      }
      current = null;
    });
  }

  void clear() {
    setState(() {
      strokes.clear();
      current = null;
    });
  }

  /// 将画板内容导出为 base64 PNG；失败返回 null。
  Future<String?> capture() async {
    final render =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (render == null) return null;
    try {
      final image = await render.toImage(
          pixelRatio: 1.0, size: widget.size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await image.close();
      if (bytes == null) return null;
      return base64Encode(bytes.toList());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size.width,
      height: widget.size.height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9C7BC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Listener(
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: CustomPaint(
            size: widget.size,
            painter: _StrokePainter(strokes),
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<ui.Offset>> strokes;

  _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()
        ..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => old.strokes != strokes;
}
