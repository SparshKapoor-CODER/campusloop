import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timetable_entry_screen.dart';
import 'chat_screen.dart';
import 'recommendation_engine.dart';
import 'theme.dart';

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
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.weekend, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Center(
            child: Text('No classes today.',
                style: AppTheme.mono(fontSize: 16, color: AppColors.textSecondary)),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTopCard(),
        const SizedBox(height: 12),
        if (_recommendation != null) _buildRecommendationCard(),
        const SizedBox(height: 20),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text("Today's full schedule",
                style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.bold)),
            collapsedIconColor: AppColors.textSecondary,
            iconColor: AppColors.accent,
            children: _todaySlotsWithCancelledIncluded(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopCard() {
    if (_doneForDay) {
      return AccentBarCard(
        barColor: AppColors.recHostel,
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.recHostel),
            const SizedBox(width: 12),
            Expanded(
              child: Text("You're done for the day!",
                  style: AppTheme.mono(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_inClassNow != null) {
      return AccentBarCard(
        barColor: AppColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IN CLASS RIGHT NOW',
                style: AppTheme.mono(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_inClassNow!['subject'],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${_inClassNow!['building']} • Room ${_inClassNow!['roomNumber']} • ${_inClassNow!['faculty']}',
                style: const TextStyle(color: AppColors.textSecondary)),
            Text('Until ${_inClassNow!['endTime']}', style: AppTheme.mono(fontSize: 13)),
            if (_nextSlot != null) ...[
              const Divider(height: 24),
              Text('Up next: ${_nextSlot!['subject']} at ${_nextSlot!['startTime']}',
                  style: AppTheme.mono(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
        ),
      );
    }

    if (_nextSlot != null) {
      return AccentBarCard(
        barColor: AppColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NEXT CLASS',
                style: AppTheme.mono(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_nextSlot!['subject'],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${_nextSlot!['building']} • Room ${_nextSlot!['roomNumber']} • ${_nextSlot!['faculty']}',
                style: const TextStyle(color: AppColors.textSecondary)),
            Text('Starts at ${_nextSlot!['startTime']}', style: AppTheme.mono(fontSize: 13)),
          ],
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
        color = AppColors.recHostel;
        icon = Icons.home_rounded;
        break;
      case 'canteen':
        color = AppColors.recCanteen;
        icon = Icons.restaurant_rounded;
        break;
      case 'at_hostel':
        color = AppColors.recInfo;
        icon = Icons.info_rounded;
        break;
      default:
        color = AppColors.recStay;
        icon = Icons.timer_rounded;
    }

    return AccentBarCard(
      barColor: color,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(rec.message)),
        ],
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
          style: isCancelled
              ? const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textSecondary)
              : null,
        ),
        subtitle: Text('${slot['building']} • Room ${slot['roomNumber']} • ${slot['faculty']}',
            style: const TextStyle(color: AppColors.textSecondary)),
        trailing: Switch(
          value: !isCancelled,
          onChanged: (val) => _toggleCancelled(code, !val),
        ),
      );
    }).toList();
  }
}