import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _selectedAlliance = 0;
  String _assignedPosition = "正在檢查分配...";
  String _matchNumber = "-";
  List<dynamic> _activeUsers = [];
  bool _isChecking = true;
  bool _isAdmin = false;
  bool _hasRecorded = false;
  bool _isServerDown = false; // 新增：判斷伺服器是否斷線
  String? _currentUserName;
  Timer? _refreshTimer;

  final Color primaryPurple = CupertinoColors.systemPurple;
  final String serverIp = Api.serverIp;

  @override
  void initState() {
    super.initState();
    _initData();
    // 每 5 秒自動同步一次
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
    String? myPhotoUrl = prefs.getString('userPhotoUrl');

    print("【Debug】目前使用者: $_currentUserName, 頭像網址: $myPhotoUrl");

    try {
      // 報到並同步頭像
      await http.post(
        Uri.parse('$serverIp/v1/rooms/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'user': _currentUserName,
          'photoUrl': myPhotoUrl
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("報到連線失敗: $e");
    }

    await _checkRoomAuthority();
    await _checkAssignment();
    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _checkRoomAuthority() async {
    try {
      final response = await http.get(Uri.parse('$serverIp/v1/rooms'));
      if (response.statusCode == 200) {
        final List rooms = jsonDecode(response.body);
        final currentRoom = rooms.firstWhere(
                (r) => r['name'] == widget.roomName,
            orElse: () => null
        );
        if (currentRoom != null && currentRoom['owner'] == _currentUserName) {
          setState(() => _isAdmin = true);
        }
      }
    } catch (e) {
      debugPrint("權限檢查失敗: $e");
    }
  }

  Future<void> _checkAssignment() async {
    try {
      final assignUrl = '$serverIp/v1/rooms/assignments?roomName=${widget.roomName}';
      final reportUrl = '$serverIp/v1/rooms/all-reports?roomName=${widget.roomName}';

      final responses = await Future.wait([
        http.get(Uri.parse(assignUrl)).timeout(const Duration(seconds: 3)),
        http.get(Uri.parse(reportUrl)).timeout(const Duration(seconds: 3)),
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

        bool recorded = reports.any((r) =>
        r['matchNumber'].toString() == remoteMatch && r['position'] == myPos);

        if (mounted) {
          setState(() {
            _assignedPosition = myPos ?? "尚未分配位置";
            _matchNumber = remoteMatch;
            _activeUsers = data['activeUsers'] ?? [];
            _hasRecorded = recorded;
            _isServerDown = false;

            if (myPos != null) {
              _teamController.text = teamsMap[myPos]?.toString() ?? "";
              _selectedAlliance = _assignedPosition.startsWith('Red') ? 0 : 1;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isServerDown = true);
      debugPrint("資料同步錯誤: $e");
    }
  }

  void _showInstruction(String reason) {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("無法開始"),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(reason),
        ),
        actions: [
          CupertinoDialogAction(child: const Text("了解"), onPressed: () => Navigator.pop(c)),
        ],
      ),
    );
  }

  void _showActiveUsers() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: double.infinity,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.person_2_fill, color: primaryPurple),
                          const SizedBox(width: 10),
                          Text("房間成員 (${_activeUsers.length})", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryPurple)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _activeUsers.length,
                        itemBuilder: (context, index) {
                          final user = _activeUsers[index];
                          final String name = user['name'] ?? "Unknown";
                          final String? photoUrl = user['photoUrl'];

                          return CupertinoListTile(
                            leading: ClipOval(
                              child: (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http'))
                                  ? Image.network(
                                photoUrl,
                                width: 36, height: 36, fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => _buildDefaultAvatar(name),
                              )
                                  : _buildDefaultAvatar(name),
                            ),
                            title: Text(name),
                            subtitle: name == _currentUserName ? const Text("（You）", style: TextStyle(fontSize: 12)) : null,
                          );
                        },
                      ),
                    ),
                    CupertinoButton(child: const Text("關閉"), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 36, height: 36,
      color: primaryPurple.withOpacity(0.2),
      child: Center(
        child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
            style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color allianceColor = _selectedAlliance == 0 ? CupertinoColors.systemRed : CupertinoColors.systemBlue;
    bool isTeamEmpty = _teamController.text.isEmpty || _teamController.text == "---" || _teamController.text == "";
    bool canStart = !isTeamEmpty && !_assignedPosition.contains("尚未") && !_hasRecorded && !_isServerDown;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showActiveUsers,
          child: Icon(CupertinoIcons.person_2_fill, color: primaryPurple),
        ),
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Match $_matchNumber"),
            if (_isChecking) const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: CupertinoActivityIndicator(radius: 7),
            ),
          ],
        ),
        trailing: _isAdmin ? CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.settings, color: primaryPurple),
          onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (c) => AdminConfig(roomName: widget.roomName))),
        ) : null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              if (_isServerDown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: CupertinoColors.systemRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.wifi_slash, color: CupertinoColors.systemRed, size: 20),
                        SizedBox(width: 10),
                        Text("伺服器連線中斷，請檢查網路", style: TextStyle(color: CupertinoColors.systemRed, fontSize: 13)),
                      ],
                    ),
                  ),
                ),

              // 分配位置卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: allianceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: allianceColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text("分配位置", style: TextStyle(color: allianceColor.withOpacity(0.8), fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(_assignedPosition, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: allianceColor)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 隊號顯示
              CupertinoTextField(
                controller: TextEditingController(text: isTeamEmpty ? "---" : _teamController.text),
                readOnly: true,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: isTeamEmpty ? CupertinoColors.systemGrey4 : allianceColor),
                decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: CupertinoColors.systemGrey4)),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              const SizedBox(height: 40),

              // 開始按鈕
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: primaryPurple,
                  disabledColor: CupertinoColors.systemGrey4,
                  onPressed: canStart ? () => _goScouting() : () {
                    if (_isServerDown) _showInstruction("伺服器連線失敗，請檢查網路 IP 設定。");
                    else if (_assignedPosition.contains("尚未")) _showInstruction("管理員尚未為您分配位置（Red/Blue）。");
                    else if (isTeamEmpty) _showInstruction("此場次尚未設定編號。");
                    else if (_hasRecorded) _showInstruction("您已經完成此場次的數據錄入，不可重複提交。");
                  },
                  child: Text(_hasRecorded ? "本場數據已完成" : "開始錄入數據",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),

              // 修正按鈕
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: primaryPurple.withOpacity(0.1),
                  onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (c) => AllConfig2(roomName: widget.roomName))),
                  child: Text("查看 / 修正全體紀錄", style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold)),
                ),
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
            child: Text("開始", style: TextStyle(color: primaryPurple)),
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context, CupertinoPageRoute(builder: (context) => ScoutingPage(
                roomName: widget.roomName, matchNumber: _matchNumber, teamNumber: _teamController.text,
                position: _assignedPosition, userName: _currentUserName ?? "Unknown",
              )));
            },
          ),
        ],
      ),
    );
  }
}