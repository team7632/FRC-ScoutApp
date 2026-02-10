import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      print("成功載入自定義 IP: ${Api.serverIp}");
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
    return CupertinoApp(
      title: 'Scouting App',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemPurple,
        brightness: Brightness.light,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        textTheme: const CupertinoTextThemeData(
          navActionTextStyle: TextStyle(color: CupertinoColors.systemPurple),
          navTitleTextStyle: TextStyle(color: CupertinoColors.label, fontWeight: FontWeight.w600),
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
      final String photoUrl = googleUser.photoUrl ?? ""; // 👈 抓取 Google 頭像網址

      // 呼叫你的後端 API
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

        // 核心修正：這裡一定要存入頭像網址！
        await prefs.setString('username', name);
        await prefs.setString('userPhotoUrl', photoUrl); // 👈 加入這行

        print("【Debug 註冊頁】已成功儲存頭像: $photoUrl");

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MyHomePage()),
        );
      }
    } catch (error) {
      print("Google Sign In Error: $error");
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
            child: const Text("確定", style: TextStyle(color: CupertinoColors.systemPurple)),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("登入")),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/favicon.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(CupertinoIcons.person_crop_circle_fill, size: 100, color: CupertinoColors.systemPurple);
                    },
                  ),
                ),
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