import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // Material 3 style Account Menu
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
              // User Info Header
              ListTile(
                leading: ClipOval(
                  child: _photoUrl != null
                      ? Image.network(_photoUrl!, width: 45, height: 45)
                      : const Icon(Icons.account_circle, size: 45),
                ),
                title: Text(
                  _currentUserName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text("Logged in"),
              ),
              const Divider(indent: 20, endIndent: 20),
              // Settings
              ListTile(
                leading: Image.asset('assets/images/settings_icon.png', width: 24, height: 24, errorBuilder: (context, _, __) => const Icon(Icons.settings)),
                title: const Text("Profile Settings", style: TextStyle(fontWeight: FontWeight.w400)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonConfigPage()));
                },
              ),
              // Logout
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w400)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w500)),
        content: const Text("Are you sure you want to log out and clear all login information?"),
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
      backgroundColor: const Color(0xFFF8F9FE), // Soft background
      appBar: AppBar(
        title: const Text('7632SCOUT', style: TextStyle(letterSpacing: 1.5, fontSize: 16)),
        actions: [
          GestureDetector(
            onTap: _showAccountMenu,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[200],
                backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                child: _photoUrl == null ? const Icon(Icons.person, size: 20) : null,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile Avatar
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null ? const Icon(Icons.person, size: 45, color: Colors.deepPurple) : null,
                ),
                const SizedBox(height: 24),
                Text(
                  "Hi, $_currentUserName",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Text(
                  "Welcome back!",
                  style: TextStyle(color: Colors.black45, fontSize: 15, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 60),

                // Main Menu Options
                _buildMenuButton(
                  icon: Icons.add_rounded,
                  label: "Create Room",
                  color: Colors.deepPurple,
                  isFilled: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoomPage())),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.storage_rounded,
                  label: "View Rooms from Server",
                  color: Colors.deepPurple,
                  isFilled: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomListPage())),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  icon: Icons.cloud_download_outlined,
                  label: "Fetch from The Blue Alliance",
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

  // Reusable Menu Button Component
  Widget _buildMenuButton({required IconData icon, required String label, required Color color, required bool isFilled, required VoidCallback onTap}) {
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
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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