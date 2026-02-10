import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'alltotal.dart';
import 'api.dart';

class AdminConfig extends StatefulWidget {
  final String roomName;
  const AdminConfig({super.key, required this.roomName});

  @override
  State<AdminConfig> createState() => _AdminConfigState();
}

class _AdminConfigState extends State<AdminConfig> {
  final String serverIp = Api.serverIp;
  bool _isLoading = true;
  bool _isAutoSaving = false;
  Timer? _debounce;

  int _viewingMatch = 1;
  List<int> _availableMatches = [1];
  List<String> _allActiveUserNames = ["尚未分配"];

  final Map<String, TextEditingController> _userControllers = {
    'Red 1': TextEditingController(text: "尚未分配"), 'Red 2': TextEditingController(text: "尚未分配"), 'Red 3': TextEditingController(text: "尚未分配"),
    'Blue 1': TextEditingController(text: "尚未分配"), 'Blue 2': TextEditingController(text: "尚未分配"), 'Blue 3': TextEditingController(text: "尚未分配"),
  };
  final Map<String, TextEditingController> _teamControllers = {
    'Red 1': TextEditingController(), 'Red 2': TextEditingController(), 'Red 3': TextEditingController(),
    'Blue 1': TextEditingController(), 'Blue 2': TextEditingController(), 'Blue 3': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _fetchConfigForMatch(1);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (var c in _userControllers.values) c.dispose();
    for (var c in _teamControllers.values) c.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    setState(() => _isAutoSaving = true);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => _saveCurrentEdit());
  }

  Future<void> _fetchConfigForMatch(int matchNum) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$serverIp/v1/rooms/get-match-config?roomName=${widget.roomName}&match=$matchNum'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _viewingMatch = matchNum;
          final List rawUsers = data['activeUsers'] ?? [];
          _allActiveUserNames = ["尚未分配"];
          for (var u in rawUsers) {
            if (u is Map) _allActiveUserNames.add(u['name'].toString());
            else if (u is String) _allActiveUserNames.add(u);
          }
          if (data['availableMatches'] != null) {
            _availableMatches = List<int>.from(data['availableMatches']);
            _availableMatches.sort();
          }
          final Map<String, dynamic> assigned = data['assigned'] ?? {};
          _userControllers.forEach((k, v) {
            String? val = assigned[k]?.toString();
            v.text = (val == null || val == "null" || val == "") ? "尚未分配" : val;
          });
          final Map<String, dynamic> teams = data['teams'] ?? {};
          _teamControllers.forEach((k, v) => v.text = teams[k]?.toString() ?? "");
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCurrentEdit() async {
    Map<String, String> userMap = {};
    Map<String, String> teamMap = {};
    _userControllers.forEach((k, v) => userMap[k] = v.text == "尚未分配" ? "" : v.text);
    _teamControllers.forEach((k, v) => teamMap[k] = v.text.trim());
    try {
      await http.post(Uri.parse('$serverIp/v1/rooms/save-config'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'roomName': widget.roomName,
            'matchNumber': _viewingMatch.toString(),
            'assignments': userMap,
            'teams': teamMap
          }));
    } finally {
      if (mounted) setState(() => _isAutoSaving = false);
    }
  }

  Future<void> _pushMatchToScouts() async {
    try {
      await http.post(Uri.parse('$serverIp/v1/rooms/set-current-match'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'roomName': widget.roomName, 'matchNumber': _viewingMatch.toString()}));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("全員已同步至 Match $_viewingMatch"), backgroundColor: Colors.orange.shade800),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // 輕微的灰白色背景
        primaryColor: Colors.purple,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.light),
      ),
      home: Scaffold(
        appBar: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: const Text("部署面板", style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
          actions: [
            if (_isAutoSaving)
              const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple)))),
            IconButton(
              icon: const Icon(Icons.analytics_outlined, color: Colors.purple),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AllTotalPage(roomName: widget.roomName))),
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.purple))
            : ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          children: [
            _buildMatchSelector(),
            const SizedBox(height: 25),
            _buildAllianceHeader("RED ALLIANCE", Colors.red.shade700),
            ...["Red 1", "Red 2", "Red 3"].map((pos) => _buildStationCard(pos, Colors.red.shade700)),
            const SizedBox(height: 20),
            _buildAllianceHeader("BLUE ALLIANCE", Colors.blue.shade700),
            ...["Blue 1", "Blue 2", "Blue 3"].map((pos) => _buildStationCard(pos, Colors.blue.shade700)),
            const SizedBox(height: 40),
            _buildSyncButton(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("當前設定場次", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("Match $_viewingMatch", style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.black87)),
              ],
            ),
          ),
          PopupMenuButton<int>(
            onSelected: (val) => _fetchConfigForMatch(val),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            itemBuilder: (c) => [
              ..._availableMatches.map((m) => PopupMenuItem(value: m, child: Text("Match $m", style: const TextStyle(fontWeight: FontWeight.bold)))),
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: () {
                  int next = (_availableMatches.isEmpty ? 0 : _availableMatches.last) + 1;
                  setState(() => _availableMatches.add(next));
                  _fetchConfigForMatch(next);
                },
                child: Row(
                  children: [Icon(Icons.add, color: Colors.purple.shade700, size: 20), const SizedBox(width: 8), Text("新增下場次", style: TextStyle(color: Colors.purple.shade700))],
                ),
              )
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("切換", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                  Icon(Icons.keyboard_arrow_down, color: Colors.purple)
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAllianceHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(width: 5, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStationCard(String pos, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pos, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                PopupMenuButton<String>(
                  onSelected: (name) {
                    setState(() => _userControllers[pos]!.text = name);
                    _onDataChanged();
                  },
                  offset: const Offset(0, 40),
                  color: Colors.white,
                  itemBuilder: (c) => _allActiveUserNames.map((n) => PopupMenuItem(value: n, child: Text(n))).toList(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(_userControllers[pos]!.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _teamControllers[pos],
              keyboardType: TextInputType.number,
              onChanged: (v) => _onDataChanged(),
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                hintText: "Team",
                hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                filled: true,
                fillColor: color.withOpacity(0.05),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _pushMatchToScouts,
        icon: const Icon(Icons.bolt_rounded, size: 28),
        label: Text("同步 Match $_viewingMatch ", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
        ),
      ),
    );
  }
}