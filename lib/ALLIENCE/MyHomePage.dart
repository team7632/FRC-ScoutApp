import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 導入相關頁面
import '../PIT/pitroom.dart';
import '../main.dart';
import '../ALLIENCE/api.dart'; // 確保導入 Api.serverIp
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

  // --- 色彩定義 ---
  final Color scoutPurple = const Color(0xFF673AB7);
  final Color scoutPurpleLight = const Color(0xFFEDE7F6);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  // --- 導航處理：獲取房間列表並進入 Pit Mode ---
  Future<void> _handleModeChange(String mode) async {
    if (mode == "Pit Mode") {
      // 顯示加載動畫，因為抓取房間清單需要時間
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // 從伺服器獲取所有房間名稱
        final response = await http.get(Uri.parse('${Api.serverIp}/v1/rooms')).timeout(const Duration(seconds: 5));

        if (mounted) Navigator.pop(context); // 關閉加載動畫

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          // 提取房間名稱
          List<String> roomNames = data.map((r) => r['name'].toString()).toList();

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PitRoom(
                  availableRooms: roomNames,
                  initialRoom: roomNames.isNotEmpty ? roomNames.first : null,
                ),
              ),
            );
          }
        } else {
          _showErrorSnackBar("Failed to load rooms from server");
        }
      } catch (e) {
        if (mounted) Navigator.pop(context); // 關閉加載動畫
        _showErrorSnackBar("Connection error. Check Server IP.");
      }
    } else {
      setState(() {
        _currentMode = mode;
      });
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  // --- 帳號選單 ---
  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
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
                title: Text(_currentUserName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: const Text("Logged in"),
              ),
              const Divider(indent: 20, endIndent: 20),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: scoutPurple),
                title: const Text("Profile Settings"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonConfigPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _googleSignIn.signOut();
              await prefs.clear();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                      (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PopupMenuButton<String>(
          icon: Icon(Icons.apps_rounded, color: scoutPurple),
          onSelected: _handleModeChange,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: "Scout Mode",
              child: Row(children: [Icon(Icons.assignment_outlined, color: Colors.deepPurple), SizedBox(width: 10), Text("Scout Mode")]),
            ),
            const PopupMenuItem(
              value: "Pit Mode",
              child: Row(children: [Icon(Icons.build_circle_outlined, color: Colors.blue), SizedBox(width: 10), Text("Pit Mode")]),
            ),
          ],
        ),
        title: const Text('7632SCOUT',
            style: TextStyle(letterSpacing: 1.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _showAccountMenu,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: scoutPurple.withOpacity(0.1),
                backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                child: _photoUrl == null ? Icon(Icons.person, size: 20, color: scoutPurple) : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Chip(
                  label: Text(_currentMode),
                  backgroundColor: scoutPurpleLight,
                  side: BorderSide.none,
                  labelStyle: TextStyle(color: scoutPurple, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 45,
                  backgroundColor: scoutPurpleLight,
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null ? Icon(Icons.person, size: 45, color: scoutPurple) : null,
                ),
                const SizedBox(height: 24),
                Text("Hi, $_currentUserName", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const Text("Welcome back!", style: TextStyle(color: Colors.black45, fontSize: 15)),
                const SizedBox(height: 50),

                _buildMenuButton(
                  icon: Icons.add_rounded,
                  label: "Create Room",
                  color: scoutPurple,
                  isFilled: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoomPage())),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.storage_rounded,
                  label: "View Rooms from Server",
                  color: scoutPurple,
                  isFilled: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomListPage())),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.cloud_download_outlined,
                  label: "Fetch from TBA",
                  color: Colors.blueAccent,
                  isFilled: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GetFromTheBlueAlliance())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isFilled,
    required VoidCallback onTap
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isFilled
          ? ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
      )
          : OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}