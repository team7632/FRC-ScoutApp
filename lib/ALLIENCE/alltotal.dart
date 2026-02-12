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
      ..strokeWidth = 3.5;

    // 繪製路徑線條
    for (int i = 0; i < normalizedPoints.length - 1; i++) {
      if (normalizedPoints[i] != null && normalizedPoints[i + 1] != null) {
        // 將 0.0~1.0 的座標還原至實際畫布大小
        Offset start = Offset(normalizedPoints[i]!.dx * size.width, normalizedPoints[i]!.dy * size.height);
        Offset end = Offset(normalizedPoints[i + 1]!.dx * size.width, normalizedPoints[i + 1]!.dy * size.height);
        canvas.drawLine(start, end, paint);
      }
    }

    // 繪製端點（增加視覺辨識度）
    if (normalizedPoints.isNotEmpty && normalizedPoints.first != null) {
      canvas.drawCircle(Offset(normalizedPoints.first!.dx * size.width, normalizedPoints.first!.dy * size.height), 4, Paint()..color = Colors.greenAccent);
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
  List<dynamic> _allRegisteredTeams = [];
  List<dynamic> _reports = [];
  bool _isLoading = true;

  final Color brandPurple = const Color(0xFF673AB7);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  /// 抓取 Ngrok/Server 數據
  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 增加 Ngrok 跳過警告的 Header
      final headers = {"ngrok-skip-browser-warning": "true"};

      final teamsRes = await http.get(Uri.parse('${Api.serverIp}/v1/rooms/teams?roomName=${widget.roomName}'), headers: headers);
      final reportsRes = await http.get(Uri.parse('${Api.serverIp}/v1/rooms/all-reports?roomName=${widget.roomName}'), headers: headers);

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

  /// 計分權重計算 (與後端同步)
  Map<String, double> _calculateScores(dynamic r) {
    double autoFuel = (double.tryParse(r['autoBallCount']?.toString() ?? "0") ?? 0) * 1.0;
    double teleFuel = (double.tryParse(r['teleopBallCount']?.toString() ?? "0") ?? 0) * 1.0;
    double leave = (r['isLeave'] == true || r['isLeave'] == 1) ? 3.0 : 0.0;
    double hang = (r['isAutoHanging'] == true || r['isAutoHanging'] == 1) ? 15.0 : 0.0;
    double end = (double.tryParse(r['endgameLevel']?.toString() ?? "0") ?? 0) * 10.0;

    return {
      'total': autoFuel + leave + hang + teleFuel + end
    };
  }

  List<Map<String, dynamic>> _processData() {
    Map<String, Map<String, dynamic>> teamStats = {};

    // 1. 初始化名單
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

    // 2. 處理報告
    for (var report in _reports) {
      String teamNum = report['teamNumber'].toString();
      if (!teamStats.containsKey(teamNum)) continue;

      var scores = _calculateScores(report);
      var s = teamStats[teamNum]!;

      s['sumTotal'] += scores['total']!;
      s['matchCount'] += 1;
      s['isScouted'] = true;

      // 解析路徑 (支援新版結構化 JSON)
      if (report['autoPathPoints'] != null && (report['autoPathPoints'] as List).isNotEmpty) {
        (s['pathDataList'] as List).add({
          'match': report['matchNumber'].toString(),
          'points': _convertToOffsets(report['autoPathPoints']),
        });
      }
    }

    return teamStats.values.map((t) {
      t['avgTotal'] = t['matchCount'] > 0 ? t['sumTotal'] / t['matchCount'] : 0.0;
      return t;
    }).toList()..sort((a, b) => b['avgTotal'].compareTo(a['avgTotal']));
  }

  /// 將 JSON 座標轉為 Offset
  List<Offset?> _convertToOffsets(List<dynamic> jsonList) {
    return jsonList.map((item) {
      if (item == null) return null;
      // 兼容舊版手繪點位與新版 Waypoint 物件
      double x = double.tryParse(item['x'].toString()) ?? 0.0;
      double y = double.tryParse(item['y'].toString()) ?? 0.0;
      return Offset(x, y);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboard = _processData();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Leaderboard: ${widget.roomName}", style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchInitialData),
          IconButton(icon: const Icon(Icons.download_rounded), onPressed: _handleExport),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: leaderboard.length,
        itemBuilder: (context, index) => _buildTeamCard(leaderboard[index], index + 1),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int rank) {
    bool isScouted = team['isScouted'];
    bool hasPaths = (team['pathDataList'] as List).isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: isScouted ? brandPurple : Colors.grey[300],
              child: Text("$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text("Team ${team['teamNumber']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isScouted ? "Avg Score: ${team['avgTotal'].toStringAsFixed(1)} (${team['matchCount']} Matches)" : "Pending Scouter..."),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => PitCheckPage(teamNumber: team['teamNumber'], roomName: widget.roomName)
              )).then((_) => _fetchInitialData());
            },
          ),
          if (hasPaths)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.map_outlined, size: 16),
                label: Text("View Auto Strategy (${(team['pathDataList'] as List).length})"),
                onPressed: () => _showPathGallery(team['teamNumber'], team['pathDataList']),
              ),
            )
        ],
      ),
    );
  }

  void _showPathGallery(String teamNum, List<dynamic> pathList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Team $teamNum - Autonomous Paths", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: pathList.length,
                itemBuilder: (context, index) {
                  final item = pathList[index];
                  return Column(
                    children: [
                      Text("Match ${item['match']}", style: const TextStyle(color: Colors.white70)),
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          children: [
                            Opacity(opacity: 0.6, child: Image.asset('assets/images/field2026.png', fit: BoxFit.cover)),
                            CustomPaint(
                              painter: PathPainter(item['points'] as List<Offset?>, Colors.cyanAccent),
                              size: Size.infinite,
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 32),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    try {
      final url = Uri.parse('${Api.serverIp}/v1/rooms/export-excel?roomName=${widget.roomName}');
      final response = await http.get(url, headers: {"ngrok-skip-browser-warning": "true"});
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Scouting_${widget.roomName}.xlsx');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }
}