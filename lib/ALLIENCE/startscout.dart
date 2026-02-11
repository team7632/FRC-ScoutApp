import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  int _selectedAlliance = 0; // 0: Red, 1: Blue
  String _assignedPosition = "Checking Assignment...";
  String _matchNumber = "-";
  List<dynamic> _activeUsers = [];
  bool _isChecking = true;
  bool _isAdmin = false;
  bool _hasRecorded = false;
  bool _isServerDown = false;
  String? _currentUserName;
  Timer? _refreshTimer;

  final Color primaryPurple = const Color(0xFF673AB7);
  final String serverIp = Api.serverIp;

  @override
  void initState() {
    super.initState();
    _initData();
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

    try {
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
      debugPrint("Join room connection failed: $e");
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
      debugPrint("Permission check failed: $e");
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
            _assignedPosition = myPos ?? "Not Assigned";
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
    }
  }

  void _showInstruction(String reason) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Notice", style: TextStyle(fontWeight: FontWeight.w500)),
        content: Text(reason),
        actions: [
          TextButton(child: const Text("Got it"), onPressed: () => Navigator.pop(c)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color allianceColor = _selectedAlliance == 0 ? Colors.red.shade600 : Colors.blue.shade600;
    final bool isTeamEmpty = _teamController.text.isEmpty || _teamController.text == "---";
    final bool canStart = !isTeamEmpty && !_assignedPosition.contains("Not") && !_hasRecorded && !_isServerDown;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Match $_matchNumber", style: const TextStyle(fontWeight: FontWeight.w400)),
        centerTitle: true,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AdminConfig(roomName: widget.roomName))),
            ),
        ],
      ),
      drawer: _buildSideDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              if (_isServerDown) _buildConnectionErrorTile(),
              _buildAssignmentCard(allianceColor),
              const SizedBox(height: 32),
              _buildTeamDisplay(isTeamEmpty, allianceColor),
              const SizedBox(height: 48),
              _buildMainActionButton(canStart, isTeamEmpty),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AllConfig2(roomName: widget.roomName))),
                  child: const Text("View / Edit All Records", style: TextStyle(fontWeight: FontWeight.w400)),
                ),
              ),
              if (_isChecking)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryPurple.withOpacity(0.05)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined, size: 40, color: primaryPurple),
                  const SizedBox(height: 12),
                  Text("Members (${_activeUsers.length})",
                      style: TextStyle(color: primaryPurple, fontSize: 18, fontWeight: FontWeight.w400)),
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
                    radius: 18,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    backgroundColor: primaryPurple.withOpacity(0.1),
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(name[0].toUpperCase(), style: TextStyle(color: primaryPurple, fontSize: 12))
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 15)),
                  trailing: name == _currentUserName ? const Badge(label: Text("You")) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionErrorTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Text("Server Connection Failed", style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Color allianceColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: allianceColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: allianceColor.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text("Your Location", style: TextStyle(color: allianceColor.withOpacity(0.7), fontSize: 14)),
          const SizedBox(height: 12),
          Text(_assignedPosition, style: TextStyle(fontSize: 42, fontWeight: FontWeight.w500, color: allianceColor)),
        ],
      ),
    );
  }

  Widget _buildTeamDisplay(bool isTeamEmpty, Color allianceColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text("Team Number", style: TextStyle(color: Colors.black38, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            isTeamEmpty ? "---" : _teamController.text,
            style: TextStyle(fontSize: 64, fontWeight: FontWeight.w300, color: isTeamEmpty ? Colors.grey[300] : allianceColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(bool canStart, bool isTeamEmpty) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        onPressed: canStart ? () => _goScouting() : () {
          if (_isServerDown) _showInstruction("Server connection failed. Please check your network/IP settings.");
          else if (_assignedPosition.contains("Not")) _showInstruction("The administrator has not assigned you a location yet.");
          else if (isTeamEmpty) _showInstruction("Team numbers for this match have not been set yet.");
          else if (_hasRecorded) _showInstruction("You have already recorded a report for this match.");
        },
        style: FilledButton.styleFrom(
          backgroundColor: _hasRecorded ? Colors.green.shade600 : primaryPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(_hasRecorded ? "Report Submitted" : "Start Scouting",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
      ),
    );
  }

  void _goScouting() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Confirm Details", style: TextStyle(fontWeight: FontWeight.w500)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogInfoRow("Match", "Qualification $_matchNumber"),
            _buildDialogInfoRow("Location", _assignedPosition),
            _buildDialogInfoRow("Team", _teamController.text),
          ],
        ),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(c)),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (context) => ScoutingPage(
                roomName: widget.roomName, matchNumber: _matchNumber, teamNumber: _teamController.text,
                position: _assignedPosition, userName: _currentUserName ?? "Unknown",
              )));
            },
            child: const Text("Start"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(color: Colors.black54)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}