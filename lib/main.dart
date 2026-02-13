import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 確保路徑對應你的專案結構
import 'package:flutter_application_1/ALLIENCE/MyHomePage.dart';
import 'package:flutter_application_1/ALLIENCE/RoomListPage.dart';
import 'package:flutter_application_1/ALLIENCE/api.dart';
import 'package:flutter_application_1/ALLIENCE/config/pubicconfig.dart';

import 'ALLIENCE/config/personconfig.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedConfig();
  final prefs = await SharedPreferences.getInstance();
  final String? savedUsername = prefs.getString('username');

  // 設定狀態列為透明且文字為亮色（適合深色背景）
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(MyApp(startPage: savedUsername == null ? const RegisterPage() : const MyHomePage()));
}

Future<void> loadSavedConfig() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? savedIp = prefs.getString('custom_ip');
    if (savedIp != null && savedIp.isNotEmpty) {
      Api.serverIp = savedIp;
    }
  } catch (e) {
    debugPrint("Error loading configuration: $e");
  }
}

class MyApp extends StatelessWidget {
  final Widget startPage;
  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF7E57C2);
    const surfaceDark = Color(0xFF111015);

    return MaterialApp(
      title: 'FRC Scouting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: surfaceDark,

        // 全局文字主題
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
        ),

        // 修正後的彈窗主題
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1C1B21),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white70),
        ),

        // 按鈕全局樣式
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      home: startPage, // 確保 home 在 MaterialApp 之下
    );
  }
}

// --- 註冊頁面 ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isLoading = false;
  final Color primaryPurple = const Color(0xFF7E57C2);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color surfaceDark = const Color(0xFF111015);

  @override
  void initState() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.initState();
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final String name = googleUser.displayName ?? "Unknown User";
      final String photoUrl = googleUser.photoUrl ?? "";

      final response = await http.post(
        Uri.parse('${Api.serverIp}/v1/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': name,
          'email': googleUser.email,
          'googleId': googleUser.id,
        }),
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', name);
        await prefs.setString('userPhotoUrl', photoUrl);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage()),
        );
      }
    } catch (error) {
      _showError("Node Sync Failed: Check Server IP in Settings.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Notice", style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: accentPurple)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonConfigPage()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with Glow
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: primaryPurple.withOpacity(0.05),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: primaryPurple.withOpacity(0.1), blurRadius: 40, spreadRadius: 5)
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset(
                      'assets/images/favicon.png',
                      width: 120, height: 120,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.bolt, size: 100, color: accentPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                const Text("FRC7632 Scout", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 80),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: accentPurple))
                        : ElevatedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text("SIGN IN WITH GOOGLE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Text("VERSION 2.0.1", style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.15), letterSpacing: 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}