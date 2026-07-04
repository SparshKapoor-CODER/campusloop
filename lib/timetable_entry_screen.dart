import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'slot_data.dart';
import 'campus_data.dart';
import 'theme.dart';

class SubjectGroup {
  final String subject;
  final String faculty;
  final String building;
  final String room;
  final List<String> slotCodes;

  SubjectGroup({
    required this.subject,
    required this.faculty,
    required this.building,
    required this.room,
    required this.slotCodes,
  });

  String get groupKey => '$subject|$faculty|$building|$room';
}

class TimetableEntryScreen extends StatefulWidget {
  const TimetableEntryScreen({super.key});

  @override
  State<TimetableEntryScreen> createState() => _TimetableEntryScreenState();
}

class _TimetableEntryScreenState extends State<TimetableEntryScreen> {
  Map<String, Map<String, dynamic>> _filledSlots = {}; // slotCode -> data
  bool _loading = true;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('students')
        .doc(_uid)
        .collection('timetable')
        .get();

    final map = <String, Map<String, dynamic>>{};
    for (final doc in snapshot.docs) {
      map[doc.id] = doc.data();
    }

    setState(() {
      _filledSlots = map;
      _loading = false;
    });
  }

  List<SubjectGroup> _buildSubjectGroups() {
    final groups = <String, SubjectGroup>{};
    for (final entry in _filledSlots.entries) {
      final data = entry.value;
      final key = '${data['subject']}|${data['faculty']}|${data['building']}|${data['roomNumber']}';
      if (groups.containsKey(key)) {
        groups[key]!.slotCodes.add(entry.key);
      } else {
        groups[key] = SubjectGroup(
          subject: data['subject'],
          faculty: data['faculty'],
          building: data['building'],
          room: data['roomNumber'],
          slotCodes: [entry.key],
        );
      }
    }
    final list = groups.values.toList();
    list.sort((a, b) => a.subject.compareTo(b.subject));
    return list;
  }

  // ---------- Add Subject flow (new subject, subject/faculty/building/room once, then pick slots) ----------
  Future<void> _openAddSubjectForm({String? preSelectedSlotCode}) async {
    final subjectController = TextEditingController();
    final facultyController = TextEditingController();
    final roomController = TextEditingController();
    String? building;
    final Set<String> selectedSlotCodes = {};
    if (preSelectedSlotCode != null) {
      selectedSlotCodes.add(preSelectedSlotCode);
    }

    final freeSlots = allSlots.where((s) => !_filledSlots.containsKey(s.code)).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Add Subject', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: facultyController,
                      decoration: const InputDecoration(labelText: 'Faculty'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: building,
                      dropdownColor: AppColors.surfaceHigh,
                      decoration: const InputDecoration(labelText: 'Building'),
                      items: academicBuildings
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setModalState(() => building = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roomController,
                      decoration: const InputDecoration(labelText: 'Room Number'),
                    ),
                    const SizedBox(height: 16),
                    Text('Add Slots', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'Only free slots are shown — slots already occupied by other subjects are hidden.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: freeSlots.isEmpty
                          ? const Center(child: Text('No free slots left.'))
                          : ListView(
                              children: [
                                for (final day in weekDays)
                                  if (freeSlots.any((s) => s.day == day)) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0, bottom: 2),
                                      child: Text(day,
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    for (final slot in freeSlots.where((s) => s.day == day))
                                      CheckboxListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text('${slot.code}  (${slot.startTime}-${slot.endTime})'),
                                        value: selectedSlotCodes.contains(slot.code),
                                        onChanged: (checked) {
                                          setModalState(() {
                                            if (checked == true) {
                                              selectedSlotCodes.add(slot.code);
                                            } else {
                                              selectedSlotCodes.remove(slot.code);
                                            }
                                          });
                                        },
                                      ),
                                  ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (subjectController.text.trim().isEmpty ||
                              facultyController.text.trim().isEmpty ||
                              building == null ||
                              roomController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Fill all fields')));
                            return;
                          }
                          if (selectedSlotCodes.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Select at least one slot')));
                            return;
                          }
                          await _saveSlots(
                            selectedSlotCodes,
                            subjectController.text.trim(),
                            facultyController.text.trim(),
                            building!,
                            roomController.text.trim(),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveSlots(Set<String> slotCodes, String subject, String faculty,
      String building, String room) async {
    final batch = FirebaseFirestore.instance.batch();
    final collectionRef =
        FirebaseFirestore.instance.collection('students').doc(_uid).collection('timetable');

    final Map<String, Map<String, dynamic>> newData = {};
    for (final code in slotCodes) {
      final slot = allSlots.firstWhere((s) => s.code == code);
      final data = {
        'slotCode': slot.code,
        'day': slot.day,
        'startTime': slot.startTime,
        'endTime': slot.endTime,
        'subject': subject,
        'faculty': faculty,
        'building': building,
        'roomNumber': room,
      };
      batch.set(collectionRef.doc(slot.code), data);
      newData[slot.code] = data;
    }
    await batch.commit();
    setState(() => _filledSlots.addAll(newData));
  }

  Future<void> _deleteSlots(List<String> slotCodes) async {
    final batch = FirebaseFirestore.instance.batch();
    final collectionRef =
        FirebaseFirestore.instance.collection('students').doc(_uid).collection('timetable');
    for (final code in slotCodes) {
      batch.delete(collectionRef.doc(code));
    }
    await batch.commit();
    setState(() {
      for (final code in slotCodes) {
        _filledSlots.remove(code);
      }
    });
  }

  // ---------- Edit an existing subject group ----------
  Future<void> _openEditSubjectGroup(SubjectGroup group) async {
    final subjectController = TextEditingController(text: group.subject);
    final facultyController = TextEditingController(text: group.faculty);
    final roomController = TextEditingController(text: group.room);
    String? building = group.building;
    final Set<String> selectedSlotCodes = {...group.slotCodes};

    // Selectable slots = this group's own slots (already occupied by IT) + any free slots.
    final selectableSlots = allSlots
        .where((s) => !_filledSlots.containsKey(s.code) || group.slotCodes.contains(s.code))
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Edit Subject', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: facultyController,
                      decoration: const InputDecoration(labelText: 'Faculty'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: building,
                      dropdownColor: AppColors.surfaceHigh,
                      decoration: const InputDecoration(labelText: 'Building'),
                      items: academicBuildings
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setModalState(() => building = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roomController,
                      decoration: const InputDecoration(labelText: 'Room Number'),
                    ),
                    const SizedBox(height: 16),
                    Text('Slots', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'Check or uncheck slots for this subject. Slots occupied by other subjects are hidden.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final day in weekDays)
                            if (selectableSlots.any((s) => s.day == day)) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, bottom: 2),
                                child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              for (final slot in selectableSlots.where((s) => s.day == day))
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${slot.code}  (${slot.startTime}-${slot.endTime})'),
                                  value: selectedSlotCodes.contains(slot.code),
                                  onChanged: (checked) {
                                    setModalState(() {
                                      if (checked == true) {
                                        selectedSlotCodes.add(slot.code);
                                      } else {
                                        selectedSlotCodes.remove(slot.code);
                                      }
                                    });
                                  },
                                ),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete subject?'),
                                content: Text(
                                    'This removes "${group.subject}" from all ${group.slotCodes.length} slot(s). This cannot be undone.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _deleteSlots(group.slotCodes);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          child: const Text('Delete Subject', style: TextStyle(color: Colors.red)),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            if (subjectController.text.trim().isEmpty ||
                                facultyController.text.trim().isEmpty ||
                                building == null ||
                                roomController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('Fill all fields')));
                              return;
                            }
                            if (selectedSlotCodes.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Select at least one slot')));
                              return;
                            }
                            // Slots removed from this group -> delete.
                            final removed =
                                group.slotCodes.where((c) => !selectedSlotCodes.contains(c)).toList();
                            if (removed.isNotEmpty) {
                              await _deleteSlots(removed);
                            }
                            // Remaining + newly added slots -> write with updated details.
                            await _saveSlots(
                              selectedSlotCodes,
                              subjectController.text.trim(),
                              facultyController.text.trim(),
                              building!,
                              roomController.text.trim(),
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------- View Subjects screen ----------
  Future<void> _openViewSubjects() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ViewSubjectsScreen(
          groups: _buildSubjectGroups(),
          onTapGroup: _openEditSubjectGroup,
          onDeleteAll: _deleteEntireTimetable,
        ),
      ),
    );
    // Refresh in case something changed while the sub-screen was open.
    await _loadTimetable();
  }

  Future<void> _deleteEntireTimetable() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('students')
        .doc(_uid)
        .collection('timetable')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    setState(() => _filledSlots = {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Subjects',
            onPressed: _openViewSubjects,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSubjectForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(110),
            border: TableBorder.all(color: AppColors.divider),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppColors.surfaceHigh),
                children: [
                  const _HeaderCell('Day'),
                  for (int col = 1; col <= 7; col++) _HeaderCell(_timeLabelForColumn(col)),
                ],
              ),
              for (final day in weekDays)
                TableRow(
                  children: [
                    _HeaderCell(day),
                    for (int col = 1; col <= 7; col++) _buildCell(day, col),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabelForColumn(int col) {
    final slot = allSlots.firstWhere((s) => s.columnIndex == col);
    return '${slot.startTime}\n${slot.endTime}';
  }

  Widget _buildCell(String day, int col) {
    final slot = allSlots.firstWhere((s) => s.day == day && s.columnIndex == col);
    final filled = _filledSlots[slot.code];

    return InkWell(
      onTap: () {
        if (filled != null) {
          final groups = _buildSubjectGroups();
          final group = groups.firstWhere((g) => g.slotCodes.contains(slot.code));
          _openEditSubjectGroup(group);
        } else {
          _openAddSubjectForm(preSelectedSlotCode: slot.code);
        }
      },
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(4),
        color: filled != null ? AppColors.accent.withValues(alpha: 0.18) : null,
        child: filled != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(filled['subject'] ?? '',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(filled['building'] ?? '',
                      style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
                ],
              )
            : Center(
                child: Text(slot.code, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _ViewSubjectsScreen extends StatelessWidget {
  final List<SubjectGroup> groups;
  final Future<void> Function(SubjectGroup) onTapGroup;
  final Future<void> Function() onDeleteAll;

  const _ViewSubjectsScreen({
    required this.groups,
    required this.onTapGroup,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Subjects')),
      body: groups.isEmpty
          ? const Center(child: Text('No subjects added yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final g = groups[index];
                final slotSummary = g.slotCodes.join(', ');
                return AccentBarCard(
                  barColor: AppColors.accent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(g.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${g.faculty} • ${g.building} • Room ${g.room}\nSlots: $slotSummary',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await onTapGroup(g);
                      // Data may have changed (edited/deleted) — pop back to the
                      // grid so it reloads fresh, rather than showing stale info here.
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete entire timetable?'),
                        content: const Text(
                            'This removes every subject and slot from your timetable. This cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes, Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await onDeleteAll();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Delete Entire Timetable', style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
    );
  }
}