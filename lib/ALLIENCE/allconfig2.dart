import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'api.dart';

// --- 通用路徑繪製器 (還原歸一化座標) ---
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
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() {
          _reports = jsonDecode(response.body);
          _runFilter(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  List<Offset?> _convertToOffsets(List<dynamic>? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((item) {
      if (item == null) return null;
      return Offset(
        double.parse(item['x'].toString()),
        double.parse(item['y'].toString()),
      );
    }).toList();
  }

  void _editReport(int index) {
    final report = _filteredReports[index];
    final originalIndex = _reports.indexOf(report);

    // 得分控制
    TextEditingController autoBallCtrl = TextEditingController(text: report['autoBallCount'].toString());
    TextEditingController teleBallCtrl = TextEditingController(text: report['teleopBallCount'].toString());

    // 戰術計數器 (Auto)
    TextEditingController aBumpCtrl = TextEditingController(text: (report['autoBump'] ?? 0).toString());
    TextEditingController aTrenchCtrl = TextEditingController(text: (report['autoTrench'] ?? 0).toString());
    TextEditingController aDepotCtrl = TextEditingController(text: (report['autoDepot'] ?? 0).toString());
    TextEditingController aOutpostCtrl = TextEditingController(text: (report['autoOutpost'] ?? 0).toString());

    // 戰術計數器 (Teleop)
    TextEditingController tBumpCtrl = TextEditingController(text: (report['teleBump'] ?? 0).toString());
    TextEditingController tTrenchCtrl = TextEditingController(text: (report['teleTrench'] ?? 0).toString());
    TextEditingController tDepotCtrl = TextEditingController(text: (report['teleDepot'] ?? 0).toString());
    TextEditingController tOutpostCtrl = TextEditingController(text: (report['teleOutpost'] ?? 0).toString());

    bool tempIsHanging = report['isAutoHanging'] == true || report['isAutoHanging'] == 1;
    bool tempIsLeave = report['isLeave'] == true || report['isLeave'] == 1;
    int tempEndgame = int.tryParse(report['endgameLevel'].toString()) ?? 0;
    String tempDepotPos = report['depot']?.toString() ?? "Near"; // 起始位置

    List<Offset?> pathOffsets = _convertToOffsets(report['autoPathPoints']);

    showCupertinoDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text("Edit M${report['matchNumber']} - T${report['teamNumber']}"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                const Divider(height: 25),
                _buildEditField("AUTO Fuels", autoBallCtrl),
                _buildEditField("TELE Fuels", teleBallCtrl),

                const Divider(height: 25),
                const Text("AUTO STRATEGY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey)),
                _buildEditField("A-BUMP", aBumpCtrl),
                _buildEditField("A-TRENCH", aTrenchCtrl),
                _buildEditField("A-DEPOT", aDepotCtrl),
                _buildEditField("A-OUTPOST", aOutpostCtrl),

                const SizedBox(height: 10),
                const Text("TELEOP STRATEGY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey)),
                _buildEditField("T-BUMP", tBumpCtrl),
                _buildEditField("T-TRENCH", tTrenchCtrl),
                _buildEditField("T-DEPOT", tDepotCtrl),
                _buildEditField("T-OUTPOST", tOutpostCtrl),

                const Divider(height: 25),
                _buildSwitchRow("Leave (3pt)", tempIsLeave, (v) => setDialogState(() => tempIsLeave = v)),
                _buildSwitchRow("Hang (15pt)", tempIsHanging, (v) => setDialogState(() => tempIsHanging = v)),

                const Divider(height: 20),
                const Text("ENDGAME LEVEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey)),
                const SizedBox(height: 8),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: tempEndgame,
                  children: const {
                    0: Text("None", style: TextStyle(fontSize: 11)),
                    1: Text("L1", style: TextStyle(fontSize: 11)),
                    2: Text("L2", style: TextStyle(fontSize: 11)),
                    3: Text("L3", style: TextStyle(fontSize: 11)),
                  },
                  onValueChanged: (val) => setDialogState(() => tempEndgame = val ?? 0),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(child: const Text("Cancel"), onPressed: () => Navigator.pop(c)),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text("Update"),
              onPressed: () async {
                Navigator.pop(c);
                try {
                  await http.post(
                    Uri.parse('${Api.serverIp}/v1/rooms/update-report'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'roomName': widget.roomName,
                      'index': originalIndex,
                      'newAutoCount': int.tryParse(autoBallCtrl.text) ?? 0,
                      'newTeleopCount': int.tryParse(teleBallCtrl.text) ?? 0,
                      'newIsHanging': tempIsHanging,
                      'newIsLeave': tempIsLeave,
                      'newEndgameLevel': tempEndgame,
                      'newDepot': tempDepotPos, // 起始位置字串
                      // 戰術數據同步
                      'autoBump': int.tryParse(aBumpCtrl.text) ?? 0,
                      'autoTrench': int.tryParse(aTrenchCtrl.text) ?? 0,
                      'autoDepot': int.tryParse(aDepotCtrl.text) ?? 0,
                      'autoOutpost': int.tryParse(aOutpostCtrl.text) ?? 0,
                      'teleBump': int.tryParse(tBumpCtrl.text) ?? 0,
                      'teleTrench': int.tryParse(tTrenchCtrl.text) ?? 0,
                      'teleDepot': int.tryParse(tDepotCtrl.text) ?? 0,
                      'teleOutpost': int.tryParse(tOutpostCtrl.text) ?? 0,
                    }),
                  );
                  _fetchReports();
                } catch (e) {
                  debugPrint("❌ Update Failed: $e");
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 95, child: Text(label, style: const TextStyle(fontSize: 13, color: CupertinoColors.label))),
          Expanded(
            child: SizedBox(
              height: 30,
              child: CupertinoTextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
                decoration: BoxDecoration(color: CupertinoColors.extraLightBackgroundGray, borderRadius: BorderRadius.circular(5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          CupertinoSwitch(value: value, onChanged: onChanged, activeColor: CupertinoColors.activeOrange),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Correction Panel"),
        trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: _fetchReports, child: const Icon(CupertinoIcons.refresh)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(controller: _searchController, placeholder: "Search Match/Team", onChanged: _runFilter),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredReports.length,
                itemBuilder: (context, index) {
                  final item = _filteredReports[index];
                  bool isHanging = item['isAutoHanging'] == true || item['isAutoHanging'] == 1;
                  bool isLeave = item['isLeave'] == true || item['isLeave'] == 1;
                  int egLevel = int.tryParse(item['endgameLevel'].toString()) ?? 0;
                  int total = (int.tryParse(item['autoBallCount'].toString()) ?? 0) * 1 + (isLeave ? 3 : 0) + (isHanging ? 15 : 0) + (int.tryParse(item['teleopBallCount'].toString()) ?? 0) * 1 + (egLevel * 10);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                    child: CupertinoListTile(
                      padding: const EdgeInsets.all(12),
                      title: Text("Match ${item['matchNumber']} - Team ${item['teamNumber']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Scouter: ${item['user']} | Depot: ${item['depot'] ?? 'Near'}"),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 5, runSpacing: 5,
                            children: [
                              _tag("A:${item['autoBallCount']}", CupertinoColors.systemYellow),
                              _tag("T:${item['teleopBallCount']}", CupertinoColors.systemBlue),
                              if (item['autoBump'] != null && item['autoBump'] > 0) _tag("BUMP", CupertinoColors.systemGrey),
                              if (item['autoTrench'] != null && item['autoTrench'] > 0) _tag("TRENCH", CupertinoColors.systemGrey),
                              if (isLeave) _tag("Left", CupertinoColors.activeOrange),
                              if (isHanging) _tag("Hang", CupertinoColors.systemGreen),
                            ],
                          )
                        ],
                      ),
                      additionalInfo: Text("$total pt", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.activeBlue)),
                      trailing: const Icon(CupertinoIcons.pencil_circle, color: CupertinoColors.systemGrey),
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

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}