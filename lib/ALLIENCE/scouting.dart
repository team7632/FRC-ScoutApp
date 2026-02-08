import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http; // 1. 引入 HTTP 庫
import 'dart:convert';
import 'dart:async';

class ScoutingPage extends StatefulWidget {
  final String roomName;    // 2. 增加 roomName 接收
  final String matchNumber;
  final String teamNumber;
  final String position;
  final String userName;    // 3. 建議傳入用戶名，方便記錄是誰偵查的

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
  int _ballCount = 0;
  final String serverIp = "192.168.1.128"; // 你的 JS 伺服器 IP

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

  // --- 新增：上傳數據到 JS 伺服器的函式 ---
  Future<void> _uploadData() async {
    final url = Uri.parse('http://$serverIp:3000/v1/rooms/submit-report');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'matchNumber': widget.matchNumber,
          'teamNumber': widget.teamNumber,
          'position': widget.position,
          'ballCount': _ballCount,
          'user': widget.userName,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("伺服器回應：提交成功");
      } else {
        throw Exception("伺服器錯誤: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("上傳失敗: $e");
      // 可以在這裡拋出錯誤讓 UI 顯示提示
      rethrow;
    }
  }

  // 修改：提交報告函式
  void _submitReport() {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("提交數據"),
        content: Text("比賽：${widget.matchNumber}\n隊伍：${widget.teamNumber}\n總計進球：$_ballCount\n確定要上傳嗎？"),
        actions: [
          CupertinoDialogAction(child: const Text("取消"), onPressed: () => Navigator.pop(c)),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("確定提交"),
            onPressed: () async {
              Navigator.pop(c); // 關閉對話框

              // 顯示讀取中...
              showCupertinoDialog(
                  context: context,
                  builder: (context) => const Center(child: CupertinoActivityIndicator())
              );

              try {
                await _uploadData(); // 執行上傳
                if (mounted) {
                  Navigator.pop(context); // 關閉讀取中
                  Navigator.pop(context); // 成功後回到上一頁 (StartScout 頁面)
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // 關閉讀取中
                  // 顯示上傳失敗提示
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text("上傳失敗"),
                      content: const Text("請檢查電腦伺服器是否啟動及 WiFi 連線。"),
                      actions: [
                        CupertinoDialogAction(
                            child: const Text("確定"),
                            onPressed: () => Navigator.pop(ctx)
                        ),
                      ],
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... 此處 build 內容與你提供的完全相同，不重複貼上 ...
    // ... 確保 Image.asset 的路徑與 pubspec.yaml 一致 ...
    return CupertinoPageScaffold(
      // 你原本的 Stack 內容
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/field2026.png', // 記得確認資料夾路徑
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
            ),
          ),
          // ... 其餘 UI ...
          // ... (左上角資訊、左下角計數器、右下角按鈕) ...
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Match ${widget.matchNumber}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Team ${widget.teamNumber} (${widget.position})", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        const Text("進球數量", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              color: CupertinoColors.systemRed.withOpacity(0.8),
                              onPressed: () => setState(() { if(_ballCount > 0) _ballCount--; }),
                              child: const Icon(CupertinoIcons.minus, color: Colors.white),
                            ),
                            Container(
                              width: 60,
                              alignment: Alignment.center,
                              child: Text("$_ballCount", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              color: CupertinoColors.systemBlue.withOpacity(0.8),
                              onPressed: () => setState(() => _ballCount++),
                              child: const Icon(CupertinoIcons.add, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _submitReport,
                    child: const Text("提交報告", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}