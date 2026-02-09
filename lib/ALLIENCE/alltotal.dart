import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api.dart';

class AllTotalPage extends StatefulWidget {
  final String roomName;
  const AllTotalPage({super.key, required this.roomName});

  @override
  State<AllTotalPage> createState() => _AllTotalPageState();
}

class _AllTotalPageState extends State<AllTotalPage> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  final String serverIp = Api.serverIp;

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
      debugPrint("數據抓取失敗: $e");
    }
  }

  // --- 輔助：鑑定等級文字轉換 ---
  String _getRatingText(double avgRating) {
    int r = avgRating.round();
    switch (r) {
      case 5: return '夯';
      case 4: return '人上人';
      case 3: return '普通';
      case 2: return '人機';
      case 1: return '拉完了';
      default: return '無';
    }
  }

  Color _getRatingColor(double avgRating) {
    int r = avgRating.round();
    if (r >= 5) return CupertinoColors.systemRed;
    if (r >= 4) return CupertinoColors.activeOrange;
    if (r >= 2) return CupertinoColors.systemGrey;
    return CupertinoColors.black;
  }

  // --- 核心邏輯：計算各階段得分與彙整備註 ---
  List<Map<String, dynamic>> _processTeamData() {
    Map<String, Map<String, dynamic>> teamStats = {};

    for (var report in _reports) {
      String teamNum = report['teamNumber'].toString();

      int autoBalls = int.tryParse(report['autoBallCount'].toString()) ?? 0;
      int teleopBalls = int.tryParse(report['teleopBallCount'].toString()) ?? 0;
      bool isHanging = report['isAutoHanging'] == true || report['isAutoHanging'] == 1;
      int endgameLevel = int.tryParse(report['endgameLevel'].toString()) ?? 0;

      // 取得鑑定數據
      int rating = int.tryParse(report['rating'].toString()) ?? 0;
      String note = report['notes'] ?? "";

      double autoScore = (autoBalls * 1.0) + (isHanging ? 15.0 : 0.0);
      double teleopScore = (teleopBalls * 1.0) + (endgameLevel * 10.0);
      double matchTotal = autoScore + teleopScore;

      if (!teamStats.containsKey(teamNum)) {
        teamStats[teamNum] = {
          'teamNumber': teamNum,
          'sumAuto': 0.0,
          'sumTeleop': 0.0,
          'sumTotal': 0.0,
          'sumEndgame': 0,
          'matchCount': 0,
          'sumRating': 0,
          'notesList': <String>[],
        };
      }

      teamStats[teamNum]!['sumAuto'] += autoScore;
      teamStats[teamNum]!['sumTeleop'] += teleopScore;
      teamStats[teamNum]!['sumTotal'] += matchTotal;
      teamStats[teamNum]!['sumEndgame'] += endgameLevel;
      teamStats[teamNum]!['matchCount'] += 1;

      if (rating > 0) teamStats[teamNum]!['sumRating'] += rating;
      if (note.isNotEmpty) teamStats[teamNum]!['notesList'].add(note);
    }

    return teamStats.values.map((team) {
      int count = team['matchCount'];
      team['avgAuto'] = team['sumAuto'] / count;
      team['avgTeleop'] = team['sumTeleop'] / count;
      team['avgTotal'] = team['sumTotal'] / count;
      team['avgRating'] = team['sumRating'] / count;
      team['avgEndgame'] = team['sumEndgame'] / count;
      return team;
    }).toList()..sort((a, b) => b['avgTotal'].compareTo(a['avgTotal']));
  }

  // --- CSV 匯出：移除掛鉤率 ---
  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    // 表頭移除 Hang Rate
    String csv = "Team,Matches,Avg Total,Avg Auto,Avg Teleop,Avg Endgame,Rating,評價\n";

    for (var team in data) {
      String combinedNotes = (team['notesList'] as List).join(" | ").replaceAll(",", " ");

      csv += "${team['teamNumber']},"
          "${team['matchCount']},"
          "${team['avgTotal'].toStringAsFixed(2)},"
          "${team['avgAuto'].toStringAsFixed(2)},"
          "${team['avgTeleop'].toStringAsFixed(2)},"
          "${team['avgEndgame'].toStringAsFixed(2)},"
          "${_getRatingText(team['avgRating'])},"
          "\"$combinedNotes\"\n";
    }

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Analysis_${widget.roomName}.csv');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      await Share.shareXFiles([XFile(file.path)], text: 'FRC Scouting Data Export');
    } catch (e) {
      debugPrint("CSV 匯出失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _processTeamData();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text("${widget.roomName} 排行榜"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.share), onPressed: () => _exportExcel(groupedData)),
            CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.refresh), onPressed: _fetchTotalData),
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
            final avgR = team['avgRating'] as double;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Team ${team['teamNumber']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRatingColor(avgR),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _getRatingText(avgR),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${team['avgTotal'].toStringAsFixed(1)} pt",
                              style: const TextStyle(fontSize: 24, color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold)),
                          const Text("平均總分", style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn("AUTO 分", team['avgAuto'], CupertinoColors.systemYellow),
                      _buildStatColumn("TELEOP 分", team['avgTeleop'], CupertinoColors.systemBlue),
                      _buildStatColumn("總場次", team['matchCount'].toDouble(), CupertinoColors.systemGrey, isInt: true),
                    ],
                  ),
                  if ((team['notesList'] as List).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "最新筆記: ${team['notesList'].last}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey, fontStyle: FontStyle.italic),
                      ),
                    )
                  ]
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color, {bool isInt = false}) {
    return Column(
      children: [
        Text(
          isInt ? value.toInt().toString() : value.toStringAsFixed(1),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}