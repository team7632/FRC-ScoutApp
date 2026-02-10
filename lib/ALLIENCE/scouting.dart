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
  int _autoBallCount = 0;
  int _teleopBallCount = 0;
  bool _isAutoHanging = false;
  bool _isLeave = false;
  int _endgameLevel = 0;
  bool _isAutoMode = true;

  final Color purpleTheme = CupertinoColors.systemPurple;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // --- UI 組件：小計數器 (放入選單用) ---
  Widget _buildMenuCounter() {
    int currentCount = _isAutoMode ? _autoBallCount : _teleopBallCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: purpleTheme, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("進球: ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 35,
            child: Icon(CupertinoIcons.minus_circle, color: purpleTheme, size: 28),
            onPressed: () => setState(() => _isAutoMode
                ? (_autoBallCount > 0 ? _autoBallCount-- : null)
                : (_teleopBallCount > 0 ? _teleopBallCount-- : null)),
          ),
          SizedBox(
            width: 30,
            child: Center(child: Text("$currentCount", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 35,
            child: Icon(CupertinoIcons.plus_circle, color: purpleTheme, size: 28),
            onPressed: () => setState(() => _isAutoMode ? _autoBallCount++ : _teleopBallCount++),
          ),
        ],
      ),
    );
  }

  // 彈出式 Endgame 選擇
  void _showEndgamePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("選擇 Endgame 等級"),
        actions: List.generate(4, (i) => CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _endgameLevel = i);
            Navigator.pop(context);
          },
          child: Text(i == 0 ? "None (未攀爬)" : "Level $i"),
        )),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
      ),
    );
  }

  // 選單按鈕
  Widget _buildMenuButton({required String label, required bool isActive, required VoidCallback onTap, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: isActive ? purpleTheme : Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: purpleTheme, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 16),
            if (icon != null) const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // 背景圖保持清晰
          Positioned.fill(
            child: Image.asset(
                'assets/images/field2026.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.black)
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 頂部導航與資訊
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(CupertinoIcons.left_chevron, color: purpleTheme, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text("M${widget.matchNumber} - T${widget.teamNumber}",
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(widget.position, style: TextStyle(color: widget.position.contains('Red') ? Colors.red : Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),

                  const Spacer(),

                  // --- 左下角集中控制面板 ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: purpleTheme, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. 模式切換
                            CupertinoSegmentedControl<bool>(
                              groupValue: _isAutoMode,
                              selectedColor: purpleTheme,
                              borderColor: purpleTheme,
                              onValueChanged: (v) => setState(() => _isAutoMode = v),
                              children: const {
                                true: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("AUTO", style: TextStyle(fontSize: 12))),
                                false: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("TELEOP", style: TextStyle(fontSize: 12))),
                              },
                            ),
                            const SizedBox(height: 15),

                            // 2. 進球計數器 (現在整合進選單)
                            _buildMenuCounter(),
                            const SizedBox(height: 15),

                            // 3. 模式特定功能
                            if (_isAutoMode) ...[
                              Row(
                                children: [
                                  _buildMenuButton(label: "Leave", isActive: _isLeave, onTap: () => setState(() => _isLeave = !_isLeave)),
                                  const SizedBox(width: 10),
                                  _buildMenuButton(label: "AutoHang", isActive: _isAutoHanging, onTap: () => setState(() => _isAutoHanging = !_isAutoHanging)),
                                ],
                              ),
                            ] else ...[
                              _buildMenuButton(
                                label: _endgameLevel == 0 ? "Select Endgame" : "Endgame: L$_endgameLevel",
                                isActive: _endgameLevel > 0,
                                onTap: _showEndgamePicker,
                                icon: CupertinoIcons.up_arrow,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Spacer(),

                      // --- 右下角提交按鈕 ---
                      CupertinoButton(
                        color: purpleTheme,
                        borderRadius: BorderRadius.circular(50),
                        padding: const EdgeInsets.all(20),
                        onPressed: _showConfirmDialog,
                        child: const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 30),
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

  void _showConfirmDialog() {
    int pts = (_autoBallCount * 4) + (_isLeave ? 3 : 0) + (_isAutoHanging ? 15 : 0) + (_teleopBallCount * 2) + (_endgameLevel * 10);
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("確認提交數據"),
        content: Text("Auto: $_autoBallCount球 | Tele: $_teleopBallCount球\n預計得分：$pts pt"),
        actions: [
          CupertinoDialogAction(child: const Text("返回"), onPressed: () => Navigator.pop(c)),
          CupertinoDialogAction(isDefaultAction: true, child: const Text("確定上傳"), onPressed: () { Navigator.pop(c); _handleUpload(); }),
        ],
      ),
    );
  }

  Future<void> _handleUpload() async {
    _showLoadingIndicator();
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
          Navigator.pop(context);
          Navigator.push(context, CupertinoPageRoute(builder: (context) => RatingPage(
            roomName: widget.roomName,
            reportIndex: result['index'],
            reportData: {'teamNumber': widget.teamNumber, 'matchNumber': widget.matchNumber},
          )));
        }
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); _showErrorAlert("上傳失敗", "網路異常"); }
    }
  }

  void _showLoadingIndicator() => showCupertinoDialog(context: context, builder: (c) => const Center(child: CupertinoActivityIndicator(radius: 15, color: Colors.white)));
  void _showErrorAlert(String t, String m) => showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(title: Text(t), content: Text(m), actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(c))]));
}