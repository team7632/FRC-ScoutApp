import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:flutter_application_1/ALLIENCE/MyHomePage.dart';
import 'package:flutter_application_1/ALLIENCE/RoomListPage.dart';

import 'ALLIENCE/api.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final String? savedUsername = prefs.getString('username');

  runApp(MyApp(startPage: savedUsername == null ? const RegisterPage() : const MyHomePage()));
}

class MyApp extends StatelessWidget {
  final Widget startPage;
  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Scouting App',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
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

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final String name = googleUser.displayName ?? "Unknown User";
      final String email = googleUser.email;
      final String id = googleUser.id;

      final response = await http.post(
        Uri.parse('$serverIp/v1/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': name,
          'email': email,
          'googleId': id,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', name);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MyHomePage()),
        );
      } else {
        _showError("註冊失敗：伺服器拒絕請求");
      }
    } catch (error) {
      print("Google Sign In Error: $error");
      _showError("Google 登入錯誤：$error");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("連線提示"),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("確定"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // 導航欄也換成更簡潔的標題
      navigationBar: const CupertinoNavigationBar(middle: Text("登入")),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- 替換後的圖片部分 ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(20), // 讓圖片圓角化
                  child: Image.asset(
                    'assets/images/favicon.png', // 請確保路徑正確
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // 如果圖片載入失敗，顯示一個備用圖標
                      return const Icon(CupertinoIcons.person_crop_circle_fill, size: 100);
                    },
                  ),
                ),
                // ---------------------

                const SizedBox(height: 30),
                const Text(
                  "FRC7632 Scout",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Please log in first.",
                  style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey),
                ),
                const SizedBox(height: 50),

                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const CupertinoActivityIndicator()
                      : CupertinoButton(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(15),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onPressed: _handleGoogleSignIn,
                    // 按鈕增加邊框感
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: CupertinoColors.systemGrey5, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.mail, color: CupertinoColors.black),
                          const SizedBox(width: 12),
                          const Text(
                            "使用 Google 帳戶登入",
                            style: TextStyle(
                              color: CupertinoColors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "YEE",
                  style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey2),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}