import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // 僅保留用於顏色和基本的色彩常量
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
  final Color _brandPurple = Colors.purple;

  @override
  void initState() {
    super.initState();
    _fetchTotalData();
  }

  Future<void> _fetchTotalData() async {
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

  List<Map<String, dynamic>> _processTeamData() {
    Map<String, Map<String, dynamic>> teamStats = {};
    for (var report in _reports) {
      String teamNum = report['teamNumber'].toString();
      int autoBalls = int.tryParse(report['autoBallCount'].toString()) ?? 0;
      int teleopBalls = int.tryParse(report['teleopBallCount'].toString()) ?? 0;
      bool isHanging = report['isAutoHanging'] == true || report['isAutoHanging'] == 1;
      bool isLeave = report['isLeave'] == true || report['isLeave'] == 1;
      int endgameLevel = int.tryParse(report['endgameLevel'].toString()) ?? 0;

      double autoScore = (autoBalls * 4.0) + (isHanging ? 15.0 : 0.0) + (isLeave ? 3.0 : 0.0);
      double teleopScore = (teleopBalls * 2.0) + (endgameLevel * 10.0);

      if (!teamStats.containsKey(teamNum)) {
        teamStats[teamNum] = {
          'teamNumber': teamNum,
          'sumTotal': 0.0,
          'sumAutoBalls': 0,
          'sumTeleopBalls': 0,
          'hasLeaveEver': false,
          'hasAutoHangEver': false,
          'maxEndgameLevel': 0,
          'matchCount': 0,
        };
      }
      teamStats[teamNum]!['sumTotal'] += (autoScore + teleopScore);
      teamStats[teamNum]!['sumAutoBalls'] += autoBalls;
      teamStats[teamNum]!['sumTeleopBalls'] += teleopBalls;
      teamStats[teamNum]!['matchCount'] += 1;
      if (isLeave) teamStats[teamNum]!['hasLeaveEver'] = true;
      if (isHanging) teamStats[teamNum]!['hasAutoHangEver'] = true;
      if (endgameLevel > teamStats[teamNum]!['maxEndgameLevel']) {
        teamStats[teamNum]!['maxEndgameLevel'] = endgameLevel;
      }
    }
    return teamStats.values.map((team) {
      team['avgTotal'] = team['sumTotal'] / team['matchCount'];
      return team;
    }).toList()..sort((a, b) => b['avgTotal'].compareTo(a['avgTotal']));
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    String csv = "Team,Matches,Avg Total,Total Auto Balls,Total Teleop Balls,Has Leave,Auto Hang,Max Endgame Level\n";
    for (var team in data) {
      csv += "${team['teamNumber']},"
          "${team['matchCount']},"
          "${team['avgTotal'].toStringAsFixed(2)},"
          "${team['sumAutoBalls']},"
          "${team['sumTeleopBalls']},"
          "${team['hasLeaveEver'] ? "YES" : "NO"},"
          "${team['hasAutoHangEver'] ? "YES" : "NO"},"
          "L${team['maxEndgameLevel']}\n";
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Analysis_${widget.roomName}.csv');
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    await Share.shareXFiles([XFile(file.path)], text: '數據分析導出');
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _processTeamData();
    // 👈 改用 CupertinoPageScaffold
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        middle: Text("${widget.roomName} 排行榜", style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.share, size: 22),
          onPressed: () => _exportExcel(groupedData),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: groupedData.length,
          itemBuilder: (context, index) {
            final team = groupedData[index];
            return _buildTeamCard(team);
          },
        ),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(team['teamNumber'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${team['avgTotal'].toStringAsFixed(1)}",
                      style: TextStyle(fontSize: 32, color: _brandPurple, fontWeight: FontWeight.w900, height: 1)),
                  const Text("AVG POINTS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1, color: Color(0xFFEEEEEE))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Matches", "${team['matchCount']}", Colors.blueGrey),
              _buildStatItem("Auto Balls", "${team['sumAutoBalls']}", Colors.orange),
              _buildStatItem("Tele Balls", "${team['sumTeleopBalls']}", Colors.blue),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusTag(team['hasLeaveEver'], "Leave"),
              _buildStatusTag(team['hasAutoHangEver'], "AutoHang"),
              _buildStatItem("Max End", "L${team['maxEndgameLevel']}", Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatusTag(bool isActive, String label) {
    Color color = isActive ? Colors.green : Colors.grey.shade300;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.grey)),
    );
  }
}