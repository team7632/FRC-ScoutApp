import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../PIT/pitcheckpage.dart';
import 'api.dart';

// --- 自定義畫布：用於在排行榜中預覽自動化路徑 ---
class PathPainter extends CustomPainter {
  final List<Offset?> normalizedPoints;
  final Color color;
  PathPainter(this.normalizedPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < normalizedPoints.length - 1; i++) {
      if (normalizedPoints[i] != null && normalizedPoints[i + 1] != null) {
        Offset start = Offset(normalizedPoints[i]!.dx * size.width, normalizedPoints[i]!.dy * size.height);
        Offset end = Offset(normalizedPoints[i + 1]!.dx * size.width, normalizedPoints[i + 1]!.dy * size.height);
        canvas.drawLine(start, end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) => true;
}

class AllTotalPage extends StatefulWidget {
  final String roomName;
  const AllTotalPage({super.key, required this.roomName});

  @override
  State<AllTotalPage> createState() => _AllTotalPageState();
}

class _AllTotalPageState extends State<AllTotalPage> {
  List<dynamic> _allRegisteredTeams = []; // ⭐ 來自新 API: /v1/rooms/teams
  List<dynamic> _reports = [];           // 來自 API: /v1/rooms/all-reports
  bool _isLoading = true;

  // 顏色風格設定
  final Color brandPurple = const Color(0xFF673AB7);
  final Color accentBlue = const Color(0xFF1A73E8);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // ⭐ 核心同步：抓取名單與報告
  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. 抓取 AdminConfig 設定的所有隊伍
      final teamsRes = await http.get(Uri.parse('${Api.serverIp}/v1/rooms/teams?roomName=${widget.roomName}'));
      // 2. 抓取所有已提交的比賽報告
      final reportsRes = await http.get(Uri.parse('${Api.serverIp}/v1/rooms/all-reports?roomName=${widget.roomName}'));

      if (mounted) {
        setState(() {
          _allRegisteredTeams = teamsRes.statusCode == 200 ? jsonDecode(teamsRes.body) : [];
          _reports = reportsRes.statusCode == 200 ? jsonDecode(reportsRes.body) : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ⭐ 計分權重同步：Fuel 皆為 1 分
  Map<String, double> _calculateScores(dynamic r) {
    // 根據你的需求：Fuel 權重為 1
    double autoFuel = (double.tryParse(r['autoBallCount']?.toString() ?? "0") ?? 0) * 1.0;
    double teleFuel = (double.tryParse(r['teleopBallCount']?.toString() ?? "0") ?? 0) * 1.0;

    // 其他加分項 (與後端 calculateScore 同步)
    double leave = (r['isLeave'] == true || r['isLeave'] == 1) ? 3.0 : 0.0;
    double hang = (r['isAutoHanging'] == true || r['isAutoHanging'] == 1) ? 15.0 : 0.0;
    double end = (double.tryParse(r['endgameLevel']?.toString() ?? "0") ?? 0) * 10.0;

    return {
      'auto': autoFuel + leave + hang,
      'tele': teleFuel + end,
      'total': autoFuel + leave + hang + teleFuel + end
    };
  }

  List<Map<String, dynamic>> _processData() {
    Map<String, Map<String, dynamic>> teamStats = {};

    // 1. 先用 AdminConfig 的隊伍名單初始化 (確保沒數據的隊伍也會顯示)
    for (var team in _allRegisteredTeams) {
      String teamNum = team['teamNumber'].toString();
      teamStats[teamNum] = {
        'teamNumber': teamNum,
        'sumTotal': 0.0,
        'matchCount': 0,
        'isScouted': false,
        'pathDataList': <Map<String, dynamic>>[],
      };
    }

    // 2. 疊加偵察報告數據
    for (var report in _reports) {
      String teamNum = report['teamNumber'].toString();
      if (!teamStats.containsKey(teamNum)) continue; // 忽略未註冊隊伍

      var scores = _calculateScores(report);
      var s = teamStats[teamNum]!;

      s['sumTotal'] += scores['total']!;
      s['matchCount'] += 1;
      s['isScouted'] = true;

      // 如果有路徑數據則加入
      if (report['autoPathPoints'] != null && (report['autoPathPoints'] as List).isNotEmpty) {
        (s['pathDataList'] as List).add({
          'match': report['matchNumber'].toString(),
          'points': _convertToOffsets(report['autoPathPoints']),
        });
      }
    }

    // 3. 計算平均分並排序 (由高到低)
    return teamStats.values.map((t) {
      t['avgTotal'] = t['matchCount'] > 0 ? t['sumTotal'] / t['matchCount'] : 0.0;
      return t;
    }).toList()..sort((a, b) => b['avgTotal'].compareTo(a['avgTotal']));
  }

  List<Offset?> _convertToOffsets(List<dynamic> jsonList) {
    return jsonList.map((item) {
      if (item == null) return null;
      return Offset(double.parse(item['x'].toString()), double.parse(item['y'].toString()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboard = _processData();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text("Leaderboard: ${widget.roomName}",
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded, color: brandPurple),
            onPressed: _handleExport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaderboard.length,
          itemBuilder: (context, index) => _buildTeamCard(leaderboard[index], index + 1),
        ),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int rank) {
    bool isScouted = team['isScouted'];
    bool hasPaths = (team['pathDataList'] as List).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: _buildRankBadge(rank, isScouted),
              title: Text("Team ${team['teamNumber']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(isScouted ? "Matches: ${team['matchCount']}" : "No data yet"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(team['avgTotal'].toStringAsFixed(1),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandPurple)),
                  const Text("AVG", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isScouted ? Colors.white : Colors.grey[50],
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: hasPaths ? () => _showPathGallery(team['teamNumber'], team['pathDataList']) : null,
                      icon: const Icon(Icons.auto_graph, size: 18),
                      label: Text("Auto Paths (${(team['pathDataList'] as List).length})"),
                      style: TextButton.styleFrom(foregroundColor: brandPurple),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PitCheckPage(teamNumber: team['teamNumber'], roomName: widget.roomName)
                        ),
                      ).then((_) => _fetchInitialData());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Pit Details"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank, bool isScouted) {
    return Container(
      width: 35, height: 35,
      decoration: BoxDecoration(
        color: isScouted ? brandPurple.withOpacity(0.1) : Colors.grey[200],
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text("$rank",
          style: TextStyle(fontWeight: FontWeight.bold, color: isScouted ? brandPurple : Colors.grey)),
    );
  }

  // 顯示該隊伍所有比賽的自動化路徑軌跡
  void _showPathGallery(String teamNum, List<dynamic> pathList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Team $teamNum - Strategy Map", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: pathList.length,
                itemBuilder: (context, index) {
                  final item = pathList[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(title: Text("Match ${item['match']}"), dense: true),
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            children: [
                              Image.asset('assets/images/field2026.png', fit: BoxFit.cover),
                              CustomPaint(
                                painter: PathPainter(item['points'] as List<Offset?>, brandPurple),
                                size: Size.infinite,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 呼叫後端 Excel 導出
  Future<void> _handleExport() async {
    try {
      final url = Uri.parse('${Api.serverIp}/v1/rooms/export-excel?roomName=${widget.roomName}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Scouting_${widget.roomName}.xlsx');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Exported Scouting Data');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export")));
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }
}