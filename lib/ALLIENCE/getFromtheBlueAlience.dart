import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final Color darkBg = const Color(0xFF0F0E13);
  final Color surfaceDark = const Color(0xFF1C1B21);
  final Color accentPurple = const Color(0xFFB388FF);
  final Color accentBlue = const Color(0xFF40C4FF);

  List<dynamic> _allEvents = [];
  List<dynamic> _filteredEvents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMultiYearEvents();
  }

  Future<void> _fetchMultiYearEvents() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${Api.serverIp}/v1/tba/events/2025'), headers: {"ngrok-skip-browser-warning": "true"}),
        http.get(Uri.parse('${Api.serverIp}/v1/tba/events/2026'), headers: {"ngrok-skip-browser-warning": "true"}),
      ]).timeout(const Duration(seconds: 15));

      List<dynamic> combinedData = [];
      for (var response in results) {
        if (response.statusCode == 200) combinedData.addAll(jsonDecode(response.body));
      }

      combinedData.sort((a, b) => (b['start_date'] ?? "").compareTo(a['start_date'] ?? ""));

      if (mounted) {
        setState(() {
          _allEvents = combinedData;
          _filteredEvents = combinedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      _handleError("Connection to TBA service failed.\n$e");
    }
  }

  Future<void> _fetchMatchesAndNavigate(dynamic event) async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await http.get(
        Uri.parse('${Api.serverIp}/v1/tba/event/${event['key']}/matches'),
        headers: {"ngrok-skip-browser-warning": "true"},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        List<dynamic> matches = jsonDecode(response.body);
        matches = matches.where((m) => m['comp_level'] == 'qm').toList();
        matches.sort((a, b) => (a['match_number'] as int).compareTo(b['match_number'] as int));

        Map<String, List<String>> allMatchesData = {};
        for (var m in matches) {
          final alliances = m['alliances'];
          List<String> blue = (alliances['blue']['team_keys'] as List).map((t) => t.toString().replaceFirst('frc', '')).toList();
          List<String> red = (alliances['red']['team_keys'] as List).map((t) => t.toString().replaceFirst('frc', '')).toList();
          allMatchesData[m['match_number'].toString()] = [...blue, ...red];
        }

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateRoomPage(
                initialRoomName: "${event['year']}_${event['short_name'] ?? event['name']}",
                allMatchesData: allMatchesData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _handleError("Failed to sync match schedule: $e");
    }
  }

  void _handleError(String msg) {
    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
          title: const Text("TBA ERROR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
          content: Text(msg, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("RETRY", style: TextStyle(color: Colors.white))),
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
        return name.contains(keyword.toLowerCase()) || city.contains(keyword.toLowerCase()) || year.contains(keyword);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("SYNC EVENTS", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 14)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: "Search Year, City, or Event Name...",
              style: const TextStyle(color: Colors.white),
              onChanged: _runFilter,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CupertinoActivityIndicator(color: accentPurple, radius: 12))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) => _buildEventCard(_filteredEvents[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final bool is2026 = event['year'] == 2026;
    final Color yearColor = is2026 ? accentPurple : accentBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _fetchMatchesAndNavigate(event),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: yearColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    event['year'].toString().substring(2),
                    style: TextStyle(color: yearColor, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['short_name'] ?? event['name'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: yearColor.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          event['city'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event['key'].toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.1), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}