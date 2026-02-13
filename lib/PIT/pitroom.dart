import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../ALLIENCE/api.dart';
import 'package:flutter_application_1/PIT/pitcheckpage.dart';

class PitRoom extends StatefulWidget {
  final List<String> availableRooms;
  final String? initialRoom;

  const PitRoom({super.key, required this.availableRooms, this.initialRoom});

  @override
  State<PitRoom> createState() => _PitRoomState();
}

class _PitRoomState extends State<PitRoom> {
  // --- 視覺風格定義 ---
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color surfaceDark = const Color(0xFF111015);
  final Color cardColor = Colors.white.withOpacity(0.05);

  // --- 狀態變數 ---
  String? _selectedRoom;
  List<String> _allTeams = [];
  List<String> _filteredTeams = [];
  final TextEditingController _searchController = TextEditingController();

  Set<String> _scoutedTeams = {};
  Set<String> _checkingTeams = {};
  Map<String, String> _scouterNames = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.initialRoom ??
        (widget.availableRooms.isNotEmpty ? widget.availableRooms.first : null);
    if (_selectedRoom != null) _fetchAndParseTeams();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ 隊伍搜尋過濾邏輯
  void _onSearchChanged() {
    setState(() {
      _filteredTeams = _allTeams
          .where((team) => team.contains(_searchController.text.trim()))
          .toList();
    });
  }

  // ✅ 取得房間內所有隊伍
  Future<void> _fetchAndParseTeams() async {
    if (_selectedRoom == null) return;
    setState(() {
      _isLoading = true;
      _scoutedTeams.clear();
      _checkingTeams.clear();
      _searchController.clear();
    });

    try {
      final url = '${Api.serverIp}/v1/rooms/get-match-config?roomName=${Uri.encodeComponent(_selectedRoom!)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Set<String> teamSet = {};

        if (data['allConfigs'] != null) {
          Map<String, dynamic> configs = data['allConfigs'];
          configs.forEach((matchKey, stations) {
            if (stations is Map) {
              stations.forEach((position, teamNum) {
                if (teamNum != null && teamNum.toString().trim().isNotEmpty) {
                  teamSet.add(teamNum.toString().trim());
                }
              });
            }
          });
        }

        final sortedList = teamSet.toList();
        sortedList.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

        if (mounted) {
          setState(() {
            _allTeams = sortedList;
            _filteredTeams = sortedList;
            _isLoading = false;
            _checkingTeams.addAll(_allTeams);
          });
          _syncPitStatus();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 批次同步隊伍 Pit 狀態
  Future<void> _syncPitStatus() async {
    const int batchSize = 5;
    for (int i = 0; i < _allTeams.length; i += batchSize) {
      if (!mounted) break;
      final end = (i + batchSize < _allTeams.length) ? i + batchSize : _allTeams.length;
      final batch = _allTeams.sublist(i, end);
      await Future.wait(batch.map((team) => _checkSingleTeamStatus(team)));
    }
  }

  Future<void> _checkSingleTeamStatus(String teamNumber) async {
    try {
      final checkUrl = '${Api.serverIp}/v1/pit/get-data?roomName=${Uri.encodeComponent(_selectedRoom!)}&teamNumber=$teamNumber';
      final res = await http.get(Uri.parse(checkUrl)).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['lastUpdated'] != null && mounted) {
          setState(() {
            _scoutedTeams.add(teamNumber);
            _scouterNames[teamNumber] = data['scouterName'] ?? "DONE";
          });
        }
      }
    } finally {
      if (mounted) setState(() => _checkingTeams.remove(teamNumber));
    }
  }

  // ✅ 房間搜尋彈窗邏輯
  void _showRoomSearchDialog() {
    List<String> dialogFilteredRooms = widget.availableRooms;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A191E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: accentPurple.withOpacity(0.2))),
          title: Text("SELECT ROOM", style: TextStyle(color: accentPurple, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "FILTER ROOMS...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: accentPurple.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      dialogFilteredRooms = widget.availableRooms
                          .where((room) => room.toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 15),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: dialogFilteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = dialogFilteredRooms[index];
                      bool isSelected = room == _selectedRoom;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        title: Text(room, style: TextStyle(color: isSelected ? accentPurple : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? Icon(Icons.check_circle, color: accentPurple, size: 20) : null,
                        onTap: () {
                          setState(() {
                            _selectedRoom = room;
                            _fetchAndParseTeams();
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_left_rounded, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text("PIT TRACKER",
                style: TextStyle(color: accentPurple, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)),
            if (_allTeams.isNotEmpty)
              Text("${_scoutedTeams.length} / ${_allTeams.length} COMPLETED",
                  style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: accentPurple),
            onPressed: _fetchAndParseTeams,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildRoomSelector(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryPurple))
                : _buildTeamGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
      child: InkWell(
        onTap: _showRoomSearchDialog,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accentPurple.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.meeting_room_rounded, color: accentPurple, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedRoom ?? "SELECT A ROOM",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.search_rounded, color: accentPurple.withOpacity(0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "SEARCH TEAM NUMBER...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12, letterSpacing: 1),
          prefixIcon: Icon(Icons.search_rounded, color: accentPurple.withOpacity(0.6), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white24, size: 18),
            onPressed: () => _searchController.clear(),
          )
              : null,
          filled: true,
          fillColor: cardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: accentPurple.withOpacity(0.4)),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamGrid() {
    if (_filteredTeams.isEmpty && !_isLoading) {
      return Center(
        child: Text("NO TEAMS FOUND",
            style: TextStyle(color: Colors.white.withOpacity(0.1), fontWeight: FontWeight.bold, letterSpacing: 2)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
      ),
      itemCount: _filteredTeams.length,
      itemBuilder: (context, index) => _buildTeamCard(_filteredTeams[index]),
    );
  }

  Widget _buildTeamCard(String teamNumber) {
    bool isScouted = _scoutedTeams.contains(teamNumber);
    bool isChecking = _checkingTeams.contains(teamNumber);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PitCheckPage(teamNumber: teamNumber, roomName: _selectedRoom ?? "")),
        ).then((_) => _fetchAndParseTeams());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isScouted ? primaryPurple.withOpacity(0.12) : cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isScouted ? primaryPurple : (isChecking ? accentPurple.withOpacity(0.2) : Colors.white10),
            width: isScouted ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 14, right: 14,
              child: isChecking
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))
                  : Icon(isScouted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isScouted ? accentPurple : Colors.white10, size: 18),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(teamNumber,
                      style: TextStyle(color: isScouted ? Colors.white : Colors.white60, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isScouted ? primaryPurple.withOpacity(0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isChecking ? "SYNCING" : (isScouted ? (_scouterNames[teamNumber] ?? "DONE") : "PENDING"),
                      style: TextStyle(color: isScouted ? accentPurple : Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}