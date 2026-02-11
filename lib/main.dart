import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 請確保路徑與你的專案結構一致
import 'package:flutter_application_1/ALLIENCE/MyHomePage.dart';
import 'package:flutter_application_1/ALLIENCE/RoomListPage.dart';
import 'ALLIENCE/api.dart';
import 'ALLIENCE/config/pubicconfig.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedConfig();
  final prefs = await SharedPreferences.getInstance();
  final String? savedUsername = prefs.getString('username');

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
    print("讀取設定時出錯: $e");
  }
}

class MyApp extends StatelessWidget {
  final Widget startPage;
  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scouting App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // 使用紫色作為種子色，系統會自動生成輕盈的色調
        colorSchemeSeed: const Color(0xFF673AB7),
        brightness: Brightness.light,

        // 全域卡片樣式優化
        cardTheme: CardThemeData(
          elevation: 0, // 移除沉重陰影
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
        ),

        // 全域按鈕樣式優化（不加粗）
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),

        // 全域 AppBar 樣式
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w400, // 移除粗體
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: startPage,
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final String serverIp = Api.serverIp;
  bool _isLoading = false;

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
        Uri.parse('$serverIp/v1/auth/google-login'),
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
      _showError("登入過程發生錯誤");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("提示", style: TextStyle(fontWeight: FontWeight.w400)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("確定"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo 區域
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.03),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset(
                      'assets/images/favicon.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.blur_on, size: 100, color: Colors.deepPurple);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // 標題區域 - 使用中度字重而非粗體
                const Text(
                  "FRC7632 Scout",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "請先完成 Google 驗證以開始使用",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 72),

                // 登入按鈕 - 圓潤簡約風格
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton.icon(
                    onPressed: _handleGoogleSignIn,
                    icon: const Icon(Icons.mail_outline, size: 20),
                    label: const Text("使用 Google 帳戶登入"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300, width: 0.8),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // 底部版本號
                const Text(
                  "Version 2.0.0",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w200,
                    color: Colors.grey,
                    letterSpacing: 2,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}