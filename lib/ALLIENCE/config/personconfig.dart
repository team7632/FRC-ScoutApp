import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart'; // 確保路徑正確

class PersonConfigPage extends StatefulWidget {
  const PersonConfigPage({super.key});

  @override
  State<PersonConfigPage> createState() => _PersonConfigPageState();
}

class _PersonConfigPageState extends State<PersonConfigPage> {
  final TextEditingController _ipController = TextEditingController();

  // 定義你的主紫色
  final Color primaryPurple = CupertinoColors.systemPurple;

  @override
  void initState() {
    super.initState();
    _ipController.text = Api.serverIp;
  }

  Future<void> _saveIp(String newIp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_ip', newIp);
    Api.serverIp = newIp;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("設定成功", style: TextStyle(color: primaryPurple)),
        content: Text("伺服器位置已更改為：\n$newIp"),
        actions: [
          CupertinoDialogAction(
            child: Text("確定", style: TextStyle(color: primaryPurple)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // 背景稍微帶一點淺紫灰色會更有質感
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
        middle: const Text("個人設置", style: TextStyle(color: CupertinoColors.label)),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: Text("伺服器連線設定", style: TextStyle(color: CupertinoColors.systemBlue)),
              footer: const Text("修改 IP 後將立即生效，若連線失敗請檢查網路環境。"),
              children: [
                CupertinoListTile(
                  leading: Icon(CupertinoIcons.link, color: primaryPurple),
                  title: const Text("Server IP"),
                  additionalInfo: SizedBox(
                    width: 200,
                    child: CupertinoTextField(
                      controller: _ipController,
                      placeholder: "輸入 IP 或 URL",
                      placeholderStyle: const TextStyle(color: CupertinoColors.placeholderText),
                      cursorColor: CupertinoColors.systemBlue, // 游標顏色
                      decoration: null,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: CupertinoColors.systemBlue, fontWeight: FontWeight.bold),
                      onSubmitted: (value) => _saveIp(value),
                    ),
                  ),
                ),

                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.refresh_thick, color: CupertinoColors.systemGrey),
                  title: const Text("還原預設 IP", style: TextStyle(color: CupertinoColors.systemGrey)),
                  onTap: () {
                    setState(() {
                      _ipController.text = Api.defaultIp;
                    });
                    _saveIp(Api.defaultIp);
                  },
                ),
              ],
            ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: primaryPurple, // 這是你的 CupertinoColors.systemPurple
            borderRadius: BorderRadius.circular(15),
            // 關鍵修改：加入 color: CupertinoColors.white
            child: const Text(
              "儲存變更",
              style: TextStyle(
                color: CupertinoColors.white, // 👈 字體變白色
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            onPressed: () => _saveIp(_ipController.text),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}