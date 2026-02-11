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
  final Color primaryPurple = const Color(0xFF673AB7);

  @override
  void initState() {
    super.initState();
    _fetchTotalData();
  }

  Future<void> _fetchTotalData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$serverIp/v1/rooms/all-reports?roomName=${widget.roomName}'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reports = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
    await Share.shareXFiles([XFile(file.path)], text: '分析數據導出');
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _processTeamData();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("${widget.roomName} 排行榜", style: const TextStyle(fontWeight: FontWeight.w400)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: groupedData.isEmpty ? null : () => _exportExcel(groupedData),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedData.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchTotalData,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: groupedData.length,
          itemBuilder: (context, index) {
            final team = groupedData[index];
            return _buildTeamCard(team, index + 1);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("尚無數據記錄", style: TextStyle(color: Colors.grey.shade500)),
          TextButton(onPressed: _fetchTotalData, child: const Text("重新整理")),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // 頂部排名與隊伍資訊
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildRankBadge(rank),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("TEAM", style: TextStyle(fontSize: 10, color: Colors.black38, letterSpacing: 1.1)),
                        Text(team['teamNumber'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        team['avgTotal'].toStringAsFixed(1),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: primaryPurple),
                      ),
                      const Text("AVG POINTS", style: TextStyle(fontSize: 9, color: Colors.black38)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            // 詳細數據區塊
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatBox("Matches", "${team['matchCount']}", Colors.blueGrey),
                      _buildStatBox("Auto Balls", "${team['sumAutoBalls']}", Colors.orange.shade700),
                      _buildStatBox("Tele Balls", "${team['sumTeleopBalls']}", Colors.blue.shade700),
                      _buildStatBox("Max End", "L${team['maxEndgameLevel']}", primaryPurple),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildChipTag(team['hasLeaveEver'], "Leave Achieved"),
                      const SizedBox(width: 8),
                      _buildChipTag(team['hasAutoHangEver'], "Auto Hang Achieved"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor = Colors.grey.shade100;
    Color textColor = Colors.black45;

    if (rank == 1) { badgeColor = Colors.amber.shade100; textColor = Colors.amber.shade900; }
    else if (rank == 2) { badgeColor = Colors.blueGrey.shade50; textColor = Colors.blueGrey.shade700; }
    else if (rank == 3) { badgeColor = Colors.orange.shade50; textColor = Colors.orange.shade900; }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text("#$rank", style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black38)),
      ],
    );
  }

  Widget _buildChipTag(bool isActive, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.green.withOpacity(0.2) : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 12,
              color: isActive ? Colors.green : Colors.black12,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.green.shade700 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}