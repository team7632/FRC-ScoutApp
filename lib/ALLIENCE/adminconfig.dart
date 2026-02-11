import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
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
  bool _isSaving = false;

  Timer? _debounce;

  // --- 顏色配置：換成紫色調 ---
  final Color brandPurple = const Color(0xFF673AB7);
  final Color lightPurple = const Color(0xFFF3E5F5);
  final Color cardColor = Colors.white;
  final Color redAlliance = const Color(0xFFE53935);
  final Color blueAlliance = const Color(0xFF1E88E5);

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

  // --- 核心邏輯 (保持不變) ---

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
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() => _isSaving = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
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
        if (mounted) setState(() => _isSaving = false);
      } catch (e) {
        if (mounted) setState(() => _isSaving = false);
      }
    });
  }

  Future<void> _deleteRoom() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Room"),
        content: Text("Are you sure you want to delete \"${widget.roomName}\"? All data will be lost."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    setState(() => isLoading = true);
    try {
      await http.delete(Uri.parse('${Api.serverIp}/v1/rooms/delete?roomName=${widget.roomName}'));
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UI 元件 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // 與 RoomListPage 一致的背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.analytics_outlined, color: brandPurple),
          onPressed: _goToAllTotal,
        ),
        title: Column(
          children: [
            Text(widget.roomName, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
            Text(_isSaving ? "Saving..." : "Saved",
                style: TextStyle(color: _isSaving ? Colors.orange : Colors.green, fontSize: 10)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            onPressed: _deleteRoom,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: brandPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildMatchHeader(),
            const SizedBox(height: 24),
            _buildSectionTitle("RED ALLIANCE", redAlliance),
            ...["Red 1", "Red 2", "Red 3"].map((pos) => _buildStationCard(pos, redAlliance)),
            const SizedBox(height: 16),
            _buildSectionTitle("BLUE ALLIANCE", blueAlliance),
            ...["Blue 1", "Blue 2", "Blue 3"].map((pos) => _buildStationCard(pos, blueAlliance)),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 改為紫色漸層
        gradient: LinearGradient(
          colors: [brandPurple, brandPurple.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandPurple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Match $currentMatch",
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: _showMatchSelector,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Switch Match"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isSyncing ? null : _syncMatchData,
            icon: const Icon(Icons.sync, color: Colors.white, size: 16),
            label: const Text("Sync TBA Data", style: TextStyle(color: Colors.white, fontSize: 13)),
          )
        ],
      ),
    );
  }

  Widget _buildStationCard(String pos, Color accentColor) {
    String scoutName = assignments[pos] ?? "";
    bool isAssigned = scoutName.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(pos, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: teams[pos] ?? "",
                  selection: TextSelection.collapsed(offset: (teams[pos] ?? "").length),
                ),
              ),
              onChanged: (v) {
                teams[pos] = v;
                autoSave();
              },
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: "Team", border: InputBorder.none, hintStyle: TextStyle(fontSize: 12)),
            ),
          ),
          const VerticalDivider(width: 20),
          Expanded(
            child: PopupMenuButton<String>(
              onSelected: (val) {
                setState(() => assignments[pos] = val);
                autoSave();
              },
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isAssigned ? scoutName : "Unassigned",
                    style: TextStyle(color: isAssigned ? Colors.black : Colors.grey[400], fontSize: 14)),
                trailing: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(value: "", child: Text("Clear Assignment", style: TextStyle(color: Colors.red))),
                ...activeUsers.map((u) => PopupMenuItem(value: u is String ? u : u['name'], child: Text(u is String ? u : u['name']))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 輔助方法 ---
  void _goToAllTotal() => Navigator.push(context, MaterialPageRoute(builder: (context) => AllTotalPage(roomName: widget.roomName)));

  void _addNewMatch() {
    int next = (availableMatches.isEmpty ? 0 : availableMatches.last) + 1;
    setState(() { availableMatches.add(next); currentMatch = next; teams = {}; });
    autoSave();
  }

  Future<void> _syncMatchData() async {
    setState(() => _isSyncing = true);
    _parseTbaToLocal(currentMatch);
    await autoSave();
    setState(() => _isSyncing = false);
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
      await http.post(Uri.parse('${Api.serverIp}/v1/rooms/set-schedule'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({"roomName": widget.roomName, "schedule": schedule}));
    } catch (_) {}
  }

  void _showMatchSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          ListTile(
              title: Text("Add New Match", style: TextStyle(color: brandPurple, fontWeight: FontWeight.bold)),
              leading: Icon(Icons.add_circle_outline, color: brandPurple),
              onTap: () { _addNewMatch(); Navigator.pop(context); }),
          const Divider(),
          ...availableMatches.map((m) => ListTile(
            title: Text("Match $m", style: TextStyle(fontWeight: currentMatch == m ? FontWeight.bold : FontWeight.normal)),
            trailing: currentMatch == m ? Icon(Icons.check_circle, color: brandPurple) : null,
            onTap: () { setState(() { currentMatch = m; fetchConfig(); }); Navigator.pop(context); },
          ))
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
    );
  }
}