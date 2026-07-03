import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timetable_entry_screen.dart';
import 'chat_screen.dart';
import 'recommendation_engine.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  String? _hostelId;
  List<Map<String, dynamic>> _todaySlots = []; // sorted, non-cancelled
  List<Map<String, dynamic>> _allTodaySlots = []; // sorted, includes cancelled
  Set<String> _cancelledCodes = {};
  Map<String, dynamic>? _inClassNow;
  Map<String, dynamic>? _nextSlot;
  Map<String, dynamic>? _previousSlot;
  GapRecommendation? _recommendation;
  bool _doneForDay = false;
  bool _noClassesToday = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  String _locId(String name) => name.replaceAll(' ', '_');

  DateTime _todayAt(String hhmm) {
    final now = DateTime.now();
    final parts = hhmm.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadEverything() async {
    setState(() {
      _loading = true;
      _error = null;
      _noClassesToday = false;
    });

    try {
      final now = DateTime.now();
      final weekdayIndex = now.weekday; // Mon=1 .. Sun=7

      if (weekdayIndex == 7) {
        setState(() {
          _noClassesToday = true;
          _loading = false;
        });
        return;
      }

      final dayName = _weekDays[weekdayIndex - 1];

      // ---- student profile ----
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(_uid)
          .get();
      final hostelBlock = studentDoc.data()?['hostelBlock'] as String?;
      final hostelId = hostelBlock != null ? _locId(hostelBlock) : null;

      // ---- today's cancellations ----
      final cancelDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(_uid)
          .collection('cancellations')
          .doc(_dateKey(now))
          .get();
      final cancelledCodes = <String>{
        ...?((cancelDoc.data()?['slotCodes'] as List?)?.cast<String>())
      };

      // ---- today's timetable ----
      final timetableSnap = await FirebaseFirestore.instance
          .collection('students')
          .doc(_uid)
          .collection('timetable')
          .where('day', isEqualTo: dayName)
          .get();

      final allTodaySlots = timetableSnap.docs.map((d) => d.data()).toList()
        ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));

      final todaySlots = allTodaySlots
          .where((s) => !cancelledCodes.contains(s['slotCode']))
          .toList();

      if (allTodaySlots.isEmpty) {
        setState(() {
          _hostelId = hostelId;
          _cancelledCodes = cancelledCodes;
          _allTodaySlots = allTodaySlots;
          _noClassesToday = true;
          _loading = false;
        });
        return;
      }

      // ---- figure out current position in the day ----
      Map<String, dynamic>? inClassNow;
      Map<String, dynamic>? nextSlot;
      Map<String, dynamic>? previousSlot;

      for (final slot in todaySlots) {
        final start = _todayAt(slot['startTime']);
        final end = _todayAt(slot['endTime']);
        if (!now.isBefore(start) && now.isBefore(end)) {
          inClassNow = slot;
          break;
        }
      }

      if (inClassNow == null) {
        for (final slot in todaySlots) {
          final start = _todayAt(slot['startTime']);
          if (start.isAfter(now)) {
            nextSlot = slot;
            break;
          }
        }
        if (nextSlot != null) {
          for (final slot in todaySlots) {
            final end = _todayAt(slot['endTime']);
            if (!end.isAfter(now)) {
              previousSlot = slot; // keeps getting overwritten -> ends up as the last one before now
            }
          }
        }
      } else {
        // find the slot after the one happening now, for "up next" info
        final idx = todaySlots.indexOf(inClassNow);
        if (idx + 1 < todaySlots.length) {
          nextSlot = todaySlots[idx + 1];
        }
      }

      bool doneForDay = false;
      GapRecommendation? recommendation;

      if (inClassNow == null && nextSlot == null) {
        doneForDay = true;
      } else if (inClassNow == null && nextSlot != null) {
        final gapMinutes = _todayAt(nextSlot['startTime']).difference(now).inMinutes;
        final currentLocationId =
            previousSlot != null ? _locId(previousSlot['building']) : (hostelId ?? '');
        final nextLocationId = _locId(nextSlot['building']);

        // ---- mess timings + canteen ids (only needed if we might recommend) ----
        final messDoc = await FirebaseFirestore.instance
            .collection('messTimings')
            .doc('default')
            .get();
        final mess = messDoc.data() ?? {};

        bool overlaps(String? startStr, String? endStr) {
          if (startStr == null || endStr == null) return false;
          final mStart = _todayAt(startStr);
          final mEnd = _todayAt(endStr);
          final gapEnd = _todayAt(nextSlot!['startTime']);
          return mStart.isBefore(gapEnd) && mEnd.isAfter(now);
        }

        final messActive = overlaps(mess['breakfastStart'], mess['breakfastEnd']) ||
            overlaps(mess['lunchStart'], mess['lunchEnd']) ||
            overlaps(mess['eveningsnacksStart'], mess['eveningsnacksEnd']) ||
            overlaps(mess['dinnerStart'], mess['dinnerEnd']);

        final canteenSnap = await FirebaseFirestore.instance
            .collection('campusLocations')
            .where('type', isEqualTo: 'canteen')
            .get();
        final canteenIds = canteenSnap.docs.map((d) => d.id).toList();

        // ---- fetch only the distanceMatrix docs we actually need ----
        final neededIds = <String>{
          currentLocationId,
          if (hostelId != null) hostelId,
          nextLocationId,
          ...canteenIds,
        }..removeWhere((e) => e.isEmpty);

        final distanceMatrix = <String, Map<String, dynamic>>{};
        for (final id in neededIds) {
          final doc = await FirebaseFirestore.instance
              .collection('distanceMatrix')
              .doc(id)
              .get();
          if (doc.exists) distanceMatrix[id] = doc.data()!;
        }

        if (hostelId != null && currentLocationId.isNotEmpty) {
          recommendation = computeRecommendation(
            currentLocationId: currentLocationId,
            nextLocationId: nextLocationId,
            gapMinutes: gapMinutes,
            hostelId: hostelId,
            canteenIds: canteenIds,
            distanceMatrix: distanceMatrix,
            messWindowActiveDuringGap: messActive,
          );
        }
      }

      setState(() {
        _hostelId = hostelId;
        _todaySlots = todaySlots;
        _allTodaySlots = allTodaySlots;
        _cancelledCodes = cancelledCodes;
        _inClassNow = inClassNow;
        _nextSlot = nextSlot;
        _previousSlot = previousSlot;
        _recommendation = recommendation;
        _doneForDay = doneForDay;
        _noClassesToday = false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleCancelled(String slotCode, bool cancel) async {
    final ref = FirebaseFirestore.instance
        .collection('students')
        .doc(_uid)
        .collection('cancellations')
        .doc(_dateKey(DateTime.now()));

    if (cancel) {
      await ref.set({
        'slotCodes': FieldValue.arrayUnion([slotCode])
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'slotCodes': FieldValue.arrayRemove([slotCode])
      }, SetOptions(merge: true));
    }
    await _loadEverything();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusLoop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Ask CampusLoop',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'My Timetable',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TimetableEntryScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEverything,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(20), child: Text('Error: $_error'))])
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_noClassesToday) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.weekend, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('No classes today.', style: TextStyle(fontSize: 16))),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTopCard(),
        const SizedBox(height: 16),
        if (_recommendation != null) _buildRecommendationCard(),
        const SizedBox(height: 20),
        ExpansionTile(
          title: const Text("Today's full schedule"),
          children: _todaySlotsWithCancelledIncluded(),
        ),
      ],
    );
  }

  Widget _buildTopCard() {
    if (_doneForDay) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Expanded(child: Text("You're done for the day!")),
            ],
          ),
        ),
      );
    }

    if (_inClassNow != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('In class right now', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_inClassNow!['subject'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${_inClassNow!['building']} • Room ${_inClassNow!['roomNumber']} • ${_inClassNow!['faculty']}'),
              Text('Until ${_inClassNow!['endTime']}'),
              if (_nextSlot != null) ...[
                const Divider(height: 24),
                Text('Up next: ${_nextSlot!['subject']} at ${_nextSlot!['startTime']}'),
              ],
            ],
          ),
        ),
      );
    }

    if (_nextSlot != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Next class', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_nextSlot!['subject'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${_nextSlot!['building']} • Room ${_nextSlot!['roomNumber']} • ${_nextSlot!['faculty']}'),
              Text('Starts at ${_nextSlot!['startTime']}'),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRecommendationCard() {
    final rec = _recommendation!;
    Color color;
    IconData icon;
    switch (rec.type) {
      case 'hostel':
        color = Colors.green.shade100;
        icon = Icons.home;
        break;
      case 'canteen':
        color = Colors.orange.shade100;
        icon = Icons.restaurant;
        break;
      case 'at_hostel':
        color = Colors.blue.shade100;
        icon = Icons.info;
        break;
      default:
        color = Colors.grey.shade200;
        icon = Icons.timer;
    }

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(rec.message)),
          ],
        ),
      ),
    );
  }

  List<Widget> _todaySlotsWithCancelledIncluded() {
    return _allTodaySlots.map((slot) {
      final code = slot['slotCode'];
      final isCancelled = _cancelledCodes.contains(code);
      return ListTile(
        title: Text(
          '${slot['subject']}  (${slot['startTime']}-${slot['endTime']})',
          style: isCancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: Text('${slot['building']} • Room ${slot['roomNumber']} • ${slot['faculty']}'),
        trailing: Switch(
          value: !isCancelled,
          onChanged: (val) => _toggleCancelled(code, !val),
        ),
      );
    }).toList();
  }
}