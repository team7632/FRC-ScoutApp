import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/ALLIENCE/startscout.dart'; // Ensure this path is correct
import 'api.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  final Color _brandPurple = const Color(0xFF673AB7);

  // Data Storage
  List<dynamic> _allRooms = [];      // Original data from server
  List<dynamic> _filteredRooms = []; // Data after search filter
  bool _isLoading = true;
  String _errorMsg = "";

  // Search Controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();

    // Listen for search input changes
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Logic Handling ---

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
        throw 'Server Error (${response.statusCode})';
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Could not connect to server. Please check your network settings.';
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

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("FRC Room List",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildSearchBar(),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: _brandPurple,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search room name or owner...",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () => _searchController.clear(),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    if (_errorMsg.isNotEmpty) {
      return _buildErrorView(_errorMsg);
    }

    if (_allRooms.isEmpty) {
      return _buildEmptyView("No rooms available yet", Icons.inbox_outlined);
    }

    if (_filteredRooms.isEmpty) {
      return _buildEmptyView("No matching rooms found", Icons.search_off_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _filteredRooms.length,
      itemBuilder: (context, index) => _buildRoomCard(_filteredRooms[index]),
    );
  }

  Widget _buildRoomCard(dynamic room) {
    final String roomName = room['name'] ?? "Unknown Room";
    final String ownerName = room['owner'] ?? "Anonymous";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Auto-refresh on return to prevent entering deleted rooms
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StartScout(roomName: roomName)),
            );
            _loadData();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                _buildRoomIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roomName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text("Owner: $ownerName",
                          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w300)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _brandPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Image.asset(
          'assets/images/icon.png',
          width: 24,
          height: 24,
          errorBuilder: (context, _, __) => Icon(Icons.meeting_room_outlined, color: _brandPurple),
        ),
      ),
    );
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
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
          Icon(icon, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w300)),
        ],
      ),
    );
  }
}