import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// 導入相關頁面
import 'AdminConfig.dart';
import 'allconfig2.dart'; // 全員查看與修正頁面
import 'scouting.dart';   // 實際錄入數據頁面

class StartScout extends StatefulWidget {
  final String roomName;
  const StartScout({super.key, required this.roomName});

  @override
  State<StartScout> createState() => _StartScoutState();
}

class _StartScoutState extends State<StartScout> {
  final TextEditingController _teamController = TextEditingController();
  int _selectedAlliance = 0; // 0: Red, 1: Blue
  String _assignedPosition = "正在檢查分配...";
  String _matchNumber = "-";
  List<String> _activeUsers = []; // 儲存當前房間所有成員
  bool _isChecking = true;
  bool _isAdmin = false;
  String? _currentUserName;
  Timer? _refreshTimer;

  final String serverIp = "192.168.1.128";

  @override
  void initState() {
    super.initState();
    _initData();
    // 啟動定時刷新：每 5 秒同步一次最新場次、隊號與成員清單
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _checkAssignment();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _teamController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserName = prefs.getString('username');

    // 1. 進入房間報到
    try {
      await http.post(
        Uri.parse('http://$serverIp:3000/v1/rooms/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roomName': widget.roomName, 'user': _currentUserName}),
      );
    } catch (e) {
      debugPrint("報到連線失敗: $e");
    }

    // 2. 檢查權限與獲取初始分配
    await _checkRoomAuthority();
    await _checkAssignment();

    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _checkRoomAuthority() async {
    try {
      final response = await http.get(Uri.parse('http://$serverIp:3000/v1/rooms'));
      if (response.statusCode == 200) {
        final List rooms = jsonDecode(response.body);
        final currentRoom = rooms.firstWhere((r) => r['name'] == widget.roomName, orElse: () => null);
        if (currentRoom != null && currentRoom['owner'] == _currentUserName) {
          setState(() => _isAdmin = true);
        }
      }
    } catch (e) {
      debugPrint("權限檢查失敗: $e");
    }
  }

  // 核心功能：同步伺服器的最新分配與成員名單
  Future<void> _checkAssignment() async {
    try {
      final url = 'http://$serverIp:3000/v1/rooms/assignments?roomName=${widget.roomName}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<String, dynamic> assignedMap = data['assigned'] ?? {};

        // 尋找自己的分配位置
        String? myPos;
        assignedMap.forEach((pos, user) {
          if (user == _currentUserName) myPos = pos;
        });

        if (mounted) {
          setState(() {
            _assignedPosition = myPos ?? "尚未分配位置";
            _matchNumber = data['matchNumber']?.toString() ?? "1";
            _activeUsers = List<String>.from(data['activeUsers'] ?? []);

            // 更新管理員設定的隊號
            if (myPos != null && data['teams'] != null) {
              _teamController.text = data['teams'][myPos]?.toString() ?? "";
            }

            // 根據位置自動切換紅藍樣式
            if (_assignedPosition.startsWith('Red')) {
              _selectedAlliance = 0;
            } else if (_assignedPosition.startsWith('Blue')) {
              _selectedAlliance = 1;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("資料同步錯誤: $e");
    }
  }

  // 彈出顯示成員列表
  void _showActiveUsers() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text("${widget.roomName} 成員列表"),
        message: Text(_activeUsers.isNotEmpty ? _activeUsers.join("、") : "尚無其他成員"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text("關閉"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = _selectedAlliance == 0
        ? CupertinoColors.systemRed
        : CupertinoColors.systemBlue;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showActiveUsers,
          child: const Icon(CupertinoIcons.person_2_fill, size: 24),
        ),
        middle: Text("Match $_matchNumber"),
        trailing: _isAdmin ? CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (c) => AdminConfig(roomName: widget.roomName)),
            ).then((_) => _checkAssignment());
          },
        ) : null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 1. 狀態顯示卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text("我的分配位置", style: TextStyle(color: themeColor.withOpacity(0.8), fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(_assignedPosition, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: themeColor)),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Text("本次偵查隊伍", style: TextStyle(color: CupertinoColors.systemGrey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // 2. 隊號顯示框
              CupertinoTextField(
                controller: _teamController,
                readOnly: true,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: themeColor),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),

              const SizedBox(height: 40),

              // 3. 主要動作：開始錄入
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: (_teamController.text.isEmpty || _assignedPosition.contains("尚未"))
                      ? null
                      : () => _goScouting(),
                  child: const Text("開始錄入數據", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 15),

              // 4. 新功能：全員查看/修正按鈕
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => AllConfig2(roomName: widget.roomName)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.doc_text_search, color: CupertinoColors.systemPurple),
                      SizedBox(width: 8),
                      Text("查看 / 修正全體紀錄", style: TextStyle(color: CupertinoColors.systemPurple, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Text("目前房間人數: ${_activeUsers.length}", style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
              if (_isChecking) const Padding(
                padding: EdgeInsets.only(top: 10),
                child: CupertinoActivityIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goScouting() {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("確認資訊"),
        content: Text("場次：$_matchNumber\n位置：$_assignedPosition\n隊伍：${_teamController.text}"),
        actions: [
          CupertinoDialogAction(child: const Text("取消"), onPressed: () => Navigator.pop(c)),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("開始"),
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => ScoutingPage(
                    roomName: widget.roomName,
                    matchNumber: _matchNumber,
                    teamNumber: _teamController.text,
                    position: _assignedPosition,
                    userName: _currentUserName ?? "Unknown",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}