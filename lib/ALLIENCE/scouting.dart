import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../PIT/path.dart';
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

  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color allianceColor = const Color(0xFF7E57C2);


  int _autoBalls = 0, _teleBalls = 0;
  bool _isLeave = false, _isHanging = false;
  int _endgameLevel = 0;
  int _autoBump = 0, _autoTrench = 0, _autoDepot = 0, _autoOutpost = 0;
  int _teleBump = 0, _teleTrench = 0, _teleDepot = 0, _teleOutpost = 0;
  String _autoPathJson = "[]";

  Future<void> _submitReport() async {
    HapticFeedback.heavyImpact();
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
      'autoPathPoints': jsonDecode(_autoPathJson),
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
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RatingPage(
            roomName: widget.roomName,
            reportData: payload,
            reportIndex: responseData['index'] ?? 0,
          ),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final Color posColor = widget.position.startsWith('Red') ? Colors.redAccent : Colors.blueAccent;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text("QUAL ${widget.matchNumber} • ${widget.position}",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white38)),
            Text("TEAM ${widget.teamNumber}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: posColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: posColor.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(widget.position, style: TextStyle(color: posColor, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.5,
            colors: [primaryPurple.withOpacity(0.05), darkBg],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              // --- AUTONOMOUS ---
              _buildSection(
                title: "AUTONOMOUS STAGE",
                icon: Icons.auto_awesome_rounded,
                children: [
                  _counterRow("Auto Scored Fuels", _autoBalls, (v) => setState(() => _autoBalls = v)),
                  _sectionDivider("Field Points"),
                  _tacticalGrid([
                    _smallCounter("BUMP", _autoBump, (v) => setState(() => _autoBump = v)),
                    _smallCounter("TRENCH", _autoTrench, (v) => setState(() => _autoTrench = v)),
                    _smallCounter("DEPOT", _autoDepot, (v) => setState(() => _autoDepot = v)),
                    _smallCounter("OUTPOST", _autoOutpost, (v) => setState(() => _autoOutpost = v)),
                  ]),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: _toggleChip("Leave Line", _isLeave, (v) => setState(() => _isLeave = v))),
                    const SizedBox(width: 12),
                    Expanded(child: _toggleChip("Auto Hang", _isHanging, (v) => setState(() => _isHanging = v))),
                  ]),
                  const SizedBox(height: 24),
                  _sectionLabel("AUTO PATH STRATEGY"),
                  const SizedBox(height: 12),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: BezierPathCanvas(
                      drivetrain: "swerve",
                      onPathJsonChanged: (json) => _autoPathJson = json,
                    ),
                  ),
                ],
              ),

              // --- TELEOP ---
              _buildSection(
                title: "TELE-OP STAGE",
                icon: Icons.sports_esports_rounded,
                children: [
                  _counterRow("Teleop Scored Fuels", _teleBalls, (v) => setState(() => _teleBalls = v)),
                  _sectionDivider("Performance Metrics"),
                  _tacticalGrid([
                    _smallCounter("BUMP", _teleBump, (v) => setState(() => _teleBump = v)),
                    _smallCounter("TRENCH", _teleTrench, (v) => setState(() => _teleTrench = v)),
                    _smallCounter("DEPOT", _teleDepot, (v) => setState(() => _teleDepot = v)),
                    _smallCounter("OUTPOST", _teleOutpost, (v) => setState(() => _teleOutpost = v)),
                  ]),
                  const SizedBox(height: 32),
                  _sectionLabel("ENDGAME STATUS"),
                  const SizedBox(height: 16),
                  _buildEndgamePicker(),
                ],
              ),

              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: accentPurple, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: accentPurple, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 24),
        ...children
      ]),
    );
  }

  Widget _sectionDivider(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(children: [
        Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.05))),
      ]),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.5));
  }

  Widget _counterRow(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              const SizedBox(height: 16),
              Row(children: [
                _circularBtn(Icons.remove_rounded, () {
                  if (value > 0) {
                    HapticFeedback.lightImpact();
                    onChanged(value - 1);
                  }
                }),
                const SizedBox(width: 16),
                _circularBtn(Icons.add_rounded, () {
                  HapticFeedback.mediumImpact();
                  onChanged(value + 1);
                }, isPrimary: true),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _quickAddTextBtn("+5", () {
                  HapticFeedback.mediumImpact();
                  onChanged(value + 5);
                }),
                const SizedBox(width: 10),
                _quickAddTextBtn("+10", () {
                  HapticFeedback.mediumImpact();
                  onChanged(value + 10);
                }),
              ])
            ],
          ),
        ),
        Text("$value", style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: accentPurple, fontFamily: 'monospace', shadows: [
          Shadow(color: accentPurple.withOpacity(0.5), blurRadius: 20)
        ])),
      ],
    );
  }

  Widget _circularBtn(IconData icon, VoidCallback? onTap, {bool isPrimary = false}) {
    return Material(
      color: onTap == null ? Colors.white10 : (isPrimary ? primaryPurple : Colors.white.withOpacity(0.05)),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 24, color: onTap == null ? Colors.white24 : Colors.white),
        ),
      ),
    );
  }

  Widget _quickAddTextBtn(String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _smallCounter(String label, int value, Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
          Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: Colors.white24),
                onPressed: value > 0 ? () { HapticFeedback.selectionClick(); onChanged(value - 1); } : null),
            SizedBox(
                width: 30,
                child: Center(child: Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)))),
            IconButton(icon: Icon(Icons.add_circle_rounded, size: 22, color: accentPurple),
                onPressed: () { HapticFeedback.selectionClick(); onChanged(value + 1); }),
          ])
        ],
      ),
    );
  }

  Widget _tacticalGrid(List<Widget> children) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: children.length,
    separatorBuilder: (context, index) => const SizedBox(height: 8),
    itemBuilder: (context, index) => children[index],
  );

  Widget _toggleChip(String label, bool isActive, Function(bool) onSelected) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(!isActive);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? primaryPurple : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? accentPurple : Colors.white.withOpacity(0.05), width: 2),
          boxShadow: isActive ? [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildEndgamePicker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [0, 1, 2, 3].map((level) {
          bool isSelected = _endgameLevel == level;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _endgameLevel = level);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? primaryPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(level == 0 ? "NONE" : "L$level",
                      style: TextStyle(color: isSelected ? Colors.white : Colors.white24, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10))],
        ),
        child: ElevatedButton(
          onPressed: _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 80),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded),
              SizedBox(width: 16),
              Text("COMPLETE & SYNC DATA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}