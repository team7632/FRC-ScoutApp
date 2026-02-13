import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;

// --- 資料模型 ---
class Waypoint {
  Offset position; // 儲存 0.0 ~ 1.0 的百分比座標
  double heading;
  double waitTime;
  String command;

  Waypoint(this.position, {this.heading = 0.0, this.waitTime = 0.0, this.command = ""});

  bool get isWait => waitTime > 0;
  bool get hasCommand => command.isNotEmpty;

  Map<String, dynamic> toJson() => {
    "x": position.dx.toStringAsFixed(3),
    "y": position.dy.toStringAsFixed(3),
    "h": heading.toStringAsFixed(3),
    "w": waitTime,
    "c": command
  };
}

enum EditMode { addOrRotate, toggleWait, toggleCommand }

// --- 主元件 ---
class BezierPathCanvas extends StatefulWidget {
  final Function(String) onPathJsonChanged;
  final String drivetrain;
  final String? initialJson;

  const BezierPathCanvas({
    super.key,
    required this.onPathJsonChanged,
    required this.drivetrain,
    this.initialJson,
  });

  @override
  State<BezierPathCanvas> createState() => _BezierPathCanvasState();
}

class _BezierPathCanvasState extends State<BezierPathCanvas> with TickerProviderStateMixin {
  List<Waypoint> waypoints = [];
  late AnimationController _controller;
  int _activeSegmentIndex = 0;
  bool _isAnimating = false;
  EditMode _currentMode = EditMode.addOrRotate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _loadInitialPath();
  }

  void _loadInitialPath() {
    if (widget.initialJson == null || widget.initialJson!.isEmpty || widget.initialJson == "[]") return;
    try {
      final List<dynamic> decoded = jsonDecode(widget.initialJson!);
      setState(() {
        waypoints = decoded.map((item) => Waypoint(
          Offset(double.parse(item['x'].toString()), double.parse(item['y'].toString())),
          heading: double.parse(item['h'].toString()),
          waitTime: double.parse(item['w'].toString()),
          command: item['c'].toString(),
        )).toList();
      });
    } catch (e) {
      debugPrint("路徑還原失敗: $e");
    }
  }

  void _syncToParent() {
    widget.onPathJsonChanged(jsonEncode(waypoints.map((w) => w.toJson()).toList()));
  }

  // --- 彈窗邏輯 (Heading, Wait, Command) ---
  void _showHeadingPicker(int index) {
    double tempHeading = waypoints[index].heading;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("set Heading ${index + 1}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onPanUpdate: (details) {
                  Offset center = const Offset(75, 75);
                  Offset localPos = details.localPosition - center;
                  setDialogState(() => tempHeading = math.atan2(localPos.dy, localPos.dx) + (math.pi / 2));
                },
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[900], border: Border.all(color: Colors.blueAccent)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: tempHeading,
                        child: Column(children: [Container(width: 4, height: 60, color: Colors.greenAccent), const SizedBox(height: 60)]),
                      ),
                      Text("${((tempHeading * 180 / math.pi) % 360).round()}°", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
            ElevatedButton(onPressed: () {
              setState(() => waypoints[index].heading = tempHeading);
              _syncToParent();
              Navigator.pop(context);
            }, child: const Text("save")),
          ],
        ),
      ),
    );
  }

  void _inputWaitTime(int index) {
    final ctrl = TextEditingController(text: waypoints[index].waitTime.toString());
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("wait(s)"),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
        TextButton(onPressed: () {
          setState(() => waypoints[index].waitTime = double.tryParse(ctrl.text) ?? 0);
          _syncToParent();
          Navigator.pop(context);
        }, child: const Text("sure")),
      ],
    ));
  }

  void _inputCommand(int index) {
    final ctrl = TextEditingController(text: waypoints[index].command);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("動作指令"),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "例如: shoot")),
      actions: [
        TextButton(onPressed: () { setState(() => waypoints[index].command = ""); _syncToParent(); Navigator.pop(context); }, child: const Text("清除")),
        TextButton(onPressed: () { setState(() => waypoints[index].command = ctrl.text); _syncToParent(); Navigator.pop(context); }, child: const Text("確定")),
      ],
    ));
  }

  Future<void> _playFullPreview() async {
    if (waypoints.length < 2) return;
    setState(() { _isAnimating = true; _activeSegmentIndex = 0; });
    for (int i = 0; i < waypoints.length - 1; i++) {
      setState(() => _activeSegmentIndex = i);
      _controller.duration = const Duration(milliseconds: 1200);
      await _controller.forward(from: 0.0);
      if (waypoints[i+1].isWait) await Future.delayed(Duration(milliseconds: (waypoints[i+1].waitTime * 1000).toInt()));
    }
    setState(() => _isAnimating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: LayoutBuilder(builder: (context, constraints) {
            final double W = constraints.maxWidth;
            final double H = constraints.maxHeight;

            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isAnimating ? Colors.greenAccent : Colors.white12, width: 2),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.4,
                      child: Image.asset("assets/images/field2026.png", fit: BoxFit.fill),
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (details) {
                      if (_isAnimating) return;
                      setState(() {
                        Offset percentPos = Offset(details.localPosition.dx / W, details.localPosition.dy / H);
                        for (int i = 0; i < waypoints.length; i++) {
                          Offset pPos = Offset(waypoints[i].position.dx * W, waypoints[i].position.dy * H);
                          if ((details.localPosition - pPos).distance < 25) {
                            if (_currentMode == EditMode.toggleWait) _inputWaitTime(i);
                            else if (_currentMode == EditMode.toggleCommand) _inputCommand(i);
                            else _showHeadingPicker(i);
                            return;
                          }
                        }
                        if (_currentMode == EditMode.addOrRotate) {
                          waypoints.add(Waypoint(percentPos));
                          _syncToParent();
                        }
                      });
                    },
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: BezierPainter(
                          nodes: waypoints,
                          progress: _controller.value,
                          activeSeg: _activeSegmentIndex,
                          drivetrain: widget.drivetrain,
                          showAnimation: _isAnimating,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  Positioned(bottom: 12, right: 12, child: FloatingActionButton.small(backgroundColor: Colors.green, onPressed: _isAnimating ? null : _playFullPreview, child: const Icon(Icons.play_arrow, color: Colors.white))),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _modeChip(EditMode.addOrRotate, Icons.add_location, "Point", Colors.blue),
              _modeChip(EditMode.toggleWait, Icons.timer, "Wait", Colors.red),
              _modeChip(EditMode.toggleCommand, Icons.flash_on, "Command", Colors.orange),
              const SizedBox(width: 8),
              ActionChip(label: const Text("undo"), onPressed: () => setState(() { if(waypoints.isNotEmpty) waypoints.removeLast(); _syncToParent(); })),
              ActionChip(label: const Text("clear"), onPressed: () => setState(() { waypoints.clear(); _syncToParent(); })),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeChip(EditMode mode, IconData icon, String label, Color color) {
    bool isSel = _currentMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black)),
        selected: isSel,
        selectedColor: color,
        avatar: Icon(icon, size: 16, color: isSel ? Colors.white : Colors.black),
        onSelected: (_) => setState(() => _currentMode = mode),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// --- 繪製器 (核心 Swerve 模擬) ---
class BezierPainter extends CustomPainter {
  final List<Waypoint> nodes;
  final double progress;
  final int activeSeg;
  final String drivetrain;
  final bool showAnimation;

  BezierPainter({required this.nodes, required this.progress, required this.activeSeg, required this.drivetrain, required this.showAnimation});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;
    List<Offset> realPoints = nodes.map((n) => Offset(n.position.dx * size.width, n.position.dy * size.height)).toList();

    // 1. 繪製路徑連線
    final pathPaint = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2;
    for (int i = 0; i < realPoints.length - 1; i++) {
      canvas.drawLine(realPoints[i], realPoints[i + 1], pathPaint);
    }

    // 2. 繪製動畫機器人 (Swerve 狀態)
    if (showAnimation && realPoints.length >= 2 && activeSeg < realPoints.length - 1) {
      _drawSwerveRobot(canvas, realPoints);
    }

    // 3. 繪製標點
    for (int i = 0; i < realPoints.length; i++) {
      final pos = realPoints[i];
      final node = nodes[i];
      canvas.drawCircle(pos, 5, Paint()..color = node.isWait ? Colors.redAccent : Colors.blueAccent);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(node.heading);
      final arrow = Path()..moveTo(0, -12)..lineTo(5, -5)..lineTo(-5, -5)..close();
      canvas.drawPath(arrow, Paint()..color = Colors.white);
      canvas.restore();

      if (node.hasCommand) _drawLabel(canvas, "⚡ ${node.command}", pos + const Offset(0, -22), Colors.orange);
      if (node.isWait) _drawLabel(canvas, "⏱ ${node.waitTime}s", pos + const Offset(0, 15), Colors.red);
    }
  }

  void _drawSwerveRobot(Canvas canvas, List<Offset> points) {
    final p1 = points[activeSeg];
    final p2 = points[activeSeg + 1];
    final currentPos = Offset.lerp(p1, p2, progress)!;

    // 計算自轉角度插值
    double h1 = nodes[activeSeg].heading;
    double h2 = nodes[activeSeg + 1].heading;
    double diff = (h2 - h1) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;
    double currentHeading = h1 + diff * progress;

    // --- Swerve 運動學計算 ---
    Offset velocity = p2 - p1; // 移動方向向量
    double rotVel = diff;      // 旋轉速度量

    canvas.save();
    canvas.translate(currentPos.dx, currentPos.dy);
    canvas.rotate(currentHeading);

    // 繪製底盤本體
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 32, height: 32), Paint()..color = Colors.blueAccent.withOpacity(0.6));
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 32, height: 32), Paint()..color = Colors.white..style = PaintingStyle.stroke);

    // 四個模組位置 (左前, 右前, 左後, 右後)
    List<Offset> modules = [const Offset(-12, -12), const Offset(12, -12), const Offset(-12, 12), const Offset(12, 12)];

    for (var modOffset in modules) {
      // 旋轉造成的切線速度 (垂直於模組半徑)
      Offset tangent = Offset(-modOffset.dy, modOffset.dx) * (rotVel * 0.5);
      // 平移向量轉為機器人局部坐標
      Offset localMove = _rotateOffset(velocity, -currentHeading);
      // 向量疊加得出輪子指向
      Offset modVec = localMove + tangent;

      _drawModuleWheel(canvas, modOffset, modVec.direction + (math.pi / 2));
    }

    // 車頭綠色標記
    canvas.drawRect(Rect.fromLTWH(-16, -16, 32, 4), Paint()..color = Colors.greenAccent);
    canvas.restore();
  }

  void _drawModuleWheel(Canvas canvas, Offset pos, double angle) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 6, height: 12), const Radius.circular(2)), Paint()..color = Colors.cyanAccent);
    canvas.restore();
  }

  Offset _rotateOffset(Offset s, double angle) {
    return Offset(s.dx * math.cos(angle) - s.dy * math.sin(angle), s.dx * math.sin(angle) + s.dy * math.cos(angle));
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: tp.width + 8, height: tp.height + 4), const Radius.circular(4)), Paint()..color = color.withOpacity(0.8));
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}