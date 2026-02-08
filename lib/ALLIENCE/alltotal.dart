import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AllTotalPage extends StatefulWidget {
  final String roomName;
  const AllTotalPage({super.key, required this.roomName});

  @override
  State<AllTotalPage> createState() => _AllTotalPageState();
}

class _AllTotalPageState extends State<AllTotalPage> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  final String serverIp = "192.168.1.128";

  @override
  void initState() {
    super.initState();
    _fetchTotalData();
  }

  Future<void> _fetchTotalData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://$serverIp:3000/v1/rooms/all-reports?roomName=${widget.roomName}'),
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

  // 整理數據邏輯
  List<Map<String, dynamic>> _processTeamData() {
    Map<String, Map<String, dynamic>> teamStats = {};
    for (var report in _reports) {
      String teamNum = report['teamNumber'].toString();
      int balls = int.tryParse(report['ballCount'].toString()) ?? 0;
      if (!teamStats.containsKey(teamNum)) {
        teamStats[teamNum] = {'teamNumber': teamNum, 'totalBalls': 0, 'matchCount': 0};
      }
      teamStats[teamNum]!['totalBalls'] += balls;
      teamStats[teamNum]!['matchCount'] += 1;
    }
    return teamStats.values.map((team) {
      team['avgBalls'] = team['totalBalls'] / team['matchCount'];
      return team;
    }).toList()..sort((a, b) => b['avgBalls'].compareTo(a['avgBalls']));
  }

  // --- 核心匯出功能 ---
  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    // 製作 CSV 內容 (Excel 可讀格式)
    String csv = "Team Number,Matches,Total Balls,Average\n";
    for (var team in data) {
      csv += "${team['teamNumber']},${team['matchCount']},${team['totalBalls']},${team['avgBalls'].toStringAsFixed(2)}\n";
    }

    try {
      // 取得手機暫存路徑
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Scouting_Report.csv');

      // 寫入 UTF-8 BOM 以防亂碼
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);

      // 呼叫系統分享介面
      await Share.shareXFiles([XFile(file.path)], text: 'FRC Scouting Data - ${widget.roomName}');
    } catch (e) {
      debugPrint("匯出出錯: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _processTeamData();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("戰力分析"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _exportExcel(groupedData),
              child: const Icon(CupertinoIcons.share), // 匯出按鈕
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _fetchTotalData,
              child: const Icon(CupertinoIcons.refresh),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedData.length,
          itemBuilder: (context, index) {
            final team = groupedData[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Team ${team['teamNumber']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(team['avgBalls'].toStringAsFixed(1), style: const TextStyle(fontSize: 22, color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold)),
                      const Text("AVG Balls", style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey)),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}