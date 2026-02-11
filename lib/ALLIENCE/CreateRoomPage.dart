import 'dart:convert';
import 'package:flutter/material.dart'; // 切換至 Material
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class CreateRoomPage extends StatefulWidget {
  final String? initialRoomName;
  final Map<String, List<String>>? allMatchesData;

  const CreateRoomPage({super.key, this.initialRoomName, this.allMatchesData});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  late TextEditingController _roomNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController(text: widget.initialRoomName);
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final String name = _roomNameController.text.trim();
    if (name.isEmpty) {
      _showError("房間名稱不能為空");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? currentUserName = prefs.getString('username');
      final String serverIp = Api.serverIp;

      final Map<String, dynamic> requestBody = {
        'name': name,
        'owner': currentUserName ?? "管理員",
        'allMatches': widget.allMatchesData,
      };

      final response = await http.post(
        Uri.parse('$serverIp/v1/rooms/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        final errorMsg = jsonDecode(response.body)['message'] ?? "未知錯誤";
        _showError("建立失敗: $errorMsg");
      }
    } catch (e) {
      _showError("無法連線至伺服器: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("提示", style: TextStyle(fontWeight: FontWeight.w500)),
        content: Text(msg),
        actions: [
          TextButton(
            child: const Text("確定"),
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int matchCount = widget.allMatchesData?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("建立新房間", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // --- TBA 匯入狀態卡片 (Material 3 風格) ---
            if (matchCount > 0) _buildTbaStatusCard(matchCount),

            const SizedBox(height: 32),

            const Text(
              "房間基本資訊",
              style: TextStyle(fontSize: 14, color: Colors.black54, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),

            // 使用 Material 3 的 TextField 優化輸入體驗
            TextField(
              controller: _roomNameController,
              decoration: InputDecoration(
                hintText: "例如: 2026_TPE_Regional",
                prefixIcon: const Icon(Icons.drive_file_rename_outline, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 48),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text("確認建立並匯入排程", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),

            const SizedBox(height: 24),
            const Center(
              child: Text(
                "建立後，您可以進入部署面板分配 Scout 人員",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w300),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTbaStatusCard(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                "TBA 資料準備就緒",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "已載入 $count 場資格賽。建立房間後系統將自動填充排程隊伍。",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}