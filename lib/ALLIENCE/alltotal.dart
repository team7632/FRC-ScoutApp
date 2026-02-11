import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';

// --- 同步：歸一化路徑繪製器 ---
class PathPainter extends CustomPainter {
  final List<Offset?> normalizedPoints;
  final Color color;
  PathPainter(this.normalizedPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5; // 歷史路徑預覽稍微細一點更精緻

    for (int i = 0; i < normalizedPoints.length - 1; i++) {
      if (normalizedPoints[i] != null && normalizedPoints[i + 1] != null) {
        // 重要：將 0.0~1.0 的比例乘以目前 Canvas 的實際尺寸
        Offset start = Offset(
          normalizedPoints[i]!.dx * size.width,
          normalizedPoints[i]!.dy * size.height,
        );
        Offset end = Offset(
          normalizedPoints[i + 1]!.dx * size.width,
          normalizedPoints[i + 1]!.dy * size.height,
        );
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

  // --- 數據處理：同步 Depot 與 歸一化座標 ---
  List<Map<String, dynamic>> _processTeamData() {
    Map<String, Map<String, dynamic>> teamStats = {};
    for (var report in _reports) {
      String teamNum = report['teamNumber'].toString();
      int autoBalls = int.tryParse(report['autoBallCount'].toString()) ?? 0;
      int teleopBalls = int.tryParse(report['teleopBallCount'].toString()) ?? 0;
      bool isHanging = report['isAutoHanging'] == true || report['isAutoHanging'] == 1;
      bool isLeave = report['isLeave'] == true || report['isLeave'] == 1;
      int endgameLevel = int.tryParse(report['endgameLevel'].toString()) ?? 0;

      // 取得歸一化點
      List<dynamic>? pathPointsJson = report['autoPathPoints'];

      double autoScore = (autoBalls * 1.0) + (isHanging ? 15.0 : 0.0) + (isLeave ? 3.0 : 0.0);
      double teleopScore = (teleopBalls * 1.0) + (endgameLevel * 10.0);

      if (!teamStats.containsKey(teamNum)) {
        teamStats[teamNum] = {
          'teamNumber': teamNum,
          'sumTotal': 0.0,
          'sumAutoBalls': 0,
          'sumTeleopBalls': 0,
          'matchCount': 0,
          'maxEndgameLevel': 0,
          'pathDataList': <Map<String, dynamic>>[],
        };
      }

      var stats = teamStats[teamNum]!;
      stats['sumTotal'] += (autoScore + teleopScore);
      stats['sumAutoBalls'] += autoBalls;
      stats['sumTeleopBalls'] += teleopBalls;
      stats['matchCount'] += 1;
      if (endgameLevel > stats['maxEndgameLevel']) stats['maxEndgameLevel'] = endgameLevel;

      if (pathPointsJson != null && pathPointsJson.isNotEmpty) {
        (stats['pathDataList'] as List).add({
          'match': report['matchNumber'].toString(),
          'depot': report['depot'] ?? "Unknown", // 同步 Depot 資訊
          'points': _convertToOffsets(pathPointsJson),
        });
      }
    }
    return teamStats.values.map((team) {
      team['avgTotal'] = team['sumTotal'] / team['matchCount'];
      return team;
    }).toList()..sort((a, b) => b['avgTotal'].compareTo(a['avgTotal']));
  }

  List<Offset?> _convertToOffsets(List<dynamic> jsonList) {
    return jsonList.map((item) {
      if (item == null) return null;
      return Offset(
          double.parse(item['x'].toString()),
          double.parse(item['y'].toString())
      );
    }).toList();
  }

  // --- UI: 同步不歪斜的路徑預覽 ---
  Widget _buildPathPreview(List<Offset?> normalizedPoints) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // 同步：使用 BoxFit.fill 配合歸一化座標
                    Image.asset(
                        'assets/images/field2026.png',
                        fit: BoxFit.fill,
                        width: double.infinity,
                        height: double.infinity
                    ),
                    CustomPaint(
                      painter: PathPainter(normalizedPoints, primaryPurple),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  void _showPathGallery(String teamNum, List<dynamic> pathList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1B1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Team $teamNum - Strategy Map", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: pathList.length,
                itemBuilder: (context, index) {
                  final item = pathList[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.adjust, color: primaryPurple, size: 16),
                              const SizedBox(width: 8),
                              Text("Match ${item['match']}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          // 顯示出發位置
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                            child: Text("Depot: ${item['depot']}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildPathPreview(item['points'] as List<Offset?>),
                      const SizedBox(height: 30),
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

  Widget _buildTeamCard(Map<String, dynamic> team, int rank) {
    bool hasPaths = (team['pathDataList'] as List).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("TEAM", style: TextStyle(fontSize: 10, color: Colors.black38)),
                  Text(team['teamNumber'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(team['avgTotal'].toStringAsFixed(1), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryPurple)),
                  const Text("AVG PTS", style: TextStyle(fontSize: 9, color: Colors.black38)),
                ]),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _buildStatBox("Matches", "${team['matchCount']}"),
                  _buildStatBox("Avg Auto", "${(team['sumAutoBalls']/team['matchCount']).toStringAsFixed(1)}"),
                  _buildStatBox("Avg Tele", "${(team['sumTeleopBalls']/team['matchCount']).toStringAsFixed(1)}"),
                  _buildStatBox("Max End", "L${team['maxEndgameLevel']}"),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: hasPaths ? () => _showPathGallery(team['teamNumber'], team['pathDataList']) : null,
                      icon: Icon(Icons.map_outlined, size: 16, color: hasPaths ? Colors.white : Colors.grey),
                      label: Text(hasPaths ? "Tactical Analysis (${(team['pathDataList'] as List).length})" : "No Path Data"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasPaths ? primaryPurple : Colors.grey.shade200,
                        foregroundColor: hasPaths ? Colors.white : Colors.grey,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 輔助元件 ---
  Widget _buildRankBadge(int rank) => Container(width: 36, height: 36, decoration: BoxDecoration(color: rank <= 3 ? primaryPurple.withOpacity(0.1) : Colors.grey.shade100, shape: BoxShape.circle), alignment: Alignment.center, child: Text("#$rank", style: TextStyle(fontWeight: FontWeight.bold, color: rank <= 3 ? primaryPurple : Colors.black45)));
  Widget _buildStatBox(String label, String value) => Column(children: [Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 10, color: Colors.black38))]);
  Widget _buildEmptyState() => const Center(child: Text("No data yet"));
  void _showErrorSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _exportXlsx(dynamic _) async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$serverIp/v1/rooms/export-excel?roomName=${widget.roomName}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/${widget.roomName}_Ranking.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(filePath)], text: 'FRC Ranking - ${widget.roomName}');
      }
    } catch (e) {
      _showErrorSnackBar("Export failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _processTeamData();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("${widget.roomName} Ranking", style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: groupedData.isEmpty ? null : () => _exportXlsx(groupedData)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedData.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchTotalData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedData.length,
          itemBuilder: (context, index) => _buildTeamCard(groupedData[index], index + 1),
        ),
      ),
    );
  }
}