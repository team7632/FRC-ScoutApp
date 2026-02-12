import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../PIT/path.dart';
import 'api.dart';
import 'endscout.dart'; // RatingPage 所在檔案

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

  int _autoBalls = 0, _teleBalls = 0;
  bool _isLeave = false, _isHanging = false;
  int _endgameLevel = 0;

  // Tactical Grid 數據
  int _autoBump = 0, _autoTrench = 0, _autoDepot = 0, _autoOutpost = 0;
  int _teleBump = 0, _teleTrench = 0, _teleDepot = 0, _teleOutpost = 0;

  // 自動路徑 JSON 儲存
  String _autoPathJson = "[]";

  final Color primaryPurple = const Color(0xFF673AB7);
  final Color bgGray = const Color(0xFFF2F2F7);

  /// 提交報告
  Future<void> _submitReport() async {
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
      'autoPathPoints': jsonDecode(_autoPathJson), // 傳送結構化的 Waypoints
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submit Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        title: Text("M${widget.matchNumber} - T${widget.teamNumber}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- AUTONOMOUS SECTION ---
            _buildSection("AUTONOMOUS", Colors.orange, [
              _counterRow("Auto Fuels", _autoBalls, (v) => setState(() => _autoBalls = v)),
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
                Expanded(child: _toggleChip("Auto Hang", _isHanging, (v) => setState(() => _isHanging = v))),
              ]),
              const SizedBox(height: 20),
              const Text("AUTO PATH EDIT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              // ⭐ 整合路徑編輯組件
              BezierPathCanvas(
                drivetrain: "swerve", // 根據你的要求，固定為 swerve
                onPathJsonChanged: (json) {
                  _autoPathJson = json;
                },
              ),
            ]),

            // --- TELEOP SECTION ---
            _buildSection("TELEOP", Colors.blue, [
              _counterRow("Tele Fuels", _teleBalls, (v) => setState(() => _teleBalls = v)),
              const Divider(height: 32),
              _tacticalGrid([
                _smallCounter("BUMP", _teleBump, (v) => setState(() => _teleBump = v)),
                _smallCounter("TRENCH", _teleTrench, (v) => setState(() => _teleTrench = v)),
                _smallCounter("DEPOT", _teleDepot, (v) => setState(() => _teleDepot = v)),
                _smallCounter("OUTPOST", _teleOutpost, (v) => setState(() => _teleOutpost = v)),
              ]),
              const SizedBox(height: 16),
              const Center(child: Text("Endgame Level", style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              _buildEndgamePicker(),
            ]),

            // --- SUBMIT BUTTON ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: const Text("SUBMIT DATA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 組件集 ---

  Widget _buildSection(String title, Color accentColor, List<Widget> children) =>
      Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 4, height: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(height: 16),
                ...children
              ]));

  Widget _counterRow(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text("$value", style: TextStyle(fontSize: 32, color: primaryPurple, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _quickAddBtn("-1", Colors.redAccent, value > 0 ? () => onChanged(value - 1) : null),
            const SizedBox(width: 8),
            Expanded(child: _quickAddBtn("+1", Colors.green, () => onChanged(value + 1))),
            const SizedBox(width: 4),
            Expanded(child: _quickAddBtn("+5", Colors.green, () => onChanged(value + 5))),
          ],
        ),
      ],
    );
  }

  Widget _quickAddBtn(String label, Color color, VoidCallback? onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: onTap == null ? Colors.grey.shade50 : Colors.white,
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _smallCounter(String label, int value, Function(int) onChanged) =>
      Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: bgGray.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: value > 0 ? () => onChanged(value - 1) : null),
              Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.blue), onPressed: () => onChanged(value + 1)),
            ]),
          ],
        ),
      );

  Widget _tacticalGrid(List<Widget> children) =>
      GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          children: children);

  Widget _toggleChip(String label, bool isActive, Function(bool) onSelected) =>
      ChoiceChip(
        label: Container(width: double.infinity, alignment: Alignment.center, child: Text(label)),
        selected: isActive,
        onSelected: onSelected,
        selectedColor: primaryPurple.withOpacity(0.2),
        checkmarkColor: primaryPurple,
        labelStyle: TextStyle(color: isActive ? primaryPurple : Colors.black87, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
      );

  Widget _buildEndgamePicker() =>
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text("None")),
          ButtonSegment(value: 1, label: Text("L1")),
          ButtonSegment(value: 2, label: Text("L2")),
          ButtonSegment(value: 3, label: Text("L3")),
        ],
        selected: {_endgameLevel},
        onSelectionChanged: (set) => setState(() => _endgameLevel = set.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primaryPurple,
          selectedForegroundColor: Colors.white,
        ),
      );
}