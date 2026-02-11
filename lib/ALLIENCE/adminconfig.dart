import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'alltotal.dart';
import 'api.dart';

class AdminConfig extends StatefulWidget {
  final String roomName;
  final Map<String, List<String>>? initialTbaData;

  const AdminConfig({
    super.key,
    required this.roomName,
    this.initialTbaData,
  });

  @override
  State<AdminConfig> createState() => _AdminConfigState();
}

class _AdminConfigState extends State<AdminConfig> {
  Map<String, String> assignments = {};
  Map<String, String> teams = {};
  List<int> availableMatches = [1];
  List<dynamic> activeUsers = [];
  int currentMatch = 1;
  bool isLoading = true;
  bool _isSyncing = false;

  final Color primaryDark = const Color(0xFF1A1C1E);
  final Color cardColor = Colors.white;
  final Color redAlliance = const Color(0xFFE53935);
  final Color blueAlliance = const Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // --- Logic Section ---

  Future<void> _initializeData() async {
    if (widget.initialTbaData != null && widget.initialTbaData!.isNotEmpty) {
      _parseTbaToLocal(1);
      await _bulkUploadTbaData();
      await fetchConfig();
      setState(() {
        availableMatches = widget.initialTbaData!.keys.map(int.parse).toList()..sort();
        isLoading = false;
      });
    } else {
      await fetchConfig();
    }
  }

  void _parseTbaToLocal(int matchNum) {
    final matchKey = matchNum.toString();
    if (widget.initialTbaData != null && widget.initialTbaData!.containsKey(matchKey)) {
      List<String> teamList = widget.initialTbaData![matchKey]!;
      setState(() {
        teams = {
          "Blue 1": teamList[0], "Blue 2": teamList[1], "Blue 3": teamList[2],
          "Red 1": teamList[3], "Red 2": teamList[4], "Red 3": teamList[5],
        };
      });
    }
  }

  Future<void> fetchConfig() async {
    try {
      final res = await http.get(Uri.parse(
          '${Api.serverIp}/v1/rooms/get-match-config?roomName=${widget.roomName}&match=$currentMatch'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          assignments = Map<String, String>.from(data['assigned'] ?? {});
          teams = Map<String, String>.from(data['teams'] ?? {});
          availableMatches = List<int>.from(data['availableMatches'] ?? [1]);
          activeUsers = data['activeUsers'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  Future<void> autoSave() async {
    final body = json.encode({
      "roomName": widget.roomName,
      "matchNumber": currentMatch,
      "assignments": assignments,
      "teams": teams
    });
    try {
      await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/save-config'),
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      debugPrint("Auto-saved Match $currentMatch");
    } catch (e) {
      debugPrint("Auto-save failed: $e");
    }
  }

  void _addNewMatch() {
    int nextMatch = (availableMatches.isEmpty ? 0 : availableMatches.last) + 1;
    setState(() {
      availableMatches.add(nextMatch);
      currentMatch = nextMatch;
      teams = {};
    });
    autoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added Match $nextMatch"), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _syncMatchData() async {
    setState(() => _isSyncing = true);
    try {
      _parseTbaToLocal(currentMatch);
      await autoSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Match $currentMatch synced with TBA data"), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _bulkUploadTbaData() async {
    try {
      final schedule = {};
      widget.initialTbaData!.forEach((mNum, tList) {
        schedule[mNum] = {
          "Blue 1": tList[0], "Blue 2": tList[1], "Blue 3": tList[2],
          "Red 1": tList[3], "Red 2": tList[4], "Red 3": tList[5],
        };
      });
      await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/set-schedule'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"roomName": widget.roomName, "schedule": schedule}),
      );
    } catch (e) { debugPrint("Bulk upload error: $e"); }
  }

  void _goToAllTotal() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AllTotalPage(roomName: widget.roomName)));
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.analytics_outlined, color: Colors.blueAccent),
          onPressed: _goToAllTotal,
        ),
        title: Text(widget.roomName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_done_outlined, color: Colors.green),
            onPressed: autoSave,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchHeader(),
            const SizedBox(height: 24),
            _buildSectionTitle("RED ALLIANCE", redAlliance),
            _buildStationCard("Red 1", redAlliance),
            _buildStationCard("Red 2", redAlliance),
            _buildStationCard("Red 3", redAlliance),
            const SizedBox(height: 24),
            _buildSectionTitle("BLUE ALLIANCE", blueAlliance),
            _buildStationCard("Blue 1", blueAlliance),
            _buildStationCard("Blue 2", blueAlliance),
            _buildStationCard("Blue 3", blueAlliance),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF00BCD4)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Current Configuration", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text("Match $currentMatch", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showMatchSelector,
                    child: const Text("Switch ▾"),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add),
                    onPressed: _addNewMatch,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          InkWell(
            onTap: _isSyncing ? null : _syncMatchData,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isSyncing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text("Sync Match Teams (TBA)", style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
    );
  }

  Widget _buildStationCard(String pos, Color accentColor) {
    String scoutName = assignments[pos] ?? "";
    bool isAssigned = scoutName.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 6, decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
            const SizedBox(width: 16),
            SizedBox(width: 50, child: Text(pos, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor))),
            SizedBox(
              width: 60,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: (v) { teams[pos] = v; autoSave(); },
                controller: TextEditingController(text: teams[pos] ?? ""),
                decoration: const InputDecoration(hintText: "Team #", border: InputBorder.none, hintStyle: TextStyle(fontSize: 14)),
              ),
            ),
            const VerticalDivider(indent: 10, endIndent: 10, width: 20),
            Expanded(
              child: PopupMenuButton<String>(
                offset: const Offset(0, 40),
                onSelected: (val) { setState(() => assignments[pos] = val); autoSave(); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: isAssigned ? Colors.black87 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(isAssigned ? scoutName : "Assign User", style: TextStyle(color: isAssigned ? Colors.black87 : Colors.grey, fontSize: 14), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: "", child: Text("Clear Assignment", style: TextStyle(color: Colors.red))),
                  const PopupMenuDivider(),
                  ...activeUsers.map((u) {
                    final String name = u is String ? u : u['name'];
                    return PopupMenuItem(value: name, child: Text(name));
                  })
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _showMatchSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Match", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableMatches.length,
                itemBuilder: (context, index) {
                  int m = availableMatches[index];
                  return ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text("Match $m", style: TextStyle(fontWeight: m == currentMatch ? FontWeight.bold : FontWeight.normal)),
                    trailing: m == currentMatch ? const Icon(Icons.check, color: Colors.blue) : null,
                    onTap: () {
                      setState(() { currentMatch = m; fetchConfig(); });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}