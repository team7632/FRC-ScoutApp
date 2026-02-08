import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'MyHomePage.dart';

class People extends StatefulWidget {
  const People({super.key});

  @override
  State<People> createState() => _PeopleState();
}

class _PeopleState extends State<People> {
  final TextEditingController _usernameController = TextEditingController();
  bool _loading = false;

  Future<void> _handleRegister() async {
    final name = _usernameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);

    try {
      // 1. 同步到伺服器
      final response = await http.post(
        Uri.parse('http://192.168.1.128:3000'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': name}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 2. 伺服器成功接收，寫入本地記憶
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', name);

        if (mounted) {
          // 3. 註冊成功，切換到主頁面
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(builder: (context) => const MyHomePage()),
          );
        }
      } else {
        throw Exception("伺服器拒絕註冊");
      }
    } catch (e) {

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: const Text("連線失敗"),
            content: const Text("請確保已連上開發伺服器 WiFi"),
            actions: [
              CupertinoDialogAction(
                child: const Text("確定"),
                onPressed: () => Navigator.pop(c),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text("初次使用註冊")),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("輸入您的 Scout ID", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              CupertinoTextField(
                controller: _usernameController,
                placeholder: "EX.ass",
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 30),
              _loading
                  ? const CupertinoActivityIndicator()
                  : SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _handleRegister,
                  child: const Text("註冊並開始"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}