import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AllConfig2 extends StatefulWidget {
  final String roomName;
  const AllConfig2({super.key, required this.roomName});

  @override
  State<AllConfig2> createState() => _AllConfig2State();
}

class _AllConfig2State extends State<AllConfig2> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  final String serverIp = "192.168.1.128";

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // 獲取所有原始報告
  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://$serverIp:3000/v1/rooms/all-reports?roomName=${widget.roomName}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _reports = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 修改數據的對話框
  void _editReport(int index) {
    final report = _reports[index];
    // 使用 Controller 捕捉輸入內容
    TextEditingController editController = TextEditingController(text: report['ballCount'].toString());

    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text("修改 Team ${report['teamNumber']} 數據"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: editController,
            keyboardType: TextInputType.number,
            placeholder: "輸入新的進球數",
          ),
        ),
        actions: [
          CupertinoDialogAction(child: const Text("取消"), onPressed: () => Navigator.pop(c)),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("儲存修改"),
            onPressed: () async {
              final newCount = editController.text;

              // 1. 先關閉對話框
              Navigator.pop(c);

              try {
                // 2. 發送 POST 請求給 Node.js 伺服器
                final response = await http.post(
                  Uri.parse('http://$serverIp:3000/v1/rooms/update-report'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'roomName': widget.roomName,
                    'index': index,      // 告訴後端要改哪一筆
                    'newBallCount': newCount
                  }),
                );

                if (response.statusCode == 200) {
                  // 3. 伺服器更新成功後，再更新本地 UI
                  setState(() {
                    _reports[index]['ballCount'] = newCount;
                  });
                  debugPrint("✅ 數據更新成功");
                } else {
                  debugPrint("❌ 更新失敗: ${response.body}");
                }
              } catch (e) {
                debugPrint("❌ 網路連線錯誤: $e");
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("所有場次原始紀錄"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _fetchReports,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _reports.length,
          itemBuilder: (context, index) {
            final item = _reports[index];
            return Container(
              // 修正這裡：使用 .only 並指定 bottom
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoListTile(
                title: Text("Match ${item['matchNumber']} - Team ${item['teamNumber']}"),
                subtitle: Text("偵查員: ${item['user']} (${item['position']})"),
                additionalInfo: Text(
                  "${item['ballCount']} ⚽",
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.activeBlue
                  ),
                ),
                trailing: const Icon(CupertinoIcons.pencil_circle, color: CupertinoColors.systemGrey),
                onTap: () => _editReport(index),
              ),
            );
          },
        ),
      ),
    );
  }
}