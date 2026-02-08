import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'CreateRoomPage.dart';
import 'RoomListPage.dart';
import 'People.dart';

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

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();

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
            isDestructiveAction: true,
            child: const Text("確定"),
            onPressed: () async {
              await prefs.clear();
              if (mounted) {
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
      backgroundColor: CupertinoColors.secondaryLabel,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Room Dashboard'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _handleLogout,
          child: const Icon(CupertinoIcons.square_arrow_right),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Hi, $_currentUserName",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeBlue,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "歡迎回來！",
                style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 16),
              ),
              const SizedBox(height: 40),
              const Icon(
                CupertinoIcons.square_stack_3d_up_fill,
                size: 100,
                color: CupertinoColors.systemGrey3,
              ),
              const SizedBox(height: 50),

              // 建立房間按鈕
              SizedBox(
                width: double.infinity, // 讓按鈕撐滿寬度
                child: CupertinoButton.filled(
                  color: CupertinoColors.systemPurple,
                  onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const CreateRoomPage()),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.add),
                      SizedBox(width: 8),
                      Text('Create Room via API'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // 查看房間清單按鈕
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemPurple.withOpacity(0.1),
                  onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const RoomListPage()),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.list_bullet, color: CupertinoColors.systemPurple),
                      SizedBox(width: 8),
                      Text(
                        'View Rooms from Server',
                        style: TextStyle(color: CupertinoColors.systemPurple),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}