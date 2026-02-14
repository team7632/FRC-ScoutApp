import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

class PersonConfigPage extends StatefulWidget {
  const PersonConfigPage({super.key});

  @override
  State<PersonConfigPage> createState() => _PersonConfigPageState();
}

class _PersonConfigPageState extends State<PersonConfigPage> {
  final TextEditingController _ipController = TextEditingController();


  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color primaryPurple = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _ipController.text = Api.serverIp;
  }

  Future<void> _saveIp(String newIp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_ip', newIp);
    Api.serverIp = newIp;

    HapticFeedback.mediumImpact();

    if (!mounted) return;


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "CORE SYNC: IP updated to $newIp",
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        backgroundColor: primaryPurple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "SYSTEM CONFIG",
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [primaryPurple.withOpacity(0.05), darkBg],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("NETWORK PROTOCOL"),
                const SizedBox(height: 16),

                // 核心配置卡片
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Server IP 輸入框
                      TextField(
                        controller: _ipController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: "Server Node IP / URL",
                          labelStyle: TextStyle(color: accentPurple.withOpacity(0.5), fontSize: 12),
                          hintText: "e.g. 192.168.1.100",
                          hintStyle: const TextStyle(color: Colors.white10),
                          prefixIcon: Icon(Icons.lan_outlined, color: accentPurple),
                          filled: true,
                          fillColor: Colors.black26,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: accentPurple, width: 2),
                          ),
                        ),
                        onSubmitted: (value) => _saveIp(value),
                      ),
                      const SizedBox(height: 16),


                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() => _ipController.text = Api.defaultIp);
                            _saveIp(Api.defaultIp);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.restart_alt_rounded, color: Colors.white38, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Factory Reset IP", style: TextStyle(color: Colors.white38, fontSize: 13)),
                                const Spacer(),
                                const Icon(Icons.chevron_right, color: Colors.white10, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "Note: Ensure the target node is accessible via local mesh or cloud relay before synchronizing.",
                    style: TextStyle(fontSize: 11, color: Colors.white24, height: 1.5),
                  ),
                ),

                const SizedBox(height: 48),


                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: primaryPurple.withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _saveIp(_ipController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      "SYNC CONFIGURATION",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: accentPurple.withOpacity(0.5),
        letterSpacing: 2,
      ),
    );
  }
}