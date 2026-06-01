import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';

class PhotoDrawResult {
  PhotoDrawResult({
    required this.imageBase64,
    required this.strokes,
    this.caption,
  });

  final String imageBase64;
  final List<DrawStroke> strokes;
  final String? caption;
}

class PhotoDrawScreen extends StatefulWidget {
  const PhotoDrawScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<PhotoDrawScreen> createState() => _PhotoDrawScreenState();
}

class _PhotoDrawScreenState extends State<PhotoDrawScreen> {
  final List<DrawStroke> _strokes = [];
  final List<DrawPoint> _currentPoints = [];
  final _captionController = TextEditingController();

  Color _color = Colors.red;
  final double _width = 4;
  int? _activeDrawPointer;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _addPoint(Offset pos, Size size) {
    _currentPoints.add(DrawPoint(
      x: (pos.dx / size.width).clamp(0.0, 1.0),
      y: (pos.dy / size.height).clamp(0.0, 1.0),
    ));
  }

  void _finishDrawStroke() {
    if (_currentPoints.length >= 2) {
      _strokes.add(DrawStroke(
        points: List.from(_currentPoints),
        color: _color.toARGB32(),
        width: _width,
      ));
    }
    _currentPoints.clear();
    setState(() {});
  }

  void _onDrawPointerDown(PointerDownEvent e, Size size) {
    _activeDrawPointer = e.pointer;
    _currentPoints.clear();
    _addPoint(e.localPosition, size);
    setState(() {});
  }

  void _onDrawPointerMove(PointerMoveEvent e, Size size) {
    if (_activeDrawPointer != e.pointer) return;
    _addPoint(e.localPosition, size);
    setState(() {});
  }

  void _onDrawPointerUp(PointerEvent e, Size size) {
    if (_activeDrawPointer != e.pointer) return;
    _activeDrawPointer = null;
    _finishDrawStroke();
  }

  void _submit() {
    final b64 = base64Encode(widget.imageBytes);
    Navigator.pop(
      context,
      PhotoDrawResult(
        imageBase64: b64,
        strokes: _strokes,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Редактор поста'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('Готово', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(widget.imageBytes, fit: BoxFit.contain),
                    CustomPaint(
                      painter: _LivePainter(
                        strokes: _strokes,
                        current: _currentPoints,
                        color: _color,
                        width: _width,
                      ),
                    ),
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _onDrawPointerDown(e, size),
                        onPointerMove: (e) => _onDrawPointerMove(e, size),
                        onPointerUp: (e) => _onDrawPointerUp(e, size),
                        onPointerCancel: (e) => _onDrawPointerUp(e, size),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: _captionController,
                  decoration: const InputDecoration(
                    labelText: 'Подпись к посту (необязательно)',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ColorDot(
                      color: Colors.red,
                      selected: _color == Colors.red,
                      onTap: () => setState(() => _color = Colors.red),
                    ),
                    _ColorDot(
                      color: Colors.yellow,
                      selected: _color == Colors.yellow,
                      onTap: () => setState(() => _color = Colors.yellow),
                    ),
                    _ColorDot(
                      color: Colors.green,
                      selected: _color == Colors.green,
                      onTap: () => setState(() => _color = Colors.green),
                    ),
                    _ColorDot(
                      color: Colors.blue,
                      selected: _color == Colors.blue,
                      onTap: () => setState(() => _color = Colors.blue),
                    ),
                    _ColorDot(
                      color: Colors.white,
                      selected: _color == Colors.white,
                      onTap: () => setState(() => _color = Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.gold : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _LivePainter extends CustomPainter {
  _LivePainter({
    required this.strokes,
    required this.current,
    required this.color,
    required this.width,
  });

  final List<DrawStroke> strokes;
  final List<DrawPoint> current;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke.points, Color(stroke.color), stroke.width);
    }
    if (current.length >= 2) {
      _drawStroke(canvas, size, current, color, width);
    }
  }

  void _drawStroke(
    Canvas canvas,
    Size size,
    List<DrawPoint> points,
    Color c,
    double w,
  ) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points.first.x * size.width, points.first.y * size.height);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x * size.width, points[i].y * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LivePainter oldDelegate) => true;
}
