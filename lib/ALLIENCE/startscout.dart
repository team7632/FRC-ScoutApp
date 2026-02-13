import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'AdminConfig.dart';
import 'RoomListPage.dart';
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
  // --- UI Styling ---
  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);

  // --- State Data ---
  final TextEditingController _teamController = TextEditingController();
  int _selectedAlliance = 0; // 0: Red, 1: Blue
  String _assignedPosition = "Syncing...";
  String _matchNumber = "-";
  List<dynamic> _activeUsers = [];
  bool _isChecking = true;
  bool _isAdmin = false;
  bool _hasRecorded = false;
  bool _isServerDown = false;
  String? _currentUserName;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initData();
    // Refresh every 4 seconds to sync match changes and locking status
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) _checkAssignment();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _teamController.dispose();
    super.dispose();
  }

  // --- Logic & API ---

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserName = prefs.getString('username');
    String? myPhotoUrl = prefs.getString('userPhotoUrl');

    try {
      await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'user': _currentUserName,
          'photoUrl': myPhotoUrl
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Join room failed: $e");
    }

    await _checkRoomAuthority();
    await _checkAssignment();
    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _checkRoomAuthority() async {
    try {
      final response = await http.get(Uri.parse('${Api.serverIp}/v1/rooms'));
      if (response.statusCode == 200) {
        final List rooms = jsonDecode(response.body);
        final currentRoom = rooms.firstWhere((r) => r['name'] == widget.roomName, orElse: () => null);
        if (currentRoom != null && currentRoom['owner'] == _currentUserName) {
          setState(() => _isAdmin = true);
        }
      }
    } catch (e) {
      debugPrint("Authority check failed");
    }
  }

  Future<void> _checkAssignment() async {
    try {
      final assignUrl = '${Api.serverIp}/v1/rooms/assignments?roomName=${widget.roomName}';
      final reportUrl = '${Api.serverIp}/v1/rooms/all-reports?roomName=${widget.roomName}';

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

        // 🔥 Locking Logic: Check if current user has already submitted for this match/position
        bool recorded = reports.any((r) {
          final String rMatch = r['matchNumber']?.toString() ?? "";
          final String rPos = r['position']?.toString() ?? "";
          final String rScouter = (r['scouter'] ?? r['user'] ?? "").toString();

          return rMatch == remoteMatch &&
              rPos == myPos &&
              rScouter == _currentUserName;
        });

        if (mounted) {
          setState(() {
            _assignedPosition = myPos ?? "Not Assigned";
            _matchNumber = remoteMatch;
            _activeUsers = data['activeUsers'] ?? [];
            _hasRecorded = recorded;
            _isServerDown = false;

            if (myPos != null) {
              _teamController.text = teamsMap[myPos]?.toString() ?? "---";
              _selectedAlliance = _assignedPosition.startsWith('Red') ? 0 : 1;
            } else {
              _teamController.text = "---";
            }
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isServerDown = true);
      debugPrint("Sync Error: $e");
    }
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final Color allianceColor = _selectedAlliance == 0 ? Colors.redAccent : Colors.blueAccent;
    final bool isTeamEmpty = _teamController.text.isEmpty || _teamController.text == "---";
    final bool canStart = !isTeamEmpty && !_assignedPosition.contains("Not") && !_hasRecorded && !_isServerDown;

    return Scaffold(
      backgroundColor: darkBg,
      drawer: _buildSideDrawer(),
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [allianceColor.withOpacity(0.12), darkBg],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                if (_isServerDown) _buildConnectionErrorTile(),
                _buildAssignmentCard(allianceColor),
                const SizedBox(height: 32),
                _buildTeamDisplay(isTeamEmpty, allianceColor),
                const SizedBox(height: 48),
                _buildMainActionButton(canStart, isTeamEmpty, allianceColor),
                const SizedBox(height: 16),
                _buildRecordButton(),
                if (_isChecking)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: CircularProgressIndicator(color: Color(0xFFB388FF), strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
        onPressed: () {
          HapticFeedback.mediumImpact();
          // 強制銷毀當前所有路由，跳轉到 RoomListPage
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const RoomListPage()),
                (route) => false, // false 表示清空所有歷史紀錄
          );
        },
      ),
      title: Text("QUAL MATCH $_matchNumber",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: Colors.white)),
      centerTitle: true,
      actions: [
        if (_isAdmin)
          IconButton(
            icon: Icon(Icons.admin_panel_settings_outlined, color: accentPurple),
            onPressed: () async {
              final bool? shouldPopToRoot = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => AdminConfig(roomName: widget.roomName))
              );

              if (shouldPopToRoot == true && mounted) {
                // 管理員設定後若需要強制跳轉
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const RoomListPage()),
                      (route) => false,
                );
              } else {
                _checkAssignment();
              }
            },
          ),
        Builder(builder: (context) {
          return IconButton(
            icon: Icon(Icons.group_rounded, color: accentPurple),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        }),
      ],
    );
  }

  Widget _buildSideDrawer() {
    return Drawer(
      backgroundColor: surfaceDark,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryPurple.withOpacity(0.05)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hub_rounded, size: 40, color: accentPurple),
                  const SizedBox(height: 12),
                  const Text("ROOM MEMBERS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  Text("${_activeUsers.length} Active Users", style: TextStyle(color: accentPurple, fontSize: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _activeUsers.length,
              itemBuilder: (context, index) {
                final user = _activeUsers[index];
                final String name = user['name'] ?? "Unknown";
                final String? photoUrl = user['photoUrl'];

                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    backgroundColor: Colors.white10,
                    child: (photoUrl == null || photoUrl.isEmpty) ? Text(name[0], style: TextStyle(color: accentPurple)) : null,
                  ),
                  title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  trailing: name == _currentUserName ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: primaryPurple, borderRadius: BorderRadius.circular(10)),
                    child: const Text("YOU", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Color allianceColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: allianceColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          const Text("ASSIGNED POSITION", style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(_assignedPosition, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: allianceColor, letterSpacing: -1)),
        ],
      ),
    );
  }

  Widget _buildTeamDisplay(bool isTeamEmpty, Color allianceColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Text("TARGET TEAM", style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            isTeamEmpty ? "WAITING" : _teamController.text,
            style: TextStyle(fontSize: 72, fontWeight: FontWeight.w200, color: isTeamEmpty ? Colors.white10 : Colors.white, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(bool canStart, bool isTeamEmpty, Color allianceColor) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton(
        onPressed: _hasRecorded
            ? () {
          HapticFeedback.vibrate();
          _showInstruction("Data for this match has already been submitted.");
        }
            : (canStart ? () => _goScouting() : () {
          HapticFeedback.vibrate();
          if (_isServerDown) _showInstruction("Cannot connect to server.");
          else if (_assignedPosition.contains("Not")) _showInstruction("Waiting for assignment from admin...");
          else if (isTeamEmpty) _showInstruction("Teams not set for this match.");
        }),
        style: ElevatedButton.styleFrom(
          backgroundColor: _hasRecorded
              ? Colors.green.withOpacity(0.2)
              : (canStart ? primaryPurple : Colors.white10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: _hasRecorded ? const BorderSide(color: Colors.greenAccent, width: 1) : BorderSide.none,
          ),
        ),
        child: Text(
            _hasRecorded ? "✓ DATA RECORDED" : (canStart ? "START SCOUTING" : "LOCKED"),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: _hasRecorded ? Colors.greenAccent : Colors.white
            )
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AllConfig2(roomName: widget.roomName))),
        icon: const Icon(Icons.history_rounded, size: 20),
        label: const Text("VIEW ALL MATCH RECORDS", style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildConnectionErrorTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 16),
          SizedBox(width: 8),
          Text("OFFLINE: CHECK SERVER CONFIG", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  void _goScouting() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("CONFIRM DETAILS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInfoRow("Match", "#$_matchNumber"),
            _buildDialogInfoRow("Position", _assignedPosition),
            _buildDialogInfoRow("Team", _teamController.text),
          ],
        ),
        actions: [
          TextButton(child: const Text("CANCEL"), onPressed: () => Navigator.pop(c)),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (context) => ScoutingPage(
                roomName: widget.roomName,
                matchNumber: _matchNumber,
                teamNumber: _teamController.text,
                position: _assignedPosition,
                userName: _currentUserName ?? "Unknown",
              )));
            },
            child: const Text("READY"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38)),
          Text(value, style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  void _showInstruction(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(reason),
      backgroundColor: surfaceDark,
      behavior: SnackBarBehavior.floating,
    ));
  }
}