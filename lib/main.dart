import 'package:flutter/cupertino.dart';
import 'package:flutter_application_1/ALLIENCE/MyHomePage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/ALLIENCE/RoomListPage.dart';

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
      // 設定啟動頁面
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
  final TextEditingController _usernameController = TextEditingController();

  final String serverIp = "192.168.1.128";
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final String name = _usernameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://$serverIp:3000/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': name}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // 1. 儲存用戶名
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', name);

        if (!mounted) return;

        // 2. 註冊成功，直接跳轉到房間列表
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const RoomListPage()),
        );
      } else {
        _showError("註冊失敗，伺服器回傳錯誤");
      }
    } catch (e) {
      _showError("連線錯誤：請檢查伺服器是否開啟 (錯誤碼: $e)");
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
      navigationBar: const CupertinoNavigationBar(middle: Text("系統註冊")),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.person_crop_circle_fill_badge_plus, size: 100, color: CupertinoColors.activeBlue),
                const SizedBox(height: 40),
                const Text("偵查系統註冊", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                CupertinoTextField(
                  controller: _usernameController,
                  placeholder: "輸入您的名稱",
                  style: const TextStyle(color: CupertinoColors.black),
                  placeholderStyle: const TextStyle(color: CupertinoColors.placeholderText),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const CupertinoActivityIndicator()
                      : CupertinoButton.filled(
                    onPressed: _handleRegister,
                    child: const Text("註冊並開始使用"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}