import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'api.dart';
import 'endscout.dart';

class ScoutingPage extends StatefulWidget {
  final String roomName;
  final String matchNumber;
  final String teamNumber;
  final String position;
  final String userName;

  const ScoutingPage({
    super.key,
    required this.roomName,
    required this.matchNumber,
    required this.teamNumber,
    required this.position,
    required this.userName,
  });

  @override
  State<ScoutingPage> createState() => _ScoutingPageState();
}

class _ScoutingPageState extends State<ScoutingPage> {
  int _autoBallCount = 0;
  int _teleopBallCount = 0;
  bool _isAutoHanging = false;
  bool _isLeave = false;
  int _endgameLevel = 0;
  bool _isAutoMode = true;

  final Color purpleTheme = const Color(0xFFD0BCFF); // Material 3 Purple

  @override
  void initState() {
    super.initState();
    // Force Landscape orientation for scouting
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore Portrait orientation when leaving
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // --- UI Component: Score Counter ---
  Widget _buildMenuCounter() {
    int currentCount = _isAutoMode ? _autoBallCount : _teleopBallCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleTheme.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Updated label to "Fuels"
          const Text("Fuels", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: purpleTheme),
            onPressed: () => setState(() => _isAutoMode
                ? (_autoBallCount > 0 ? _autoBallCount-- : null)
                : (_teleopBallCount > 0 ? _teleopBallCount-- : null)),
          ),
          Text(
            "$currentCount",
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: purpleTheme),
            onPressed: () => setState(() => _isAutoMode ? _autoBallCount++ : _teleopBallCount++),
          ),
        ],
      ),
    );
  }

  // Endgame Selector
  void _showEndgamePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1B1F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text("Endgame Level",
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const Divider(color: Colors.white10, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 4,
                  itemBuilder: (context, i) => ListTile(
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      i == 0 ? "None" : "Level $i",
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    onTap: () {
                      setState(() => _endgameLevel = i);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipButton({required String label, required bool isActive, required VoidCallback onTap}) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (v) => onTap(),
      selectedColor: purpleTheme.withOpacity(0.3),
      checkmarkColor: purpleTheme,
      labelStyle: TextStyle(color: isActive ? purpleTheme : Colors.white70),
      backgroundColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isActive ? purpleTheme : Colors.white24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Field Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(
                  'assets/images/field2026.png',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: Colors.black)
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildControlPanel(),
                      const Spacer(),
                      FloatingActionButton.large(
                        onPressed: _showConfirmDialog,
                        backgroundColor: purpleTheme,
                        child: const Icon(Icons.send_rounded, size: 36, color: Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    bool isRed = widget.position.contains('Red');
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text("Match ${widget.matchNumber} | Team ${widget.teamNumber}"),
          backgroundColor: Colors.black87,
          labelStyle: const TextStyle(color: Colors.white),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isRed ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isRed ? Colors.red : Colors.blue),
          ),
          child: Text(
            widget.position,
            style: TextStyle(
              color: isRed ? Colors.red[200] : Colors.blue[200],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1F).withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text("AUTO"), icon: Icon(Icons.bolt)),
              ButtonSegment(value: false, label: Text("TELEOP"), icon: Icon(Icons.videogame_asset)),
            ],
            selected: {_isAutoMode},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() => _isAutoMode = newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.black26,
              selectedBackgroundColor: purpleTheme,
              selectedForegroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          _buildMenuCounter(),
          const SizedBox(height: 16),

          if (_isAutoMode)
            Row(
              children: [
                _buildChipButton(label: "Leave Zone", isActive: _isLeave, onTap: () => setState(() => _isLeave = !_isLeave)),
                const SizedBox(width: 8),
                _buildChipButton(label: "Auto Hang", isActive: _isAutoHanging, onTap: () => setState(() => _isAutoHanging = !_isAutoHanging)),
              ],
            )
          else
            ActionChip(
              avatar: const Icon(Icons.anchor, size: 16),
              label: Text(_endgameLevel == 0 ? "Select Endgame" : "Endgame: Level $_endgameLevel"),
              onPressed: _showEndgamePicker,
              backgroundColor: _endgameLevel > 0 ? purpleTheme.withOpacity(0.2) : Colors.black45,
              labelStyle: TextStyle(color: _endgameLevel > 0 ? purpleTheme : Colors.white),
            ),
        ],
      ),
    );
  }

  void _showConfirmDialog() {
    // UPDATED LOGIC: Auto Fuels (* 1) and Teleop Fuels (* 1)
    int pts = (_autoBallCount * 1) + (_isLeave ? 3 : 0) + (_isAutoHanging ? 15 : 0) + (_teleopBallCount * 1) + (_endgameLevel * 10);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF2B2930),
        title: const Text("Confirm Submission", style: TextStyle(color: Colors.white)),
        content: Text(
          "Auto Fuels: $_autoBallCount | Teleop Fuels: $_teleopBallCount\nEstimated Score: $pts pts",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(child: const Text("Back"), onPressed: () => Navigator.pop(c)),
          FilledButton(
              child: const Text("Submit Report"),
              onPressed: () { Navigator.pop(c); _handleUpload(); }
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload() async {
    _showLoading();
    try {
      final response = await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/submit-report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'matchNumber': widget.matchNumber,
          'teamNumber': widget.teamNumber,
          'position': widget.position,
          'autoBallCount': _autoBallCount,
          'teleopBallCount': _teleopBallCount,
          'isAutoHanging': _isAutoHanging,
          'isLeave': _isLeave,
          'endgameLevel': _endgameLevel,
          'user': widget.userName,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted) {
          Navigator.pop(context); // Close loading
          Navigator.push(context, MaterialPageRoute(builder: (context) => RatingPage(
            roomName: widget.roomName,
            reportIndex: result['index'],
            reportData: {'teamNumber': widget.teamNumber, 'matchNumber': widget.matchNumber},
          )));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError("Upload Failed", "Connection error or server timeout.");
      }
    }
  }

  void _showLoading() => showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
  void _showError(String t, String m) => showDialog(context: context, builder: (c) => AlertDialog(title: Text(t), content: Text(m), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]));
}