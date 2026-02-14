import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../PIT/pitcheckpage.dart';
import 'api.dart';

class AdvancedPathPainter extends CustomPainter {
  final List<dynamic> rawPoints;
  final double progress;
  final String drivetrain;

  AdvancedPathPainter({
    required this.rawPoints,
    required this.progress,
    required this.drivetrain,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rawPoints.isEmpty) return;

    // ✅ 防溢位處理：內縮 12 像素作為安全區
    const double padding = 12.0;
    final double drawW = size.width - (padding * 2);
    final double drawH = size.height - (padding * 2);

    final List<Offset> points = rawPoints.map((p) =>
        Offset(
          double.parse(p['x'].toString()) * drawW + padding,
          double.parse(p['y'].toString()) * drawH + padding,
        )
    ).toList();


    final linePaint = Paint()
      ..color = const Color(0xFFB388FF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // 2. 計算並繪製機器人動畫 (Swerve 模擬)
    int segmentCount = points.length - 1;
    if (segmentCount > 0) {
      double totalProgress = progress * segmentCount;
      int currentIndex = totalProgress.floor();
      double segmentProgress = totalProgress - currentIndex;

      if (currentIndex < segmentCount) {
        Offset p1 = points[currentIndex];
        Offset p2 = points[currentIndex + 1];
        Offset currentPos = Offset.lerp(p1, p2, segmentProgress)!;

        double h1 = double.parse(rawPoints[currentIndex]['h'].toString());
        double h2 = double.parse(rawPoints[currentIndex + 1]['h'].toString());


        double diff = (h2 - h1) % (2 * math.pi);
        if (diff > math.pi) diff -= 2 * math.pi;
        if (diff < -math.pi) diff += 2 * math.pi;
        double finalRotation = h1 + diff * segmentProgress;

        canvas.save();
        canvas.translate(currentPos.dx, currentPos.dy);
        canvas.rotate(finalRotation);
        _drawSwerveRobotModel(canvas, diff, (p2 - p1));
        canvas.restore();
      }
    }

    for (int i = 0; i < points.length; i++) {
      final p = rawPoints[i];
      final pos = points[i];
      double wait = double.tryParse(p['w']?.toString() ?? "0") ?? 0;
      String cmd = p['c']?.toString() ?? "";

      canvas.drawCircle(pos, 2.5, Paint()..color = wait > 0 ? Colors.redAccent : const Color(0xFFB388FF));

      if (cmd.isNotEmpty) {
        _drawSafeTag(canvas, "⚡ $cmd", pos + const Offset(0, -16), Colors.orangeAccent, size);
      }
      if (wait > 0) {
        _drawSafeTag(canvas, "⏱ ${wait}s", pos + const Offset(0, 10), Colors.redAccent, size);
      }
    }
  }

  void _drawSwerveRobotModel(Canvas canvas, double rotVel, Offset velocity) {

    final bodyPaint = Paint()..color = const Color(0xFF7E57C2);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 16, height: 16), bodyPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 16, height: 16),
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.5);


    List<Offset> modules = [const Offset(-6, -6), const Offset(6, -6), const Offset(-6, 6), const Offset(6, 6)];
    for (var modPos in modules) {
      Offset tangent = Offset(-modPos.dy, modPos.dx) * (rotVel * 0.5);
      Offset wheelDir = velocity + tangent;

      canvas.save();
      canvas.translate(modPos.dx, modPos.dy);
      canvas.rotate(wheelDir.direction + (math.pi / 2));
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 3, height: 6), const Radius.circular(1)),
          Paint()..color = Colors.cyanAccent
      );
      canvas.restore();
    }

    canvas.drawRect(const Rect.fromLTWH(-8, -8, 16, 2.5), Paint()..color = Colors.greenAccent);
  }

  void _drawSafeTag(Canvas canvas, String text, Offset position, Color color, Size canvasSize) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr)..layout();

    double x = position.dx.clamp(tp.width / 2 + 2, canvasSize.width - tp.width / 2 - 2);
    double y = position.dy.clamp(tp.height / 2 + 2, canvasSize.height - tp.height / 2 - 2);
    Offset safePos = Offset(x, y);

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: safePos, width: tp.width + 4, height: tp.height + 1), const Radius.circular(3)),
        Paint()..color = color);
    tp.paint(canvas, safePos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- 2. 路徑預覽卡片組件 ---
class PathPreviewCard extends StatefulWidget {
  final dynamic pathItem;
  final String drivetrain;
  const PathPreviewCard({super.key, required this.pathItem, required this.drivetrain});

  @override
  State<PathPreviewCard> createState() => _PathPreviewCardState();
}

class _PathPreviewCardState extends State<PathPreviewCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("MATCH ${widget.pathItem['match']}", style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 12),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Positioned.fill(child: Opacity(opacity: 0.5, child: Image.asset('assets/images/field2026.png', fit: BoxFit.fill))),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: AdvancedPathPainter(
                          rawPoints: widget.pathItem['raw'],
                          progress: _controller.value,
                          drivetrain: widget.drivetrain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class AllTotalPage extends StatefulWidget {
  final String roomName;
  const AllTotalPage({super.key, required this.roomName});

  @override
  State<AllTotalPage> createState() => _AllTotalPageState();
}

class _AllTotalPageState extends State<AllTotalPage> {
  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color accentPurple = const Color(0xFFB388FF);

  List<dynamic> _allRegisteredTeams = [];
  List<dynamic> _reports = [];
  Map<String, String> _teamDrivetrains = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final headers = {"ngrok-skip-browser-warning": "true"};
      final teamsRes = await http.get(Uri.parse('${Api.serverIp}/v1/rooms/teams?roomName=${widget.roomName}'), headers: headers);
      final reportsRes = await http.get(Uri.parse('${Api.serverIp}/v1/rooms/all-reports?roomName=${widget.roomName}'), headers: headers);

      if (mounted) {
        _allRegisteredTeams = jsonDecode(teamsRes.body);
        _reports = jsonDecode(reportsRes.body);

        for (var team in _allRegisteredTeams) {
          String teamNum = team['teamNumber'].toString();
          final pitRes = await http.get(Uri.parse('${Api.serverIp}/v1/pit/get-data?roomName=${widget.roomName}&teamNumber=$teamNum'), headers: headers);
          if (pitRes.statusCode == 200) {
            _teamDrivetrains[teamNum] = jsonDecode(pitRes.body)['drivetrain'] ?? "Swerve";
          }
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _processData() {
    Map<String, Map<String, dynamic>> teamStats = {};

    for (var team in _allRegisteredTeams) {
      String teamNum = team['teamNumber'].toString();
      teamStats[teamNum] = {
        'teamNumber': teamNum,
        'sumTotal': 0.0,
        'matchCount': 0,
        'pathDataList': <Map<String, dynamic>>[],
      };
    }

    for (var report in _reports) {
      String teamNum = report['teamNumber'].toString();
      if (!teamStats.containsKey(teamNum)) continue;
      teamStats[teamNum]!['matchCount'] += 1;
      teamStats[teamNum]!['sumTotal'] += _calculateScore(report);

      if (report['autoPathPoints'] != null) {
        var points = report['autoPathPoints'];
        if (points is String) points = jsonDecode(points);
        if ((points as List).isNotEmpty) {
          (teamStats[teamNum]!['pathDataList'] as List).add({'match': report['matchNumber'], 'raw': points});
        }
      }
    }

    return teamStats.values.map((t) {
      t['avgTotal'] = t['matchCount'] > 0 ? t['sumTotal'] / t['matchCount'] : 0.0;
      return t;
    }).toList()..sort((a, b) => b['avgTotal'].compareTo(a['avgTotal']));
  }

  double _calculateScore(dynamic r) {
    double auto = (double.tryParse(r['autoBallCount']?.toString() ?? "0") ?? 0);
    double leave = (r['isLeave'] == true || r['isLeave'] == 1) ? 3.0 : 0.0;
    double hang = (r['isAutoHanging'] == true || r['isAutoHanging'] == 1) ? 15.0 : 0.0;
    double tele = (double.tryParse(r['teleopBallCount']?.toString() ?? "0") ?? 0);
    double end = (double.tryParse(r['endgameLevel']?.toString() ?? "0") ?? 0) * 10.0;
    return auto + leave + hang + tele + end;
  }

  @override
  Widget build(BuildContext context) {
    final leaderboard = _processData();

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("RANKING: ${widget.roomName}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20), onPressed: _fetchInitialData),
          IconButton(icon: const Icon(Icons.ios_share_rounded, color: Color(0xFFB388FF), size: 20), onPressed: _handleExport),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentPurple))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: leaderboard.length,
        itemBuilder: (context, index) => _buildTeamCard(leaderboard[index], index + 1),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int rank) {
    String teamNum = team['teamNumber'];
    bool hasPaths = (team['pathDataList'] as List).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rank <= 3 ? accentPurple.withOpacity(0.4) : Colors.white.withOpacity(0.05)),
        boxShadow: rank <= 3 ? [BoxShadow(color: accentPurple.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)] : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: _buildRankBadge(rank),
          title: Text("TEAM $teamNum", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          subtitle: Text("AVG: ${team['avgTotal'].toStringAsFixed(1)} pts", style: TextStyle(color: accentPurple, fontSize: 11, fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (hasPaths) ...[
              const Divider(color: Colors.white10, height: 20),
              const Align(alignment: Alignment.centerLeft, child: Text("AUTO PATHS", style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
              const SizedBox(height: 10),
              ... (team['pathDataList'] as List).take(3).map((path) => PathPreviewCard(pathItem: path, drivetrain: _teamDrivetrains[teamNum] ?? "Swerve")),
            ],
            const SizedBox(height: 12),
            _buildPitButton(teamNum),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: rank <= 3 ? accentPurple.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: rank <= 3 ? accentPurple.withOpacity(0.5) : Colors.transparent),
      ),
      child: Center(child: Text("$rank", style: TextStyle(color: rank <= 3 ? accentPurple : Colors.white38, fontWeight: FontWeight.bold, fontSize: 13))),
    );
  }

  Widget _buildPitButton(String teamNum) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PitCheckPage(teamNumber: teamNum, roomName: widget.roomName))),
        child: const Text("VIEW PIT DETAILS", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  Future<void> _handleExport() async {
    HapticFeedback.lightImpact();
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