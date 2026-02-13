import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

// --- 同步深色路徑繪製器 ---
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

class AllConfig2 extends StatefulWidget {
  final String roomName;
  const AllConfig2({super.key, required this.roomName});

  @override
  State<AllConfig2> createState() => _AllConfig2State();
}

class _AllConfig2State extends State<AllConfig2> {
  // --- 深色配色方案 ---
  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color primaryPurple = const Color(0xFF7E57C2);

  List<dynamic> _reports = [];
  List<dynamic> _filteredReports = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${Api.serverIp}/v1/rooms/all-reports?roomName=${widget.roomName}'),
        headers: {"ngrok-skip-browser-warning": "true"},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _reports = jsonDecode(response.body);
          _runFilter(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _runFilter(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredReports = _reports;
      } else {
        _filteredReports = _reports.where((report) {
          final match = report['matchNumber'].toString();
          final team = report['teamNumber'].toString();
          return match.contains(keyword) || team.contains(keyword);
        }).toList();
      }
    });
  }

  // --- 編輯彈窗：同步深色樣式與現代化配置 ---
  void _editReport(int index) {
    final report = _filteredReports[index];
    final originalIndex = _reports.indexOf(report);
    HapticFeedback.heavyImpact();

    // 控制器初始化
    TextEditingController autoBallCtrl = TextEditingController(text: report['autoBallCount'].toString());
    TextEditingController teleBallCtrl = TextEditingController(text: report['teleopBallCount'].toString());
    TextEditingController aBumpCtrl = TextEditingController(text: (report['autoBump'] ?? 0).toString());
    TextEditingController aTrenchCtrl = TextEditingController(text: (report['autoTrench'] ?? 0).toString());
    TextEditingController aDepotCtrl = TextEditingController(text: (report['autoDepot'] ?? 0).toString());
    TextEditingController aOutpostCtrl = TextEditingController(text: (report['autoOutpost'] ?? 0).toString());
    TextEditingController tBumpCtrl = TextEditingController(text: (report['teleBump'] ?? 0).toString());
    TextEditingController tTrenchCtrl = TextEditingController(text: (report['teleTrench'] ?? 0).toString());
    TextEditingController tDepotCtrl = TextEditingController(text: (report['teleDepot'] ?? 0).toString());
    TextEditingController tOutpostCtrl = TextEditingController(text: (report['teleOutpost'] ?? 0).toString());

    bool tempIsHanging = report['isAutoHanging'] == true || report['isAutoHanging'] == 1;
    bool tempIsLeave = report['isLeave'] == true || report['isLeave'] == 1;
    int tempEndgame = int.tryParse(report['endgameLevel'].toString()) ?? 0;
    String tempDepotPos = report['depot']?.toString() ?? "Near";

    showDialog(
      context: context,
      builder: (c) => Theme(
        data: ThemeData.dark().copyWith(
          dialogBackgroundColor: surfaceDark,
          colorScheme: ColorScheme.dark(primary: accentPurple),
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Text("EDIT REPORT", style: TextStyle(color: accentPurple, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text("Match ${report['matchNumber']} - Team ${report['teamNumber']}", style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sectionHeader("SCORING"),
                    _buildEditField("Auto Score", autoBallCtrl),
                    _buildEditField("Tele Score", teleBallCtrl),

                    _sectionHeader("AUTO STRATEGY"),
                    _buildEditField("A-Bump", aBumpCtrl),
                    _buildEditField("A-Trench", aTrenchCtrl),

                    _sectionHeader("STATUS"),
                    _buildSwitchRow("Leave (3pt)", tempIsLeave, (v) => setDialogState(() => tempIsLeave = v)),
                    _buildSwitchRow("Auto Hang", tempIsHanging, (v) => setDialogState(() => tempIsHanging = v)),

                    _sectionHeader("ENDGAME LEVEL"),
                    const SizedBox(height: 10),
                    CupertinoSlidingSegmentedControl<int>(
                      backgroundColor: Colors.black26,
                      thumbColor: primaryPurple,
                      groupValue: tempEndgame,
                      children: const {
                        0: Text("None", style: TextStyle(fontSize: 11, color: Colors.white)),
                        1: Text("L1", style: TextStyle(fontSize: 11, color: Colors.white)),
                        2: Text("L2", style: TextStyle(fontSize: 11, color: Colors.white)),
                        3: Text("L3", style: TextStyle(fontSize: 11, color: Colors.white)),
                      },
                      onValueChanged: (val) => setDialogState(() => tempEndgame = val ?? 0),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(child: const Text("CANCEL", style: TextStyle(color: Colors.white38)), onPressed: () => Navigator.pop(c)),
              TextButton(
                child: Text("UPDATE", style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(c);
                  await _updateReport(originalIndex, {
                    'autoBallCount': int.tryParse(autoBallCtrl.text) ?? 0,
                    'teleopBallCount': int.tryParse(teleBallCtrl.text) ?? 0,
                    'isHanging': tempIsHanging,
                    'isLeave': tempIsLeave,
                    'endgameLevel': tempEndgame,
                    'depot': tempDepotPos,
                    'autoBump': int.tryParse(aBumpCtrl.text) ?? 0,
                    'autoTrench': int.tryParse(aTrenchCtrl.text) ?? 0,
                    'teleBump': int.tryParse(tBumpCtrl.text) ?? 0,
                  });
                  _fetchReports();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateReport(int index, Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('${Api.serverIp}/v1/rooms/update-report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'index': index,
          'newAutoCount': data['autoBallCount'],
          'newTeleopCount': data['teleopBallCount'],
          'newIsHanging': data['isHanging'],
          'newIsLeave': data['isLeave'],
          'newEndgameLevel': data['endgameLevel'],
          'newDepot': data['depot'],
          'autoBump': data['autoBump'],
          'autoTrench': data['autoTrench'],
          'teleBump': data['teleBump'],
        }),
      );
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  // --- UI 組件：保持與主系統一致 ---
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(color: accentPurple.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70))),
          SizedBox(
            width: 60,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        CupertinoSwitch(value: value, activeColor: primaryPurple, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("CORRECTION PANEL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchReports),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: "Search Match or Team...",
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: _runFilter,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(color: accentPurple))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filteredReports.length,
                itemBuilder: (context, index) {
                  final item = _filteredReports[index];
                  bool isHanging = item['isAutoHanging'] == true || item['isAutoHanging'] == 1;
                  bool isLeave = item['isLeave'] == true || item['isLeave'] == 1;
                  int total = _calculateTotal(item);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: surfaceDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text("MATCH ${item['matchNumber']} - TEAM ${item['teamNumber']}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Scouter: ${item['user']} | Depot: ${item['depot'] ?? 'N/A'}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: [
                              _tag("AUTO:${item['autoBallCount']}", Colors.orangeAccent),
                              _tag("TELE:${item['teleopBallCount']}", Colors.blueAccent),
                              if (isLeave) _tag("LEFT", accentPurple),
                              if (isHanging) _tag("HANG", Colors.greenAccent),
                            ],
                          )
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("$total", style: TextStyle(color: accentPurple, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                          const Text("PTS", style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      onTap: () => _editReport(index),
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

  int _calculateTotal(dynamic item) {
    bool isHanging = item['isAutoHanging'] == true || item['isAutoHanging'] == 1;
    bool isLeave = item['isLeave'] == true || item['isLeave'] == 1;
    int egLevel = int.tryParse(item['endgameLevel'].toString()) ?? 0;
    return (int.tryParse(item['autoBallCount'].toString()) ?? 0) +
        (isLeave ? 0 : 0) +
        (isHanging ? 15 : 0) +
        (int.tryParse(item['teleopBallCount'].toString()) ?? 0) +
        (egLevel * 10);
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}