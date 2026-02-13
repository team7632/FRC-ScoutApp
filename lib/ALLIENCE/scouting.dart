import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';
import 'endscout.dart';


class ScoutingPage extends StatefulWidget {
  final String roomName;
  final String userName;
  final String position;
  final String matchNumber;
  final String teamNumber;

  const ScoutingPage({
    super.key,
    required this.roomName,
    required this.userName,
    required this.position,
    required this.matchNumber,
    required this.teamNumber,
  });

  @override
  State<ScoutingPage> createState() => _ScoutingPageState();
}

class _ScoutingPageState extends State<ScoutingPage> {
  // --- Data States ---
  int _autoBalls = 0, _teleBalls = 0;
  bool _isLeave = false, _isHanging = false;
  int _endgameLevel = 0;

  // Tactical Counters
  int _autoBump = 0, _autoTrench = 0, _autoDepot = 0, _autoOutpost = 0;
  int _teleBump = 0, _teleTrench = 0, _teleDepot = 0, _teleOutpost = 0;

  // --- Canvas States ---
  final List<Offset?> _points = [];
  final GlobalKey _canvasKey = GlobalKey();
  bool _isCanvasLocked = true; // Controls scroll locking and drawing
  final Color primaryPurple = const Color(0xFF673AB7);

  Future<void> _submitReport() async {
    final RenderBox? renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final Size size = renderBox?.size ?? const Size(1, 1);

    List<Map<String, dynamic>?> normalizedPoints = _points.map((p) {
      if (p == null) return null;
      return {
        'x': (p.dx / size.width).clamp(0.0, 1.0),
        'y': (p.dy / size.height).clamp(0.0, 1.0),
      };
    }).toList();

    final Map<String, dynamic> payload = {
      'roomName': widget.roomName,
      'user': widget.userName,
      'position': widget.position,
      'matchNumber': widget.matchNumber,
      'teamNumber': widget.teamNumber,
      'autoBallCount': _autoBalls,
      'teleopBallCount': _teleBalls,
      'isLeave': _isLeave,
      'isAutoHanging': _isHanging,
      'endgameLevel': _endgameLevel,
      'autoPathPoints': normalizedPoints,
      'autoBump': _autoBump,
      'autoTrench': _autoTrench,
      'autoDepot': _autoDepot,
      'autoOutpost': _autoOutpost,
      'teleBump': _teleBump,
      'teleTrench': _teleTrench,
      'teleDepot': _teleDepot,
      'teleOutpost': _teleOutpost,
    };

    try {
      final response = await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/submit-report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 && mounted) {
        final responseData = jsonDecode(response.body);
        final int reportIndex = responseData['index'] ?? 0;

        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RatingPage(
            roomName: widget.roomName,
            reportData: payload,
            reportIndex: reportIndex,
          ),
        ));
      }
    } catch (e) {
      debugPrint("Submit Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text("M${widget.matchNumber} - T${widget.teamNumber}"),
      ),
      // --- Scroll Logic: Disable physics when drawing ---
      body: SingleChildScrollView(
        physics: _isCanvasLocked
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildSection("AUTONOMOUS", Colors.orange, [
              _counterRow("Auto Fuel", _autoBalls, (v) => setState(() => _autoBalls = v)),
              const Divider(height: 32),
              _tacticalGrid([
                _smallCounter("BUMP", _autoBump, (v) => setState(() => _autoBump = v)),
                _smallCounter("TRENCH", _autoTrench, (v) => setState(() => _autoTrench = v)),
                _smallCounter("DEPOT", _autoDepot, (v) => setState(() => _autoDepot = v)),
                _smallCounter("OUTPOST", _autoOutpost, (v) => setState(() => _autoOutpost = v)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _toggleChip("Leave", _isLeave, (v) => setState(() => _isLeave = v))),
                const SizedBox(width: 8),
                Expanded(child: _toggleChip("Hang", _isHanging, (v) => setState(() => _isHanging = v))),
              ]),
              _buildCanvas(),
            ]),
            _buildSection("TELEOP", Colors.blue, [
              _counterRow("Tele Fuel", _teleBalls, (v) => setState(() => _teleBalls = v)),
              const Divider(height: 32),
              _tacticalGrid([
                _smallCounter("BUMP", _teleBump, (v) => setState(() => _teleBump = v)),
                _smallCounter("TRENCH", _teleTrench, (v) => setState(() => _teleTrench = v)),
                _smallCounter("DEPOT", _teleDepot, (v) => setState(() => _teleDepot = v)),
                _smallCounter("OUTPOST", _teleOutpost, (v) => setState(() => _teleOutpost = v)),
              ]),
              const Center(child: Text("Endgame Level", style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              _buildEndgamePicker(),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                ),
                child: const Text("SUBMIT DATA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("AUTO PATH", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _isCanvasLocked = !_isCanvasLocked),
                  icon: Icon(_isCanvasLocked ? Icons.lock_outline : Icons.lock_open, size: 18),
                  label: Text(_isCanvasLocked ? "Unlock to Draw" : "Lock to Scroll"),
                  style: TextButton.styleFrom(
                    foregroundColor: _isCanvasLocked ? Colors.grey : primaryPurple,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _isCanvasLocked ? null : () => setState(() => _points.clear()),
                ),
              ],
            ),
          ],
        ),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isCanvasLocked ? Colors.black12 : primaryPurple.withOpacity(0.5), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/images/field2026.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    color: _isCanvasLocked ? Colors.white.withOpacity(0.8) : null,
                    colorBlendMode: BlendMode.modulate,
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: _isCanvasLocked ? null : (details) => setState(() => _points.add(details.localPosition)),
                      onPanUpdate: _isCanvasLocked ? null : (details) => setState(() => _points.add(details.localPosition)),
                      onPanEnd: _isCanvasLocked ? null : (details) => setState(() => _points.add(null)),
                      child: CustomPaint(
                        key: _canvasKey,
                        painter: ScoutingPainter(_points, primaryPurple),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  if (_isCanvasLocked)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, color: Colors.grey, size: 30),
                          Text("Tap 'Unlock' to Draw Path", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Components ---
  Widget _quickAddBtn(String label, Color color, VoidCallback? onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _smallCounter(String label, int value, Function(int) onChanged) =>
      Column(children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: value > 0 ? () => onChanged(value - 1) : null),
          Text("$value", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add, size: 18, color: Colors.blue), onPressed: () => onChanged(value + 1)),
        ]),
      ]);

  Widget _tacticalGrid(List<Widget> children) =>
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.2, children: children);

  Widget _buildSection(String t, Color c, List<Widget> ch) =>
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16), ...ch
          ]));

  Widget _counterRow(String label, int value, Function(int) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text("$value", style: TextStyle(fontSize: 32, color: primaryPurple, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _quickAddBtn("-1", Colors.redAccent, value > 0 ? () => onChanged(value - 1) : null),
        const SizedBox(width: 8),
        Expanded(child: _quickAddBtn("+1", Colors.green, () => onChanged(value + 1))),
        const SizedBox(width: 4),
        Expanded(child: _quickAddBtn("+5", Colors.green, () => onChanged(value + 5))),
        const SizedBox(width: 4),
        Expanded(child: _quickAddBtn("+10", Colors.green, () => onChanged(value + 10))),
      ]),
    ]);
  }

  Widget _toggleChip(String l, bool a, Function(bool) o) => FilterChip(label: Text(l), selected: a, onSelected: o);

  Widget _buildEndgamePicker() => SizedBox(width: double.infinity,
    child: SegmentedButton<int>(
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.comfortable, padding: const EdgeInsets.symmetric(vertical: 8)),
      segments: const [
        ButtonSegment(value: 0, label: Text("None", style: TextStyle(fontSize: 12))),
        ButtonSegment(value: 1, label: Text("L1", style: TextStyle(fontSize: 12))),
        ButtonSegment(value: 2, label: Text("L2", style: TextStyle(fontSize: 12))),
        ButtonSegment(value: 3, label: Text("L3", style: TextStyle(fontSize: 12))),
      ],
      selected: {_endgameLevel},
      onSelectionChanged: (set) => setState(() => _endgameLevel = set.first),
    ),
  );
}

class ScoutingPainter extends CustomPainter {
  final List<Offset?> points; final Color color;
  ScoutingPainter(this.points, this.color);
  @override void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color..strokeCap = StrokeCap.round..strokeWidth = 5.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i+1] != null) canvas.drawLine(points[i]!, points[i+1]!, paint);
    }
  }
  @override bool shouldRepaint(old) => true;
}