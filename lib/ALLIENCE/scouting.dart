import 'package:flutter/cupertino.dart';
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
  // --- 數據變數 ---
  int _autoBallCount = 0;
  int _teleopBallCount = 0;
  bool _isAutoHanging = false;
  int _endgameLevel = 0; // 0=無, 1=L1, 2=L2, 3=L3

  // 模式切換：true = Auto, false = Teleop
  bool _isAutoMode = true;

  @override
  void initState() {
    super.initState();
    // 強制橫向螢幕
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 離開時恢復直向
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  /// 執行上傳並跳轉
  Future<void> _handleUpload() async {
    _showLoadingIndicator();
    try {
      final response = await http.post(
        Uri.parse('http://${Api.serverIp}:3000/v1/rooms/submit-report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'matchNumber': widget.matchNumber,
          'teamNumber': widget.teamNumber,
          'position': widget.position,
          'autoBallCount': _autoBallCount,
          'teleopBallCount': _teleopBallCount,
          'isAutoHanging': _isAutoHanging,
          'endgameLevel': _endgameLevel,
          'user': widget.userName,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        int reportIndex = result['index']; // 從後端取得該筆報告的索引

        if (mounted) {
          Navigator.pop(context); // 關閉 Loading

          // 跳轉至鑑定頁面 (RatingPage)
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => RatingPage(
                roomName: widget.roomName,
                reportIndex: reportIndex,
                reportData: {
                  'teamNumber': widget.teamNumber,
                  'matchNumber': widget.matchNumber,
                },
              ),
            ),
          );
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorAlert("上傳失敗", "網路異常或伺服器未回應。");
      }
    }
  }

  void _submitReport() {
    int totalPts = _autoBallCount + (_isAutoHanging ? 15 : 0) + _teleopBallCount + (_endgameLevel * 10);

    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("確認提交"),
        content: Text("預估得分：$totalPts pt\n提交後將進行駕駛鑑定。"),
        actions: [
          CupertinoDialogAction(child: const Text("取消"), onPressed: () => Navigator.pop(c)),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("確定"),
            onPressed: () {
              Navigator.pop(c);
              _handleUpload();
            },
          ),
        ],
      ),
    );
  }

  void _showLoadingIndicator() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 15)),
    );
  }

  void _showErrorAlert(String title, String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(child: const Text("好"), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = _isAutoMode ? CupertinoColors.systemYellow : CupertinoColors.systemBlue;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // 背景與遮罩
          Positioned.fill(child: Container(color: Colors.black)),
          Positioned.fill(child: Opacity(opacity: 0.3, child: Image.asset('assets/images/field2026.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => Container()))),

          SafeArea(
            child: Stack(
              children: [
                // 頂部資訊與切換
                Positioned(
                  top: 15, left: 20,
                  child: Text("M${widget.matchNumber} - T${widget.teamNumber}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  top: 15, left: 0, right: 0,
                  child: Center(
                    child: CupertinoSegmentedControl<bool>(
                      groupValue: _isAutoMode,
                      borderColor: Colors.white54,
                      selectedColor: activeColor,
                      onValueChanged: (v) => setState(() => _isAutoMode = v),
                      children: const {
                        true: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("AUTO")),
                        false: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("TELEOP")),
                      },
                    ),
                  ),
                ),

                // 左下控制台
                Positioned(
                  bottom: 20, left: 20,
                  child: Row(
                    children: [
                      _buildCounter(activeColor),
                      const SizedBox(width: 15),
                      _isAutoMode ? _buildHangToggle() : _buildEndgameGrid(),
                    ],
                  ),
                ),

                // 右下提交按鈕
                Positioned(
                  bottom: 20, right: 20,
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    onPressed: _submitReport,
                    child: const Text("提交報告", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color)
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            // 修正這裡：minus_circle -> minus_circled
            child: const Icon(CupertinoIcons.minus_circled, color: Colors.red, size: 30),
            onPressed: () => setState(() => _isAutoMode
                ? (_autoBallCount > 0 ? _autoBallCount-- : null)
                : (_teleopBallCount > 0 ? _teleopBallCount-- : null)),
          ),
          Text(
              _isAutoMode ? "$_autoBallCount" : "$_teleopBallCount",
              style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            // 修正這裡：add_circle -> add_circled
            child: const Icon(CupertinoIcons.add_circled, color: Colors.green, size: 30),
            onPressed: () => setState(() => _isAutoMode ? _autoBallCount++ : _teleopBallCount++),
          ),
        ],
      ),
    );
  }

  Widget _buildHangToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isAutoHanging = !_isAutoHanging),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _isAutoHanging ? Colors.green : Colors.black87, borderRadius: BorderRadius.circular(15)),
        child: const Text("AUTO 吊掛\n(+15pt)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _buildEndgameGrid() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: List.generate(4, (i) => GestureDetector(
          onTap: () => setState(() => _endgameLevel = i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _endgameLevel == i ? Colors.blue : Colors.white10, borderRadius: BorderRadius.circular(8)),
            child: Text(i == 0 ? "無" : "L$i", style: const TextStyle(color: Colors.white)),
          ),
        )),
      ),
    );
  }
}

