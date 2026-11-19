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
  // strokes/current 都是原地修改的同一个对象，引用比较无法触发重绘，
  // 用递增版本号让 painter 感知内容变化（否则手写时画面毫无反应，看似卡死）。
  int _revision = 0;
  final _boundaryKey = GlobalKey();

  void _down(PointerDownEvent e) {
    setState(() {
      current = [e.position];
      _revision++;
    });
  }

  void _move(PointerMoveEvent e) {
    if (current == null) return;
    setState(() {
      current!.add(e.position);
      _revision++;
    });
  }

  void _up(PointerUpEvent e) {
    setState(() {
      if (current != null && current!.isNotEmpty) {
        strokes.add(current!);
      }
      current = null;
      _revision++;
    });
  }

  void _cancel(PointerCancelEvent e) {
    setState(() {
      current = null;
      _revision++;
    });
  }

  void clear() {
    setState(() {
      strokes.clear();
      current = null;
      _revision++;
    });
  }

  /// 将画板内容导出为 base64 PNG；失败返回 null。
  Future<String?> capture() async {
    final render =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (render == null) return null;
    try {
      final image = await render.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;
      return base64Encode(bytes.buffer.asUint8List());
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
          onPointerCancel: _cancel,
          child: CustomPaint(
            size: widget.size,
            painter: _StrokePainter(strokes, current, _revision),
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<ui.Offset>> strokes;
  final List<ui.Offset>? current;
  final int revision;

  _StrokePainter(this.strokes, this.current, this.revision);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // 已完成的笔画
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    // 正在书写的笔画，实时跟随手指/鼠标
    if (current != null) _drawStroke(canvas, current!, paint);
  }

  void _drawStroke(Canvas canvas, List<ui.Offset> stroke, Paint paint) {
    if (stroke.isEmpty) return;
    if (stroke.length == 1) {
      // 单个点画成圆点，否则抬手前只看不到内容
      canvas.drawCircle(stroke.first, paint.strokeWidth / 2, paint);
      return;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  // strokes/current 是原地修改的同一对象，必须靠版本号判断内容是否变化
  @override
  bool shouldRepaint(covariant _StrokePainter old) =>
      old.revision != revision || old.current != current;
}
