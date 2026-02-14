import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class CreateRoomPage extends StatefulWidget {
  final String? initialRoomName;

  final Map<String, List<String>>? allMatchesData;

  const CreateRoomPage({super.key, this.initialRoomName, this.allMatchesData});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {

  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color primaryPurple = const Color(0xFF7E57C2);

  late TextEditingController _roomNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController(text: widget.initialRoomName);
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final String name = _roomNameController.text.trim();
    if (name.isEmpty) {
      _showError("Room name cannot be empty");
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? currentUserName = prefs.getString('username');


      final Map<String, dynamic> requestBody = {
        'name': name,
        'owner': currentUserName ?? "Admin",
        'allMatches': widget.allMatchesData,
      };

      final response = await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {

          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Room '$name' initialized with ${widget.allMatchesData?.length ?? 0} matches.")),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showError(errorData['error'] ?? "Creation failed");
      }
    } catch (e) {
      _showError("Network error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.5))
        ),
        title: const Text("INITIALIZATION ERROR",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
        content: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            child: const Text("GOT IT", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int matchCount = widget.allMatchesData?.length ?? 0;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("CREATE DATA HUB",
            style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 12)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [primaryPurple.withOpacity(0.06), darkBg],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            children: [

              _buildTbaInfoCard(matchCount),

              const SizedBox(height: 40),

              const Text(
                "ROOM IDENTIFIER",
                style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _roomNameController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                cursorColor: accentPurple,
                decoration: InputDecoration(
                  hintText: "e.g., 2026_Championships",
                  hintStyle: const TextStyle(color: Colors.white10, fontSize: 16),
                  prefixIcon: Icon(Icons.sensors, color: accentPurple, size: 20),
                  filled: true,
                  fillColor: surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: accentPurple, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 60),

              _isLoading
                  ? Center(child: CircularProgressIndicator(color: accentPurple))
                  : _buildSubmitButton(),

              const SizedBox(height: 32),

              const Opacity(
                opacity: 0.3,
                child: Column(
                  children: [
                    Icon(Icons.security, color: Colors.white, size: 16),
                    SizedBox(height: 8),
                    Text(
                      "Data will be synchronized across all authorized scouter nodes.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.white, height: 1.5),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTbaInfoCard(int count) {
    bool hasData = count > 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: hasData ? accentPurple.withOpacity(0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  hasData ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                  color: hasData ? Colors.greenAccent : Colors.orangeAccent,
                  size: 20
              ),
              const SizedBox(width: 12),
              Text(
                hasData ? "TBA PAYLOAD READY" : "NO TBA DATA",
                style: TextStyle(
                    color: hasData ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasData
                ? "We found $count qualification matches from your selection. Creating this room will pre-populate all team assignments for the entire event."
                : "No match schedule was provided. You will need to enter team numbers manually for each match in the Admin Dashboard.",
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _createRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("LAUNCH DATA HUB",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
            SizedBox(width: 12),
            Icon(Icons.rocket_launch_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}