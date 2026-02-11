import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart'; // 確保路徑正確

class PersonConfigPage extends StatefulWidget {
  const PersonConfigPage({super.key});

  @override
  State<PersonConfigPage> createState() => _PersonConfigPageState();
}

class _PersonConfigPageState extends State<PersonConfigPage> {
  final TextEditingController _ipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 使用與 MyHomePage 一致的紫色調
  final Color primaryPurple = const Color(0xFF673AB7);

  @override
  void initState() {
    super.initState();
    _ipController.text = Api.serverIp;
  }

  Future<void> _saveIp(String newIp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_ip', newIp);
    Api.serverIp = newIp;

    if (!mounted) return;

    // 使用 Material 的 SnackBar 代替彈窗，操作更流暢不中斷
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Server IP updated to: $newIp"),
        backgroundColor: primaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // 延用主頁的清爽背景
      appBar: AppBar(
        title: const Text("Profile Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "NETWORK CONFIGURATION",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // 使用 Card 包裹設定項，符合 M3 區塊化視覺
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Server IP 輸入框
                      TextField(
                        controller: _ipController,
                        decoration: InputDecoration(
                          labelText: "Server IP / URL",
                          hintText: "e.g. 192.168.1.100",
                          prefixIcon: Icon(Icons.lan_outlined, color: primaryPurple),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFBFBFF),
                        ),
                        onSubmitted: (value) => _saveIp(value),
                      ),
                      const SizedBox(height: 12),

                      // 還原預設按鈕
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.restart_alt_rounded, color: Colors.grey),
                        ),
                        title: const Text("Reset to Default", style: TextStyle(fontSize: 14)),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          setState(() {
                            _ipController.text = Api.defaultIp;
                          });
                          _saveIp(Api.defaultIp);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "Changes take effect immediately. Please ensure your device is on the same network as the server.",
                  style: TextStyle(fontSize: 12, color: Colors.black38, height: 1.4),
                ),
              ),

              const SizedBox(height: 40),

              // 儲存按鈕 - 使用 ElevatedButton
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _saveIp(_ipController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}