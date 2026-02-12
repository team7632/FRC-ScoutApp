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
  int _selectedRating = 3;
  final TextEditingController _notesController = TextEditingController();
  bool _isSending = false;

  final List<Map<String, dynamic>> _ratingLevels = [
    {'label': '夯 (Top Tier)', 'value': 5, 'color': Colors.redAccent},
    {'label': '人上人', 'value': 4, 'color': Colors.orangeAccent},
    {'label': '普通', 'value': 3, 'color': Colors.blueGrey},
    {'label': '人機 (Bot)', 'value': 2, 'color': Colors.brown},
    {'label': '拉完了 (Choked)', 'value': 1, 'color': Colors.black},
  ];

  @override
  void initState() {
    super.initState();
    // 評價頁面強制轉回直向，方便打字
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _submitRating() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final response = await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/update-last-report-comment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'index': widget.reportIndex,
          'rating': _selectedRating,
          'notes': _notesController.text,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        // ✅ 核心邏輯：清空頁面棧回到 StartScout
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => StartScout(roomName: widget.roomName),
          ),
              (route) => false,
        );
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      _showError("上傳失敗", "網路異常，請檢查伺服器連線。");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("確定"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Drive Score"),
        centerTitle: true,
        automaticallyImplyLeading: false, // 禁止返回，必須完成評價
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text("Match ${widget.reportData['matchNumber']} | Team ${widget.reportData['teamNumber']}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 20),

              // 評價選擇
              ..._ratingLevels.map((level) => _buildRatingCard(level)),

              const SizedBox(height: 24),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "是否有特殊故障或防禦表現？",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSending ? null : _submitRating,
                  child: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("DONE", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> level) {
    bool isSelected = _selectedRating == level['value'];
    return GestureDetector(
      onTap: () => setState(() => _selectedRating = level['value']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? level['color'] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(level['label'],
                style: TextStyle(fontSize: 16, color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }
}