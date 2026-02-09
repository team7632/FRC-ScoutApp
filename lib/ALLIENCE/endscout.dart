import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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

  final List<Map<String, dynamic>> _ratingLevels = [
    {'label': '夯', 'value': 5, 'color': CupertinoColors.systemRed},
    {'label': '人上人', 'value': 4, 'color': CupertinoColors.activeOrange},
    {'label': '普通', 'value': 3, 'color': CupertinoColors.systemGrey},
    {'label': '人機', 'value': 2, 'color': CupertinoColors.systemBrown},
    {'label': '拉完了', 'value': 1, 'color': CupertinoColors.black},
  ];

  @override
  void initState() {
    super.initState();
    // 確保鑑定頁面一定是直向，方便打字與閱讀
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
        // 連續執行兩次 pop，這是最穩定的做法
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      _showError("上傳失敗", "網路異常，請稍後再試。");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String title, String msg) {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(child: const Text("確定"), onPressed: () => Navigator.pop(c)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Drive score"),
        automaticallyImplyLeading: false, // 禁止中途返回，確保數據完整
      ),
      child: SafeArea(
        child: SingleChildScrollView( // 防止鍵盤遮擋
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text("Match ${widget.reportData['matchNumber']}",
                  style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16)),
              Text("Team ${widget.reportData['teamNumber']}",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),

              // 鑑定按鈕列表
              ..._ratingLevels.map((level) {
                bool isSelected = _selectedRating == level['value'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRating = level['value']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: isSelected ? level['color'] : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: isSelected ? [BoxShadow(color: level['color'].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                        border: Border.all(
                          color: isSelected ? level['color'] : CupertinoColors.systemGrey4,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        level['label'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? CupertinoColors.white : level['color'],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 15),

              // 備註框
              CupertinoTextField(
                controller: _notesController,
                placeholder: "輸入更多備註...",
                maxLines: 4,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey4),
                ),
              ),

              const SizedBox(height: 30),

              // 提交按鈕
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: _isSending ? null : _submitRating,
                  child: _isSending
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text("DONE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}