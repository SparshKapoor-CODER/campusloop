import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'groq_config.dart';

class GroqService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static const List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Gathers today's schedule, hostel, mess timings, and walking distances
  /// into a compact text block the model can reason over. Only real data
  /// goes in here — the model is instructed not to invent anything beyond it.
  static Future<String> _buildContext() async {
    final now = DateTime.now();
    final buffer = StringBuffer();

    buffer.writeln('Current time: ${_formatTime(now)}');

    final weekdayIndex = now.weekday; // Mon=1..Sun=7
    if (weekdayIndex == 7) {
      buffer.writeln('Today is Sunday — no classes.');
      return buffer.toString();
    }

    final dayName = _weekDays[weekdayIndex - 1];
    buffer.writeln('Today is $dayName.');

    final studentDoc =
        await FirebaseFirestore.instance.collection('students').doc(_uid).get();
    final studentData = studentDoc.data() ?? {};
    final hostelBlock = studentData['hostelBlock'] as String?;
    buffer.writeln('Student hostel: ${hostelBlock ?? 'unknown'}');

    final cancelDoc = await FirebaseFirestore.instance
        .collection('students')
        .doc(_uid)
        .collection('cancellations')
        .doc(_dateKey(now))
        .get();
    final cancelledCodes = <String>{
      ...?((cancelDoc.data()?['slotCodes'] as List?)?.cast<String>())
    };

    final timetableSnap = await FirebaseFirestore.instance
        .collection('students')
        .doc(_uid)
        .collection('timetable')
        .where('day', isEqualTo: dayName)
        .get();

    final slots = timetableSnap.docs.map((d) => d.data()).toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));

    if (slots.isEmpty) {
      buffer.writeln('No classes scheduled today.');
    } else {
      buffer.writeln("Today's schedule:");
      for (final s in slots) {
        final cancelled =
            cancelledCodes.contains(s['slotCode']) ? ' [CANCELLED]' : '';
        buffer.writeln(
            '- ${s['startTime']}-${s['endTime']}: ${s['subject']} with ${s['faculty']} at ${s['building']} room ${s['roomNumber']}$cancelled');
      }
    }

    final messDoc = await FirebaseFirestore.instance
        .collection('messTimings')
        .doc('default')
        .get();
    final mess = messDoc.data() ?? {};
    buffer.writeln('Hostel mess timings:');
    buffer.writeln('- Breakfast: ${mess['breakfastStart']}-${mess['breakfastEnd']}');
    buffer.writeln('- Lunch: ${mess['lunchStart']}-${mess['lunchEnd']}');
    buffer.writeln(
        '- Evening Snacks: ${mess['eveningsnacksStart']}-${mess['eveningsnacksEnd']}');
    buffer.writeln('- Dinner: ${mess['dinnerStart']}-${mess['dinnerEnd']}');

    // Walking minutes from the student's hostel to every other campus location,
    // so the model can reason about feasibility without us pre-deciding the answer.
    if (hostelBlock != null) {
      final hostelId = hostelBlock.replaceAll(' ', '_');
      final hostelDoc = await FirebaseFirestore.instance
          .collection('distanceMatrix')
          .doc(hostelId)
          .get();
      if (hostelDoc.exists) {
        buffer.writeln('Walking minutes from hostel to key places:');
        for (final entry in hostelDoc.data()!.entries) {
          if (entry.key == hostelId) continue;
          buffer.writeln('- to ${entry.key.replaceAll('_', ' ')}: ${entry.value} min');
        }
      }
    }

    return buffer.toString();
  }

  /// Sends the user's message plus fresh context to Groq, returns the reply text.
  /// [history] should be prior turns only (NOT including the current userMessage).
  static Future<String> ask(
      String userMessage, List<Map<String, String>> history) async {
    final context = await _buildContext();

    final systemPrompt = '''
You are CampusLoop, a helpful assistant for a VIT Bhopal student. You know their class schedule, hostel, mess timings, and walking distances around campus. Use ONLY the facts given below — never invent building names, times, subjects, or distances that aren't provided. Keep answers short, practical, and friendly, like a helpful senior giving quick advice. If asked something you don't have data for, say so honestly rather than guessing.

CONTEXT:
$context
''';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $groqApiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.4,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }
}