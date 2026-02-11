import 'package:flutter/material.dart'; // 切換至 Material
import 'package:flutter/services.dart';
import 'package:flutter_application_1/ALLIENCE/startscout.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

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

  // 定義評價等級，使用更現代的 M3 色彩
  final List<Map<String, dynamic>> _ratingLevels = [
    {'label': '夯 ', 'value': 5, 'color': Colors.redAccent},
    {'label': '人上人', 'value': 4, 'color': Colors.orangeAccent},
    {'label': '普通', 'value': 3, 'color': Colors.blueGrey},
    {'label': '人機', 'value': 2, 'color': Colors.brown},
    {'label': '拉完了', 'value': 1, 'color': Colors.grey.shade900},
  ];


  @override
  void initState() {
    super.initState();
    // 回到直向顯示以利輸入備註
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
          'roomName': widget.roomName, // 👈 這裡直接用 widget 傳進來的 roomName
          'index': widget.reportIndex,
          'rating': _selectedRating,
          'notes': _notesController.text,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        // ✅ 修正：使用 pushAndRemoveUntil 回到 StartScout 並清空過往頁面堆疊
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => StartScout(roomName: widget.roomName),
            settings: const RouteSettings(name: 'StartScout'),
          ),
              (route) => false, // 這一行會刪除所有舊頁面
        );
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      debugPrint("Error: $e");
      _showError("上傳失敗", "網路異常或資料錯誤，請稍後再試。");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
                title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(msg),
            actions: [
              TextButton(
                  child: const Text("確定"),
                  onPressed: () => Navigator.pop(c)
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Drive Score",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              Text(
                "Match ${widget.reportData['matchNumber']}",
                style: TextStyle(color: Colors.grey.shade600,
                    fontSize: 14,
                    letterSpacing: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                "Team ${widget.reportData['teamNumber']}",
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 32),

              // 評價選擇區域
              ..._ratingLevels.map((level) => _buildRatingCard(level)),

              const SizedBox(height: 24),

              // 備註輸入框
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "輸入更多詳細備註",
                  hintStyle: const TextStyle(
                      fontSize: 14, color: Colors.black26),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme
                        .of(context)
                        .colorScheme
                        .primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 提交按鈕
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSending ? null : _submitRating,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSending
                      ? const SizedBox(width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text("DONE", style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> level) {
    bool isSelected = _selectedRating == level['value'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected ? level['color'] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isSelected ? 4 : 0,
        shadowColor: level['color'].withOpacity(0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedRating = level['value']),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey
                    .withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  level['label'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    right: 20,
                    child: Icon(
                        Icons.check_circle, color: Colors.white, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

