import 'package:flutter/material.dart'; // 優先使用 Material
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
  String _currentUserName = "載入中...";
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

  // 修改選單：使用 Material 的 ModalBottomSheet 會比 Cupertino 彈窗更契合 M3 風格
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
            mainAxisSize: MainAxisSize.min, // 根據內容高度伸縮
            children: [
              // 使用者資訊
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
                subtitle: const Text("已登入帳戶"),
              ),
              const Divider(indent: 20, endIndent: 20),
              // 個人設置
              ListTile(
                leading: Image.asset('assets/images/settings_icon.png', width: 24, height: 24),
                title: const Text("個人設置", style: TextStyle(fontWeight: FontWeight.w400)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonConfigPage()));
                },
              ),
              // 登出
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("登出帳戶", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w400)),
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
        title: const Text("登出", style: TextStyle(fontWeight: FontWeight.w500)),
        content: const Text("確定要登出並清除所有登入資訊嗎？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
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
            child: const Text("確定", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // 清爽的淡背景色
      appBar: AppBar(
        title: const Text('7632SCOUT', style: TextStyle(letterSpacing: 1.5, fontSize: 16)),
        actions: [
          GestureDetector(
            onTap: _showAccountMenu,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
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
                // 大頭像
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
                  "歡迎回來！",
                  style: TextStyle(color: Colors.black45, fontSize: 15, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 60),

                // 功能按鈕區 - 統一使用 ElevatedButton 並移除粗體
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
                  label: "View from The Blue Alliance",
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

  // 封裝一個清爽的按鈕組件
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