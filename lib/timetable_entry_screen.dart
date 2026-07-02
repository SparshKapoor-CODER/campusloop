import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'slot_data.dart';
import 'campus_data.dart';

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

  // ---------- Add Subject flow (subject/faculty/building/room once, then pick slots) ----------
  Future<void> _openAddSubjectForm({String? preSelectedSlotCode}) async {
    final subjectController = TextEditingController();
    final facultyController = TextEditingController();
    final roomController = TextEditingController();
    String? building;
    final Set<String> selectedSlotCodes = {};
    if (preSelectedSlotCode != null) {
      selectedSlotCodes.add(preSelectedSlotCode);
    }

    // Only free (unoccupied) slots are selectable.
    final freeSlots =
        allSlots.where((s) => !_filledSlots.containsKey(s.code)).toList();

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
                    Text('Add Subject',
                        style: Theme.of(context).textTheme.titleMedium),
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
                      decoration: const InputDecoration(labelText: 'Building'),
                      items: academicBuildings
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setModalState(() => building = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roomController,
                      decoration:
                          const InputDecoration(labelText: 'Room Number'),
                    ),
                    const SizedBox(height: 16),
                    Text('Add Slots',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Only free slots are shown — slots already occupied by other subjects are hidden.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                                      padding:
                                          const EdgeInsets.only(top: 8.0, bottom: 2),
                                      child: Text(day,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    for (final slot in freeSlots
                                        .where((s) => s.day == day))
                                      CheckboxListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                            '${slot.code}  (${slot.startTime}-${slot.endTime})'),
                                        value: selectedSlotCodes
                                            .contains(slot.code),
                                        onChanged: (checked) {
                                          setModalState(() {
                                            if (checked == true) {
                                              selectedSlotCodes.add(slot.code);
                                            } else {
                                              selectedSlotCodes
                                                  .remove(slot.code);
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fill all fields')),
                            );
                            return;
                          }
                          if (selectedSlotCodes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Select at least one slot')),
                            );
                            return;
                          }
                          await _saveSubjectToSlots(
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

  Future<void> _saveSubjectToSlots(Set<String> slotCodes, String subject,
      String faculty, String building, String room) async {
    final batch = FirebaseFirestore.instance.batch();
    final collectionRef = FirebaseFirestore.instance
        .collection('students')
        .doc(_uid)
        .collection('timetable');

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

  // ---------- View / delete a filled slot ----------
  Future<void> _openFilledSlotDetails(TimeSlot slot) async {
    final data = _filledSlots[slot.code]!;

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${slot.code} — ${slot.day} ${slot.startTime}-${slot.endTime}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('Subject: ${data['subject']}'),
              Text('Faculty: ${data['faculty']}'),
              Text('Building: ${data['building']}'),
              Text('Room: ${data['roomNumber']}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await _deleteSlot(slot.code);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteSlot(String slotCode) async {
    await FirebaseFirestore.instance
        .collection('students')
        .doc(_uid)
        .collection('timetable')
        .doc(slotCode)
        .delete();

    setState(() => _filledSlots.remove(slotCode));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Timetable')),
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
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.deepPurple.shade50),
                children: [
                  const _HeaderCell('Day'),
                  for (int col = 1; col <= 7; col++)
                    _HeaderCell(_timeLabelForColumn(col)),
                ],
              ),
              for (final day in weekDays)
                TableRow(
                  children: [
                    _HeaderCell(day),
                    for (int col = 1; col <= 7; col++)
                      _buildCell(day, col),
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
          _openFilledSlotDetails(slot);
        } else {
          _openAddSubjectForm(preSelectedSlotCode: slot.code);
        }
      },
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(4),
        color: filled != null ? Colors.deepPurple.shade100 : null,
        child: filled != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(filled['subject'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(filled['building'] ?? '',
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center),
                ],
              )
            : Center(
                child: Text(slot.code,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
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