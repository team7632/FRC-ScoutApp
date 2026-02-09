import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// 導入相關頁面
import 'AdminConfig.dart';
import 'allconfig2.dart';
import 'api.dart';
import 'scouting.dart';

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
  List<String> _activeUsers = [];
  bool _isChecking = true;
  bool _isAdmin = false;
  bool _hasRecorded = false; // [新增] 當前場次是否已上傳過報告
  String? _currentUserName;
  Timer? _refreshTimer;

  final String serverIp = Api.serverIp;

  @override
  void initState() {
    super.initState();
    _initData();
    // 啟動定時刷新：每 5 秒同步一次最新場次、隊號與上傳狀態
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
        Uri.parse('$serverIp/v1/rooms/join'),
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
      final response = await http.get(Uri.parse('$serverIp/v1/rooms'));
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

  // --- 核心同步邏輯：檢查場次、隊伍、以及「是否重複錄入」 ---
  Future<void> _checkAssignment() async {
    try {
      final assignUrl = '$serverIp/v1/rooms/assignments?roomName=${widget.roomName}';
      final reportUrl = '$serverIp/v1/rooms/all-reports?roomName=${widget.roomName}';

      // 同時檢查分配與所有報告
      final responses = await Future.wait([
        http.get(Uri.parse(assignUrl)),
        http.get(Uri.parse(reportUrl)),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        final List reports = jsonDecode(responses[1].body);

        final Map<String, dynamic> assignedMap = data['assigned'] ?? {};
        final Map<String, dynamic> teamsMap = data['teams'] ?? {};
        final String remoteMatch = data['matchNumber']?.toString() ?? "1";

        String? myPos;
        assignedMap.forEach((pos, user) {
          if (user == _currentUserName) myPos = pos;
        });

        // [關鍵邏輯]：檢查該房間是否有「這場次 + 這位置」的紀錄
        bool recorded = reports.any((r) =>
        r['matchNumber'].toString() == remoteMatch &&
            r['position'] == myPos);

        if (mounted) {
          setState(() {
            _assignedPosition = myPos ?? "尚未分配位置";
            _matchNumber = remoteMatch;
            _activeUsers = List<String>.from(data['activeUsers'] ?? []);
            _hasRecorded = recorded;

            if (myPos != null) {
              _teamController.text = teamsMap[myPos]?.toString() ?? "";
            } else {
              _teamController.text = "";
            }

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

  void _showActiveUsers() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text("${widget.roomName} 成員列表"),
        message: Text(_activeUsers.isNotEmpty ? _activeUsers.join("、") : "尚無其他成員"),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text("關閉")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = _selectedAlliance == 0 ? CupertinoColors.systemRed : CupertinoColors.systemBlue;

    // 狀態判定邏輯
    bool isTeamEmpty = _teamController.text.isEmpty || _teamController.text == "---" || _teamController.text == "";
    // 必須有隊號、有位置、且這場還沒錄過，才能開始
    bool canStart = !isTeamEmpty && !_assignedPosition.contains("尚未") && !_hasRecorded;

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
            Navigator.push(context, CupertinoPageRoute(builder: (c) => AdminConfig(roomName: widget.roomName))).then((_) => _checkAssignment());
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
                    Text("分配位置", style: TextStyle(color: themeColor.withOpacity(0.8), fontSize: 14)),
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
                controller: isTeamEmpty ? TextEditingController(text: "---") : _teamController,
                readOnly: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: isTeamEmpty ? CupertinoColors.systemGrey4 : themeColor
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),

              const SizedBox(height: 40),

              // 3. 主要按鈕：加入重複錄入檢查
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: canStart ? () => _goScouting() : null,
                  child: Text(
                    _hasRecorded
                        ? "本場數據已完成"
                        : (canStart ? "開始錄入數據" : (isTeamEmpty ? "等待管理員分配..." : "尚未獲取位置")),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // 4. 提示文字
              if (_hasRecorded)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoColors.systemGreen, size: 18),
                      SizedBox(width: 6),
                      Text("You've already recorded this one.！", style: TextStyle(color: CupertinoColors.systemGreen, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              if (_isAdmin && isTeamEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text("⚠️ 您尚未設定本場隊伍，隊員目前無法開始",
                      style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13, fontWeight: FontWeight.bold)),
                ),

              const SizedBox(height: 25),

              // 5. 查看/修正按鈕
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