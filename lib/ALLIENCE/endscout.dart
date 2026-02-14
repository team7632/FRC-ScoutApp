import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';
import 'startscout.dart';

class RatingPage extends StatefulWidget {
  final String roomName;
  final int reportIndex;
  final Map<String, dynamic> reportData;

  const RatingPage({
    super.key,
    required this.roomName,
    required this.reportData,
    required this.reportIndex,
  });

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  // --- UI Styling ---
  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);

  // --- State Data ---
  int _selectedRating = 3;
  double _accuracyRating = 0.5;
  final TextEditingController _notesController = TextEditingController();
  bool _isSending = false;

  // 定義駕駛表現層級
  final List<Map<String, dynamic>> _ratingLevels = [
    {'label': '夯', 'value': 5, 'color': const Color(0xFFFF5252)},
    {'label': '人上人', 'value': 4, 'color': const Color(0xFFFFAB40)},
    {'label': '人機', 'value': 3, 'color': const Color(0xFF64B5F6)},
    {'label': '神人', 'value': 2, 'color': const Color(0xFF8D6E63)},
    {'label': '拉完了', 'value': 1, 'color': const Color(0xFF424242)},
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  /// 提交最終分析報告
  Future<void> _submitRating() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    HapticFeedback.heavyImpact();

    try {
      final response = await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/update-last-report-comment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'index': widget.reportIndex,
          'matchNumber': widget.reportData['matchNumber'],
          'teamNumber': widget.reportData['teamNumber'],
          'rating': _selectedRating,
          'accuracy': (_accuracyRating * 100).toInt(),
          'notes': _notesController.text.isEmpty ? "No special notes." : _notesController.text,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {

        _showSuccessAndExit();
      } else {
        _showError("UPLOAD FAILED", "Server status: ${response.statusCode}");
      }
    } catch (e) {
      _showError("CONNECTION ERROR", "Check your network: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessAndExit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Analysis Saved Successfully!"), backgroundColor: Colors.green),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => StartScout(roomName: widget.roomName)),
          (route) => false,
    );
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("TRY AGAIN"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("MATCH ANALYSIS", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white54)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickHeader(),
            const SizedBox(height: 32),

            _sectionLabel("SHOOTING ACCURACY"),
            const SizedBox(height: 16),
            _buildAccuracySlider(),

            const SizedBox(height: 40),

            _sectionLabel("DRIVER PERFORMANCE"),
            const SizedBox(height: 16),
            ..._ratingLevels.map((level) => _buildRatingCard(level)),

            const SizedBox(height: 24),
            _sectionLabel("SCOUT NOTES"),
            const SizedBox(height: 12),
            _buildNotesField(),

            const SizedBox(height: 40),
            _buildDoneButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2));
  }

  Widget _buildQuickHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TEAM ${widget.reportData['teamNumber']}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              Text("MATCH #${widget.reportData['matchNumber']}", style: TextStyle(color: accentPurple, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Text("EST. POINTS", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                Text("${widget.reportData['autoBallCount'] + widget.reportData['teleopBallCount']}",
                    style: TextStyle(color: accentPurple, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAccuracySlider() {
    int percent = (_accuracyRating * 100).toInt();
    Color activeColor = Color.lerp(Colors.redAccent, accentPurple, _accuracyRating)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: activeColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$percent%", style: TextStyle(color: activeColor, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              Icon(Icons.track_changes_rounded, color: activeColor.withOpacity(0.5), size: 28),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: activeColor.withOpacity(0.2),
              trackHeight: 10,
            ),
            child: Slider(
              value: _accuracyRating,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _accuracyRating = val);
              },
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("LOW PRECISION", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
              Text("SNIPER ACCURACY", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> level) {
    bool isSelected = _selectedRating == level['value'];
    Color color = level['color'] as Color;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRating = level['value']);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.05), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(level['label'],
                style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                    letterSpacing: 1
                )),
            if (isSelected) Icon(Icons.stars_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 4,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: "Add details about robot stability, defense, or failures...",
        hintStyle: const TextStyle(color: Colors.white10),
        filled: true,
        fillColor: Colors.black26,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: primaryPurple.withOpacity(0.5))),
      ),
    );
  }

  Widget _buildDoneButton() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: _isSending ? [] : [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        onPressed: _isSending ? null : _submitRating,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white10,
          minimumSize: const Size(double.infinity, 70),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: _isSending
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : const Text("FINISH MATCH ANALYSIS", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }
}