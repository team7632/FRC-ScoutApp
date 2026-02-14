import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../PIT/pitroom.dart';
import '../main.dart';
import '../ALLIENCE/api.dart';
import 'CreateRoomPage.dart';
import 'RoomListPage.dart';
import 'config/personconfig.dart';
import 'getFromtheBlueAlience.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _currentUserName = "Loading...";
  String? _photoUrl;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String _currentMode = "Scout Mode";


  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    GoogleSignInAccount? currentUser = _googleSignIn.currentUser;
    currentUser ??= await _googleSignIn.signInSilently();

    setState(() {
      _currentUserName = prefs.getString('username') ?? currentUser?.displayName ?? "Scout";
      _photoUrl = currentUser?.photoUrl;
    });
  }

  Future<void> _handleModeChange(String mode) async {
    HapticFeedback.mediumImpact();
    if (mode == "Pit Mode") {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator(color: accentPurple)),
      );

      try {
        final response = await http.get(Uri.parse('${Api.serverIp}/v1/rooms')).timeout(const Duration(seconds: 5));
        if (mounted) Navigator.pop(context);

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          List<String> roomNames = data.map((r) => r['name'].toString()).toList();
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => PitRoom(
              availableRooms: roomNames,
              initialRoom: roomNames.isNotEmpty ? roomNames.first : null,
            )));
          }
        } else {
          _showErrorSnackBar("Server Error");
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _showErrorSnackBar("Connection Failed");
      }
    } else {
      setState(() => _currentMode = mode);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(_currentUserName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Active Account", style: TextStyle(color: Colors.white54)),
              ),
              const Divider(color: Colors.white10, indent: 20, endIndent: 20),
              _buildModalTile(Icons.settings_rounded, "Profile Settings", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonConfigPage()));
              }),
              _buildModalTile(Icons.logout_rounded, "Logout", _handleLogout, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : primaryPurple),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white)),
      onTap: onTap,
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await _googleSignIn.signOut();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const RegisterPage()), (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PopupMenuButton<String>(
          icon: Icon(Icons.grid_view_rounded, color: accentPurple),
          color: surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          onSelected: _handleModeChange,
          itemBuilder: (context) => [
            _buildPopupItem("Scout Mode", Icons.assignment_outlined, primaryPurple),
            _buildPopupItem("Pit Mode", Icons.build_circle_outlined, Colors.blueAccent),
          ],
        ),
        title: Text('7632 SCOUT', style: TextStyle(color: Colors.white.withOpacity(0.9), letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 14)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _showAccountMenu,
              child: Hero(
                tag: 'avatar',
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: surfaceDark,
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null ? Icon(Icons.person, size: 20, color: accentPurple) : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.0,
            colors: [primaryPurple.withOpacity(0.05), darkBg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: primaryPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryPurple.withOpacity(0.3))),
                    child: Text(_currentMode, style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 40),
                  // 使用者資訊
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)])),
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: surfaceDark,
                        backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                        child: _photoUrl == null ? Icon(Icons.person, size: 45, color: accentPurple) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text("Hi, $_currentUserName", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  Text("Welcome back", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                  const SizedBox(height: 50),


                  _buildMenuButton(
                    icon: Icons.add_rounded,
                    label: "Create New Room",
                    color: primaryPurple,
                    isMain: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoomPage())),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuButton(
                    icon: Icons.lan_rounded,
                    label: "Join Server Room",
                    color: Colors.white.withOpacity(0.05),
                    isMain: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomListPage())),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuButton(
                    icon: Icons.auto_awesome_mosaic_rounded,
                    label: "Fetch TBA Schedule",
                    color: Colors.white.withOpacity(0.05),
                    isMain: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GetFromTheBlueAlliance())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 12), Text(value, style: const TextStyle(color: Colors.white))]),
    );
  }

  Widget _buildMenuButton({required IconData icon, required String label, required Color color, required bool isMain, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: isMain ? BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [primaryPurple, deepPurple]),
        boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ) : null,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: isMain ? Colors.white : accentPurple),
        label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isMain ? Colors.white : Colors.white70)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isMain ? Colors.transparent : surfaceDark,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isMain ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}


const Color deepPurple = Color(0xFF4527A0);