import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // 為了 DataTable 與 Colors
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'alltotal.dart'; // 確保你已經建立了這個檔案

class AdminConfig extends StatefulWidget {
  final String roomName;
  const AdminConfig({super.key, required this.roomName});

  @override
  State<AdminConfig> createState() => _AdminConfigState();
}

class _AdminConfigState extends State<AdminConfig> {
  // 1. 人員控制項 (誰在哪個位置)
  final Map<String, TextEditingController> _userControllers = {
    'Red 1': TextEditingController(),
    'Red 2': TextEditingController(),
    'Red 3': TextEditingController(),
    'Blue 1': TextEditingController(),
    'Blue 2': TextEditingController(),
    'Blue 3': TextEditingController(),
  };

  // 2. 隊伍控制項 (這位置這場比賽是哪隊)
  final Map<String, TextEditingController> _teamControllers = {
    'Red 1': TextEditingController(),
    'Red 2': TextEditingController(),
    'Red 3': TextEditingController(),
    'Blue 1': TextEditingController(),
    'Blue 2': TextEditingController(),
    'Blue 3': TextEditingController(),
  };

  // 3. 場次控制
  final TextEditingController _matchController = TextEditingController(text: "1");

  final String serverIp = "192.168.1.128";
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentConfig();
  }

  // 從伺服器抓取目前配置 (獲取已有的分配與隊伍)
  Future<void> _fetchCurrentConfig() async {
    try {
      final response = await http.get(
        Uri.parse('http://$serverIp:3000/v1/rooms/check-my-pos?roomName=${widget.roomName}&user=admin_view'),
      );

      if (response.statusCode == 200) {
        // 這裡你可以擴充伺服器回傳完整的 assignments 列表
        // 目前我們先維持載入狀態
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("載入配置失敗: $e");
      setState(() => _isLoading = false);
    }
  }

  // 發布配置到伺服器
  Future<void> _saveAssignment() async {
    setState(() => _isSaving = true);

    Map<String, String> userMap = {};
    Map<String, String> teamMap = {};

    _userControllers.forEach((k, v) => userMap[k] = v.text.trim());
    _teamControllers.forEach((k, v) => teamMap[k] = v.text.trim());

    try {
      final response = await http.post(
        Uri.parse('http://$serverIp:3000/v1/rooms/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'matchNumber': _matchController.text,
          'assignments': userMap,
          'teams': teamMap,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (c) => CupertinoAlertDialog(
              title: const Text("成功"),
              content: const Text("配置已發布給所有成員"),
              actions: [
                CupertinoDialogAction(child: const Text("確定"), onPressed: () => Navigator.pop(c))
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("儲存失敗: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text("${widget.roomName} 管理員模式"),
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saveAssignment,
          child: const Text("發布配置", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
          children: [
            // --- 第一部分：數據分析入口 ---
        CupertinoListTile(
        title: const Text("查看總體數據統計", style: TextStyle(color: CupertinoColors.activeBlue)),
        leading: const Icon(CupertinoIcons.chart_bar_square, color: CupertinoColors.activeBlue),
        trailing: const CupertinoListTileChevron(),
        onTap: () { // <-- 修改為 onTap
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (c) => AllTotalPage(roomName: widget.roomName)),
          );
        },
      ),

            // --- 第二部分：比賽基本資訊 ---
            CupertinoListSection.insetGrouped(
              header: const Text("賽事設定"),
              children: [
                CupertinoListTile(
                  title: const Text("目前場次 (Match #)"),
                  additionalInfo: SizedBox(
                    width: 100,
                    child: CupertinoTextField(
                      controller: _matchController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      placeholder: "1",
                      decoration: null,
                    ),
                  ),
                ),
              ],
            ),

            // --- 第三部分：人員與隊伍分配 ---
            _buildAllianceSection("(Red Alliance)", ["Red 1", "Red 2", "Red 3"], CupertinoColors.systemRed),
            _buildAllianceSection("(Blue Alliance)", ["Blue 1", "Blue 2", "Blue 3"], CupertinoColors.systemBlue),

            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "* 當你點擊「發布配置」時，隊員的手機會即時更新他們負責的隊伍號碼與場次。",
                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 建構聯軍區塊的輔助函式
  Widget _buildAllianceSection(String title, List<String> positions, Color color) {
    return CupertinoListSection.insetGrouped(
      header: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      children: positions.map((pos) {
        return CupertinoListTile(
          title: Text(pos, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: SizedBox(
            height: 35,
            child: CupertinoTextField(
              controller: _userControllers[pos],
              placeholder: "派發人員名稱",
              placeholderStyle: const TextStyle(fontSize: 12, color: CupertinoColors.placeholderText),
              style: const TextStyle(fontSize: 14),
              decoration: null,
            ),
          ),
          additionalInfo: SizedBox(
            width: 100,
            child: CupertinoTextField(
              controller: _teamControllers[pos],
              placeholder: "隊號",
              placeholderStyle: const TextStyle(fontSize: 12, color: CupertinoColors.placeholderText),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              decoration: null,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _matchController.dispose();
    _userControllers.forEach((_, v) => v.dispose());
    _teamControllers.forEach((_, v) => v.dispose());
    super.dispose();
  }
}