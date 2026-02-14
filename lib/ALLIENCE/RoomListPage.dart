import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 加入震動回饋
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/ALLIENCE/startscout.dart';
import 'MyHomePage.dart';
import 'api.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {

  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);

  // Data Storage
  List<dynamic> _allRooms = [];
  List<dynamic> _filteredRooms = [];
  bool _isLoading = true;
  String _errorMsg = "";

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    try {
      final url = Uri.parse('${Api.serverIp}/v1/rooms');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allRooms = data;
          _filteredRooms = data;
          _isLoading = false;
        });
      } else {
        throw 'Server Error';
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Connection error. Check your server settings.';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRooms = _allRooms.where((room) {
        final name = (room['name'] ?? "").toString().toLowerCase();
        final owner = (room['owner'] ?? "").toString().toLowerCase();
        return name.contains(query) || owner.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
            onPressed: () {
              HapticFeedback.mediumImpact();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MyHomePage()),
                    (route) => false,
              );
            },
          ),
          title: const Text("ROOM EXPLORER",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              child: _buildSearchBar(),
            ),
          ),
        ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.2,
            colors: [primaryPurple.withOpacity(0.05), darkBg],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await _loadData();
          },
          color: accentPurple,
          backgroundColor: surfaceDark,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search by room or owner...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: accentPurple),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white38),
            onPressed: () {
              HapticFeedback.selectionClick();
              _searchController.clear();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentPurple, strokeWidth: 2));
    }

    if (_errorMsg.isNotEmpty) {
      return _buildErrorView(_errorMsg);
    }

    if (_allRooms.isEmpty) {
      return _buildEmptyView("No active rooms found", Icons.cloud_off_rounded);
    }

    if (_filteredRooms.isEmpty) {
      return _buildEmptyView("No matches found", Icons.search_off_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredRooms.length,
      itemBuilder: (context, index) => _buildRoomCard(_filteredRooms[index]),
    );
  }

  Widget _buildRoomCard(dynamic room) {
    final String roomName = room['name'] ?? "Unknown Room";
    final String ownerName = room['owner'] ?? "Anonymous";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            HapticFeedback.lightImpact();
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StartScout(roomName: roomName)),
            );
            _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _buildRoomIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roomName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 12, color: accentPurple.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(ownerName,
                              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w400)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), shape: BoxShape.circle),
                  child: Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white.withOpacity(0.2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryPurple.withOpacity(0.2), primaryPurple.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Icon(Icons.sensors_rounded, color: accentPurple, size: 26),
      ),
    );
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 60, color: Colors.white10),
          const SizedBox(height: 20),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text("Retry Connection", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white10),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.2), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}