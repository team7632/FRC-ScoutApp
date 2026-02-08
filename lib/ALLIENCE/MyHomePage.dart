import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'CreateRoomPage.dart';
import 'RoomListPage.dart';
import 'People.dart'; // 記得導入註冊頁面，以便登出後跳轉

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _currentUserName = "載入中...";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserName = prefs.getString('username') ?? "Scout";
    });
  }

  // --- 登出功能邏輯 ---
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();

    // 顯示確認對話框
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("登出"),
        content: const Text("確定要登出並清除資料嗎？"),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true, // 顯示紅色字體表示破壞性操作
            child: const Text("確定"),
            onPressed: () async {
              await prefs.clear(); // 清除所有儲存的資料 (包括 username)
              if (mounted) {
                // 跳轉回註冊頁，並清空之前的頁面路徑
                Navigator.of(context).pushAndRemoveUntil(
                  CupertinoPageRoute(builder: (context) => const People()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Room Dashboard'),
        backgroundColor: CupertinoColors.activeBlue,
        // 在右上角加入登出按鈕
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _handleLogout,
          child: const Icon(CupertinoIcons.square_arrow_right, color: CupertinoColors.quaternaryLabel),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Hi, $_currentUserName",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "歡迎回來！",
              style: TextStyle(color: CupertinoColors.systemGrey),
            ),
            const SizedBox(height: 30),
            const Icon(CupertinoIcons.square_stack_3d_up_fill,
                size: 80, color: CupertinoColors.systemGrey),
            const SizedBox(height: 40),
            CupertinoButton.filled(
              onPressed: () => Navigator.push(
                  context, CupertinoPageRoute(builder: (context) => const CreateRoomPage())
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.add),
                  Text(' Create Room via API'),
                ],
              ),
            ),
            const SizedBox(height: 15),
            CupertinoButton(
              color: CupertinoColors.activeGreen,
              onPressed: () => Navigator.push(
                  context, CupertinoPageRoute(builder: (context) => const RoomListPage())
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.list_bullet),
                  Text(' View Rooms from Server'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}