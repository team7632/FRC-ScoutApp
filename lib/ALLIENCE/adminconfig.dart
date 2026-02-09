import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // 引入 Timer 用於防抖
import 'alltotal.dart';
import 'api.dart';

class AdminConfig extends StatefulWidget {
  final String roomName;
  const AdminConfig({super.key, required this.roomName});

  @override
  State<AdminConfig> createState() => _AdminConfigState();
}

class _AdminConfigState extends State<AdminConfig> {
  final String serverIp = Api.serverIp;
  bool _isLoading = true;
  bool _isAutoSaving = false; // 顯示自動儲存狀態
  Timer? _debounce;

  int _viewingMatch = 1;
  List<int> _availableMatches = [1];
  List<String> _allActiveUsers = ["尚未分配"];

  final Map<String, TextEditingController> _userControllers = {
    'Red 1': TextEditingController(text: "尚未分配"), 'Red 2': TextEditingController(text: "尚未分配"), 'Red 3': TextEditingController(text: "尚未分配"),
    'Blue 1': TextEditingController(text: "尚未分配"), 'Blue 2': TextEditingController(text: "尚未分配"), 'Blue 3': TextEditingController(text: "尚未分配"),
  };
  final Map<String, TextEditingController> _teamControllers = {
    'Red 1': TextEditingController(), 'Red 2': TextEditingController(), 'Red 3': TextEditingController(),
    'Blue 1': TextEditingController(), 'Blue 2': TextEditingController(), 'Blue 3': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _fetchConfigForMatch(1);
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 銷毀時取消計時器
    super.dispose();
  }

  // 觸發自動儲存（防抖）
  void _onDataChanged() {
    setState(() => _isAutoSaving = true);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _saveCurrentEdit();
    });
  }

  Future<void> _fetchConfigForMatch(int matchNum) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$serverIp/v1/rooms/get-match-config?roomName=${widget.roomName}&match=$matchNum'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _viewingMatch = matchNum;
          List<String> users = List<String>.from(data['activeUsers'] ?? []);
          _allActiveUsers = ["尚未分配", ...users];
          if (data['availableMatches'] != null) {
            _availableMatches = List<int>.from(data['availableMatches']);
          }

          final Map<String, dynamic> assignedFromServer = data['assigned'] ?? {};
          assignedFromServer.forEach((k, v) {
            if (_userControllers[k] != null) {
              String val = v.toString();
              _userControllers[k]!.text = (val.isEmpty || val == "null") ? "尚未分配" : val;
            }
          });

          final Map<String, dynamic> teams = data['teams'] ?? {};
          _teamControllers.forEach((k, v) {
            v.text = teams[k]?.toString() ?? "";
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCurrentEdit() async {
    Map<String, String> userMap = {};
    Map<String, String> teamMap = {};

    _userControllers.forEach((k, v) {
      userMap[k] = (v.text == "尚未分配") ? "" : v.text;
    });
    _teamControllers.forEach((k, v) => teamMap[k] = v.text.trim());

    try {
      await http.post(
        Uri.parse('$serverIp/v1/rooms/save-config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'matchNumber': _viewingMatch.toString(),
          'assignments': userMap,
          'teams': teamMap,
        }),
      );
    } finally {
      if (mounted) setState(() => _isAutoSaving = false);
    }
  }

  Future<void> _pushMatchToScouts() async {
    try {
      await http.post(
        Uri.parse('$serverIp/v1/rooms/set-current-match'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.roomName,
          'matchNumber': _viewingMatch.toString(),
        }),
      );
      _showDialog("發布成功", "全員已同步至 Match $_viewingMatch");
    } catch (e) {
      _showDialog("錯誤", "發布失敗");
    }
  }

  void _showUserPicker(String position) {
    int currentIndex = _allActiveUsers.indexOf(_userControllers[position]!.text);
    if (currentIndex == -1) currentIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 50,
              color: CupertinoColors.secondarySystemBackground,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text("確定"),
                    onPressed: () {
                      Navigator.pop(context);
                      _onDataChanged(); // 關閉彈窗後觸發儲存
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(initialItem: currentIndex),
                onSelectedItemChanged: (i) {
                  setState(() {
                    _userControllers[position]!.text = _allActiveUsers[i];
                  });
                  // 滾動停止時也會觸發，但搭配確定按鈕更保險
                },
                children: _allActiveUsers.map((name) => Center(child: Text(name))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMatchPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 50,
              color: CupertinoColors.secondarySystemBackground,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                      child: const Text("取消"),
                      onPressed: () => Navigator.pop(context)
                  ),
                  // 補回新增場次按鈕
                  CupertinoButton(
                      child: const Text("新增場次"),
                      onPressed: () {
                        int next = (_availableMatches.isEmpty ? 0 : _availableMatches.last) + 1;
                        setState(() {
                          if (!_availableMatches.contains(next)) {
                            _availableMatches.add(next);
                            _availableMatches.sort();
                          }
                        });
                        _fetchConfigForMatch(next); // 切換到新場次
                        Navigator.pop(context);
                      }
                  ),
                  CupertinoButton(
                      child: const Text("確定"),
                      onPressed: () => Navigator.pop(context)
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                    initialItem: _availableMatches.indexOf(_viewingMatch)
                ),
                onSelectedItemChanged: (i) => _fetchConfigForMatch(_availableMatches[i]),
                children: _availableMatches.map((m) => Text("Match $m")).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(String title, String content) {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [CupertinoDialogAction(child: const Text("確定"), onPressed: () => Navigator.pop(c))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("管理員部署"),
        trailing: _isAutoSaving
            ? const CupertinoActivityIndicator()
            : const Icon(CupertinoIcons.cloud_heavyrain_fill, size: 20, color: CupertinoColors.systemGrey),
      ),
      child: SafeArea(
        child: _isLoading ? const Center(child: CupertinoActivityIndicator()) : ListView(
          children: [
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text("查看總體數據統計"),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (c) => AllTotalPage(roomName: widget.roomName))),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              header: const Text("場次管理"),
              children: [
                CupertinoListTile(
                  title: const Text("目前編輯場次"),
                  additionalInfo: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showMatchPicker,
                    child: Text("Match $_viewingMatch ▾", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                CupertinoListTile(
                  title: const Text("同步場次", style: TextStyle(color: CupertinoColors.activeOrange)),
                  subtitle: const Text("同步才會切換場次"),
                  trailing: const Icon(CupertinoIcons.antenna_radiowaves_left_right, color: CupertinoColors.activeOrange),
                  onTap: _pushMatchToScouts,
                ),
              ],
            ),

            _buildAllianceGroup("Red Alliance", ["Red 1", "Red 2", "Red 3"], CupertinoColors.systemRed),
            _buildAllianceGroup("Blue Alliance", ["Blue 1", "Blue 2", "Blue 3"], CupertinoColors.systemBlue),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAllianceGroup(String title, List<String> positions, Color color) {
    return CupertinoListSection.insetGrouped(
      header: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      children: positions.map((pos) => CupertinoListTile(
        title: Text(pos, style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
        subtitle: CupertinoButton(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          onPressed: () => _showUserPicker(pos),
          child: Text(
            _userControllers[pos]!.text,
            style: const TextStyle(fontSize: 17, color: CupertinoColors.label),
          ),
        ),
        additionalInfo: SizedBox(
          width: 85,
          child: CupertinoTextField(
            controller: _teamControllers[pos],
            placeholder: "隊號",
            onChanged: (v) => _onDataChanged(), // 輸入變化即觸發
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            decoration: null,
          ),
        ),
      )).toList(),
    );
  }
}