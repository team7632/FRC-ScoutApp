import 'package:flutter/cupertino.dart';
import 'package:flutter_application_1/ALLIENCE/scouting.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // 必須引入以使用 Timer
import 'package:shared_preferences/shared_preferences.dart';
import 'AdminConfig.dart';

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
  bool _isChecking = true;
  bool _isAdmin = false;
  String? _currentUserName;
  Timer? _refreshTimer; // 定時器

  final String serverIp = "192.168.1.128";

  @override
  void initState() {
    super.initState();
    _initData();
    // 啟動定時刷新：每 5 秒自動同步一次最新場次與隊號
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _checkAssignment();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // 頁面關閉時務必銷毀計時器
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
        body: jsonEncode(
            {'roomName': widget.roomName, 'user': _currentUserName}),
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
      final response = await http.get(
          Uri.parse('http://$serverIp:3000/v1/rooms'));
      if (response.statusCode == 200) {
        final List rooms = jsonDecode(response.body);
        final currentRoom = rooms.firstWhere((r) =>
        r['name'] == widget.roomName, orElse: () => null);
        if (currentRoom != null && currentRoom['owner'] == _currentUserName) {
          setState(() => _isAdmin = true);
        }
      }
    } catch (e) {
      debugPrint("權限檢查失敗: $e");
    }
  }

  // 核心功能：同步伺服器的最新分配與隊號
  Future<void> _checkAssignment() async {
    try {
      final url = 'http://$serverIp:3000/v1/rooms/check-my-pos?roomName=${widget
          .roomName}&user=$_currentUserName';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _assignedPosition = data['position'] ?? "尚未分配位置";
            _matchNumber = data['matchNumber']?.toString() ?? "1";

            // 只有當輸入框沒被手動修改時，才自動填入管理員設定的隊號
            if (data['teamNumber'] != null && data['teamNumber'] != "") {
              _teamController.text = data['teamNumber'].toString();
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

  @override
  Widget build(BuildContext context) {
    Color themeColor = _selectedAlliance == 0
        ? CupertinoColors.systemRed
        : CupertinoColors.systemBlue;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text("Match $_matchNumber"),
        trailing: _isAdmin ? CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (c) => AdminConfig(roomName: widget.roomName)),
            ).then((_) => _checkAssignment()); // 從設定頁回來立刻刷新一次
          },
        ) : null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 顯示當前任務狀態
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
                    Text("我的分配位置", style: TextStyle(
                        color: themeColor.withOpacity(0.8), fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(_assignedPosition, style: TextStyle(fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: themeColor)),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              const Text("本次偵查隊伍", style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // 自動顯示管理員派發的隊號
              CupertinoTextField(
                controller: _teamController,
                readOnly: true,
                // 隊員不可修改，確保數據一致
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: themeColor),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),

              const SizedBox(height: 60),

              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: (_teamController.text.isEmpty ||
                      _assignedPosition.contains("尚未"))
                      ? null
                      : () => _goScouting(),
                  child: const Text("開始錄入數據",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              if (_isChecking) const CupertinoActivityIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  void _goScouting() {
    showCupertinoDialog(
      context: context,
      builder: (c) =>
          CupertinoAlertDialog(
            title: const Text("確認資訊"),
            content: Text(
                "場次：$_matchNumber\n位置：$_assignedPosition\n隊伍：${_teamController
                    .text}"),
            actions: [
              CupertinoDialogAction(
                  child: const Text("取消"), onPressed: () => Navigator.pop(c)),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text("開始"),
                onPressed: () {
                  Navigator.pop(c); // 關閉對話框

                  // 執行跳轉，補齊 ScoutingPage 所需的參數
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) =>
                          ScoutingPage(
                            roomName: widget.roomName,
                            // 傳入房間名
                            matchNumber: _matchNumber,
                            // 傳入場次
                            teamNumber: _teamController.text,
                            // 傳入隊號
                            position: _assignedPosition,
                            // 傳入位置
                            userName: _currentUserName ?? "Unknown", // 傳入用戶名
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