import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'api.dart';
import 'CreateRoomPage.dart';

class GetFromTheBlueAlliance extends StatefulWidget {
  const GetFromTheBlueAlliance({super.key});

  @override
  State<GetFromTheBlueAlliance> createState() => _GetFromTheBlueAllianceState();
}

class _GetFromTheBlueAllianceState extends State<GetFromTheBlueAlliance> {
  List<dynamic> _allEvents = [];
  List<dynamic> _filteredEvents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMultiYearEvents();
  }

  // Fetch events for both 2025 and 2026
  Future<void> _fetchMultiYearEvents() async {
    setState(() => _isLoading = true);

    try {
      // Send both requests simultaneously
      final results = await Future.wait([
        http.get(Uri.parse('${Api.serverIp}/v1/tba/events/2025')),
        http.get(Uri.parse('${Api.serverIp}/v1/tba/events/2026')),
      ]).timeout(const Duration(seconds: 15));

      List<dynamic> combinedData = [];

      for (var response in results) {
        if (response.statusCode == 200) {
          combinedData.addAll(jsonDecode(response.body));
        } else {
          debugPrint("Failed to fetch year: ${response.statusCode}");
        }
      }

      if (combinedData.isEmpty) throw "Could not retrieve event data";

      // Global sort: Descending by date (latest first)
      combinedData.sort((a, b) => (b['start_date'] ?? "").compareTo(a['start_date'] ?? ""));

      if (mounted) {
        setState(() {
          _allEvents = combinedData;
          _filteredEvents = combinedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      _handleError("Could not connect to server.\nPlease ensure the backend service is running on the same network.\n$e");
    }
  }

  Future<void> _fetchMatchesAndNavigate(dynamic event) async {
    setState(() => _isLoading = true);
    final eventKey = event['key'];

    try {
      final response = await http.get(
        Uri.parse('${Api.serverIp}/v1/tba/event/$eventKey/matches'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        List<dynamic> matches = jsonDecode(response.body);

        // Filter for Qualification Matches (qm) only
        matches = matches.where((m) => m['comp_level'] == 'qm').toList();
        matches.sort((a, b) => (a['match_number'] as int).compareTo(b['match_number'] as int));

        Map<String, List<String>> allMatchesData = {};
        for (var m in matches) {
          final matchNum = m['match_number'].toString();
          final alliances = m['alliances'];
          // Format team keys (remove 'frc' prefix)
          List<String> blue = (alliances['blue']['team_keys'] as List).map((t) => t.toString().replaceFirst('frc', '')).toList();
          List<String> red = (alliances['red']['team_keys'] as List).map((t) => t.toString().replaceFirst('frc', '')).toList();

          // Order: Blue 1, 2, 3, Red 1, 2, 3
          allMatchesData[matchNum] = [...blue, ...red];
        }

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => CreateRoomPage(
                initialRoomName: "${event['year']}_${event['short_name'] ?? event['name']}",
                allMatchesData: allMatchesData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _handleError("Failed to fetch match schedule: $e");
    }
  }

  void _handleError(String msg) {
    if (mounted) {
      setState(() => _isLoading = false);
      showCupertinoDialog(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: Text(msg),
          actions: [
            CupertinoDialogAction(
              child: const Text("Retry"),
              onPressed: () {
                Navigator.pop(c);
                _fetchMultiYearEvents();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(c),
            ),
          ],
        ),
      );
    }
  }

  void _runFilter(String keyword) {
    setState(() {
      _filteredEvents = _allEvents.where((event) {
        final name = (event['name'] ?? "").toLowerCase();
        final city = (event['city'] ?? "").toLowerCase();
        final year = event['year'].toString();
        return name.contains(keyword.toLowerCase()) ||
            city.contains(keyword.toLowerCase()) ||
            year.contains(keyword);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Import TBA Events (2025-2026)"),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: "Search Name, City, or Year",
                onChanged: _runFilter,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 15))
                  : _filteredEvents.isEmpty
                  ? const Center(child: Text("No matching events found"))
                  : CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: _fetchMultiYearEvents,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildEventCard(_filteredEvents[index]),
                        childCount: _filteredEvents.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final is2026 = event['year'] == 2026;
    final themeColor = is2026 ? CupertinoColors.systemPurple : CupertinoColors.activeBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.all(16),
        onPressed: () => _fetchMatchesAndNavigate(event),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(CupertinoIcons.calendar, color: themeColor.withOpacity(0.2), size: 40),
                Text(
                  event['year'].toString().substring(2),
                  style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['short_name'] ?? event['name'],
                    style: const TextStyle(color: CupertinoColors.label, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event['year'].toString(),
                          style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event['city'] ?? 'Unknown Location',
                        style: const TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.systemGrey4, size: 18),
          ],
        ),
      ),
    );
  }
}