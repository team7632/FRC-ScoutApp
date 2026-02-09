import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'api.dart';

class AllConfig2 extends StatefulWidget {
  final String roomName;
  const AllConfig2({super.key, required this.roomName});

  @override
  State<AllConfig2> createState() => _AllConfig2State();
}

class _AllConfig2State extends State<AllConfig2> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  final String serverIp = Api.serverIp;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$serverIp/v1/rooms/all-reports?roomName=${widget.roomName}'),
      ).timeout(const Duration(seconds: 5));
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

  // 修改數據的對話框：支援 Auto, Teleop, 吊掛, 與 Endgame Level
  void _editReport(int index) {
    final report = _reports[index];

    TextEditingController autoController = TextEditingController(text: report['autoBallCount'].toString());
    TextEditingController teleController = TextEditingController(text: report['teleopBallCount'].toString());
    bool tempIsHanging = report['isAutoHanging'] == true || report['isAutoHanging'] == 1;
    int tempEndgame = int.tryParse(report['endgameLevel'].toString()) ?? 0;

    showCupertinoDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text("修正 Match ${report['matchNumber']} - Team ${report['teamNumber']}"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 15),
                _buildEditField("AUTO 進球", autoController),
                const SizedBox(height: 10),
                _buildEditField("TELEOP 進球", teleController),
                const SizedBox(height: 15),
                // 吊掛切換
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("AUTO 吊掛 (15pt)", style: TextStyle(fontSize: 14)),
                    CupertinoSwitch(
                      value: tempIsHanging,
                      onChanged: (val) => setDialogState(() => tempIsHanging = val),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // Endgame 等級選擇
                const Text("ENDGAME LEVEL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey)),
                const SizedBox(height: 10),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: tempEndgame,
                  children: const {
                    0: Text("無", style: TextStyle(fontSize: 12)),
                    1: Text("L1", style: TextStyle(fontSize: 12)),
                    2: Text("L2", style: TextStyle(fontSize: 12)),
                    3: Text("L3", style: TextStyle(fontSize: 12)),
                  },
                  onValueChanged: (val) => setDialogState(() => tempEndgame = val ?? 0),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(child: const Text("取消"), onPressed: () => Navigator.pop(c)),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text("確認更新"),
              onPressed: () async {
                final newAuto = int.tryParse(autoController.text) ?? 0;
                final newTele = int.tryParse(teleController.text) ?? 0;

                Navigator.pop(c);

                try {
                  final response = await http.post(
                    Uri.parse('http://$serverIp:3000/v1/rooms/update-report'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'roomName': widget.roomName,
                      'index': index,
                      'newAutoCount': newAuto,
                      'newTeleopCount': newTele,
                      'newIsHanging': tempIsHanging,
                      'newEndgameLevel': tempEndgame // 同步發送 Endgame
                    }),
                  );

                  if (response.statusCode == 200) {
                    setState(() => _fetchReports()); // 重新抓取最準確
                  }
                } catch (e) {
                  debugPrint("❌ 更新失敗: $e");
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(width: 85, child: Text(label, style: const TextStyle(fontSize: 14))),
        Expanded(
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Config panel"),
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
            bool isHanging = item['isAutoHanging'] == true || item['isAutoHanging'] == 1;
            int egLevel = int.tryParse(item['endgameLevel'].toString()) ?? 0;

            // 計算顯示總分
            int total = (int.tryParse(item['autoBallCount'].toString()) ?? 0) +
                (isHanging ? 15 : 0) +
                (int.tryParse(item['teleopBallCount'].toString()) ?? 0) +
                (egLevel * 10);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
              ),
              child: CupertinoListTile(
                padding: const EdgeInsets.all(12),
                title: Text("Match ${item['matchNumber']} - Team ${item['teamNumber']}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("偵查員: ${item['user']} (${item['position']})"),
                    const SizedBox(height: 6),
                    Wrap( // 使用 Wrap 防止標籤過多時溢出
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _tag("Auto: ${item['autoBallCount']}", CupertinoColors.systemYellow),
                        _tag("Tele: ${item['teleopBallCount']}", CupertinoColors.systemBlue),
                        if (isHanging) _tag("Auto 吊掛", CupertinoColors.systemGreen),
                        if (egLevel > 0) _tag("Endgame L$egLevel", CupertinoColors.systemPurple),
                      ],
                    )
                  ],
                ),
                additionalInfo: Text("$total pt",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoColors.activeBlue),
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

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}