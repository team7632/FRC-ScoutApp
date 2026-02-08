import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // 1. 確保有 import

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _roomNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createRoom() async {
    final name = _roomNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 【關鍵新增】強制刷新本地緩存，確保讀到 People.dart 存入的最新名字
      await prefs.reload();

      final String? currentUserName = prefs.getString('username');

      debugPrint("---------------------------------");
      debugPrint("📱 讀取測試結果: [$currentUserName]");
      debugPrint("📱 所有儲存的 Keys: ${prefs.getKeys()}");
      debugPrint("---------------------------------");

      final response = await http.post(
        Uri.parse('http://192.168.1.128:3000/v1/rooms/create'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'owner': currentUserName ?? "匿名用戶",
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.pop(context);
      } else {
        debugPrint("❌ 伺服器拒絕: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ 連線異常: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("建立新房間"),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 40),
            const Text(
              "房間名稱",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _roomNameController,
              placeholder: "請輸入房間名稱",
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CupertinoColors.systemGrey4),
              ),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CupertinoActivityIndicator()
                : CupertinoButton.filled(
              onPressed: _createRoom,
              child: const Text("確定建立"),
            ),
          ],
        ),
      ),
    );
  }
}