import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // --- Styling ---
  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color redAlliance = const Color(0xFFFF5252);
  final Color blueAlliance = const Color(0xFF448AFF);

  // --- State Data ---
  Map<String, String> assignments = {};
  Map<String, String> teams = {};
  Map<String, dynamic> allMatchConfigs = {};
  List<int> availableMatches = [1];
  List<dynamic> activeUsers = [];
  int currentMatch = 1;
  bool isLoading = true;
  bool _isSaving = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // --- Initialization & Data Fetching ---

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await fetchConfig();

    // Integrate TBA Team Data if provided
    if (widget.initialTbaData != null) {
      widget.initialTbaData!.forEach((key, value) {
        if (!allMatchConfigs.containsKey(key)) {
          allMatchConfigs[key] = {
            "Blue 1": value[0], "Blue 2": value[1], "Blue 3": value[2],
            "Red 1": value[3], "Red 2": value[4], "Red 3": value[5],
          };
        }
      });
      availableMatches = allMatchConfigs.keys.map((e) => int.parse(e)).toList()..sort();
    }

    if (availableMatches.isEmpty) availableMatches = [1];
    _syncTeamsToCurrentMatch();
    setState(() => isLoading = false);
  }

  void _syncTeamsToCurrentMatch() {
    String matchKey = currentMatch.toString();
    if (allMatchConfigs.containsKey(matchKey)) {
      setState(() => teams = Map<String, String>.from(allMatchConfigs[matchKey]));
    } else {
      setState(() => teams = {"Red 1": "", "Red 2": "", "Red 3": "", "Blue 1": "", "Blue 2": "", "Blue 3": ""});
    }
  }

  Future<void> fetchConfig() async {
    try {
      final res = await http.get(
          Uri.parse('${Api.serverIp}/v1/rooms/get-match-config?roomName=${widget.roomName}&match=$currentMatch'),
          headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          currentMatch = int.parse(data['currentMatch'].toString());
          assignments = Map<String, String>.from(data['assigned'] ?? {});
          allMatchConfigs = data['allConfigs'] ?? {};
          availableMatches = allMatchConfigs.keys.map((e) => int.parse(e)).toList()..sort();
          activeUsers = data['activeUsers'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  // --- Control Functions: Jump & Delete ---

  void _jumpToMatch(int m) async {
    HapticFeedback.mediumImpact();
    setState(() {
      currentMatch = m;
      isLoading = true;
    });
    _syncTeamsToCurrentMatch();
    await _forceSaveImmediately();
    await fetchConfig();
    setState(() => isLoading = false);
  }

  void _goToNextMatch() {
    int currentIndex = availableMatches.indexOf(currentMatch);
    int nextMatch = (currentIndex != -1 && currentIndex < availableMatches.length - 1)
        ? availableMatches[currentIndex + 1]
        : currentMatch + 1;
    _jumpToMatch(nextMatch);
  }

  Future<void> _deleteRoom() async {
    bool confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("DELETE ROOM?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("All data for '${widget.roomName}' will be wiped permanently.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final res = await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/delete'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"roomName": widget.roomName}),
      );

      if (res.statusCode == 200 && mounted) {
        // 🔥 Critical Fix: Pop current page and return 'true' to StartScout
        // StartScout will detect this and pop itself to return to RoomList
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  // --- Auto-Save Logic ---

  Future<void> _forceSaveImmediately() async {
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
    } catch (e) {
      debugPrint("Save Error: $e");
    }
  }

  void autoSave() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() => _isSaving = true);
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      await _forceSaveImmediately();
      if (mounted) setState(() => _isSaving = false);
    });
  }

  // --- UI Construction ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: _buildAppBar(),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: accentPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildMatchHeader(),
            const SizedBox(height: 30),
            _buildSectionTitle("RED ALLIANCE", redAlliance),
            ...["Red 1", "Red 2", "Red 3"].map((pos) => _buildStationCard(pos, redAlliance)),
            const SizedBox(height: 20),
            _buildSectionTitle("BLUE ALLIANCE", blueAlliance),
            ...["Blue 1", "Blue 2", "Blue 3"].map((pos) => _buildStationCard(pos, blueAlliance)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      title: Column(
        children: [
          Text(widget.roomName.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Text(_isSaving ? "● SYNCING" : "● ONLINE", style: TextStyle(color: _isSaving ? Colors.orange : Colors.greenAccent, fontSize: 8)),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(icon: Icon(Icons.analytics_outlined, color: accentPurple),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AllTotalPage(roomName: widget.roomName)))),
        IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: _deleteRoom),
      ],
    );
  }

  Widget _buildMatchHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: surfaceDark, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("CONTROL CENTER", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("M$currentMatch", style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            ],
          ),
          Row(
            children: [
              IconButton(onPressed: _showMatchSelector, icon: Icon(Icons.format_list_bulleted_rounded, color: accentPurple)),
              ElevatedButton(
                onPressed: _goToNextMatch,
                style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("NEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(String pos, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: surfaceDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(
        children: [
          Text(pos, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              key: ValueKey("in_${currentMatch}_$pos"),
              initialValue: teams[pos] ?? "",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              keyboardType: TextInputType.number,
              onChanged: (v) { teams[pos] = v; autoSave(); },
              decoration: const InputDecoration(hintText: "----", border: InputBorder.none, hintStyle: TextStyle(color: Colors.white10)),
            ),
          ),
          _buildScoutPicker(pos),
        ],
      ),
    );
  }

  Widget _buildScoutPicker(String pos) {
    String currentScout = assignments[pos] ?? "";
    return PopupMenuButton<String>(
      color: surfaceDark,
      onSelected: (val) { setState(() => assignments[pos] = val); autoSave(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
        child: Text(currentScout.isEmpty ? "UNASSIGNED" : currentScout,
            style: TextStyle(color: currentScout.isEmpty ? Colors.white24 : accentPurple, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: "", child: Text("❌ CLEAR", style: TextStyle(color: Colors.redAccent))),
        ...activeUsers.map((u) => PopupMenuItem(value: u['name'], child: Text(u['name'], style: const TextStyle(color: Colors.white)))),
      ],
    );
  }

  void _showMatchSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: availableMatches.length,
        itemBuilder: (context, index) {
          int m = availableMatches[index];
          return ListTile(
            title: Text("MATCH $m", style: TextStyle(color: m == currentMatch ? accentPurple : Colors.white)),
            onTap: () { Navigator.pop(context); _jumpToMatch(m); },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) => Container(width: double.infinity, padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)));
}