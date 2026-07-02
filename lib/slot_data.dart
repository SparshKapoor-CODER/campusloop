class TimeSlot {
  final String code;
  final String day;
  final String startTime;
  final String endTime;
  final int columnIndex; 

  const TimeSlot({
    required this.code,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.columnIndex,
  });
}

const List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const List<TimeSlot> allSlots = [
  TimeSlot(code: 'A11', day: 'Mon', startTime: '08:30', endTime: '10:00', columnIndex: 1),
  TimeSlot(code: 'B11', day: 'Mon', startTime: '10:05', endTime: '11:35', columnIndex: 2),
  TimeSlot(code: 'C11', day: 'Mon', startTime: '11:40', endTime: '13:10', columnIndex: 3),
  TimeSlot(code: 'A21', day: 'Mon', startTime: '13:15', endTime: '14:45', columnIndex: 4),
  TimeSlot(code: 'A14', day: 'Mon', startTime: '14:50', endTime: '16:20', columnIndex: 5),
  TimeSlot(code: 'B21', day: 'Mon', startTime: '16:25', endTime: '17:55', columnIndex: 6),
  TimeSlot(code: 'C21', day: 'Mon', startTime: '18:00', endTime: '19:30', columnIndex: 7),

  TimeSlot(code: 'D11', day: 'Tue', startTime: '08:30', endTime: '10:00', columnIndex: 1),
  TimeSlot(code: 'E11', day: 'Tue', startTime: '10:05', endTime: '11:35', columnIndex: 2),
  TimeSlot(code: 'F11', day: 'Tue', startTime: '11:40', endTime: '13:10', columnIndex: 3),
  TimeSlot(code: 'D21', day: 'Tue', startTime: '13:15', endTime: '14:45', columnIndex: 4),
  TimeSlot(code: 'E14', day: 'Tue', startTime: '14:50', endTime: '16:20', columnIndex: 5),
  TimeSlot(code: 'E21', day: 'Tue', startTime: '16:25', endTime: '17:55', columnIndex: 6),
  TimeSlot(code: 'F21', day: 'Tue', startTime: '18:00', endTime: '19:30', columnIndex: 7),

  TimeSlot(code: 'A12', day: 'Wed', startTime: '08:30', endTime: '10:00', columnIndex: 1),
  TimeSlot(code: 'B12', day: 'Wed', startTime: '10:05', endTime: '11:35', columnIndex: 2),
  TimeSlot(code: 'C12', day: 'Wed', startTime: '11:40', endTime: '13:10', columnIndex: 3),
  TimeSlot(code: 'A22', day: 'Wed', startTime: '13:15', endTime: '14:45', columnIndex: 4),
  TimeSlot(code: 'B14', day: 'Wed', startTime: '14:50', endTime: '16:20', columnIndex: 5),
  TimeSlot(code: 'B22', day: 'Wed', startTime: '16:25', endTime: '17:55', columnIndex: 6),
  TimeSlot(code: 'A24', day: 'Wed', startTime: '18:00', endTime: '19:30', columnIndex: 7),

  TimeSlot(code: 'D12', day: 'Thu', startTime: '08:30', endTime: '10:00', columnIndex: 1),
  TimeSlot(code: 'E12', day: 'Thu', startTime: '10:05', endTime: '11:35', columnIndex: 2),
  TimeSlot(code: 'F12', day: 'Thu', startTime: '11:40', endTime: '13:10', columnIndex: 3),
  TimeSlot(code: 'D22', day: 'Thu', startTime: '13:15', endTime: '14:45', columnIndex: 4),
  TimeSlot(code: 'F14', day: 'Thu', startTime: '14:50', endTime: '16:20', columnIndex: 5),
  TimeSlot(code: 'E22', day: 'Thu', startTime: '16:25', endTime: '17:55', columnIndex: 6),
  TimeSlot(code: 'F22', day: 'Thu', startTime: '18:00', endTime: '19:30', columnIndex: 7),

  TimeSlot(code: 'A13', day: 'Fri', startTime: '08:30', endTime: '10:00', columnIndex: 1),
  TimeSlot(code: 'B13', day: 'Fri', startTime: '10:05', endTime: '11:35', columnIndex: 2),
  TimeSlot(code: 'C13', day: 'Fri', startTime: '11:40', endTime: '13:10', columnIndex: 3),
  TimeSlot(code: 'A23', day: 'Fri', startTime: '13:15', endTime: '14:45', columnIndex: 4),
  TimeSlot(code: 'C14', day: 'Fri', startTime: '14:50', endTime: '16:20', columnIndex: 5),
  TimeSlot(code: 'B23', day: 'Fri', startTime: '16:25', endTime: '17:55', columnIndex: 6),
  TimeSlot(code: 'B24', day: 'Fri', startTime: '18:00', endTime: '19:30', columnIndex: 7),

  TimeSlot(code: 'D13', day: 'Sat', startTime: '08:30', endTime: '10:00', columnIndex: 1),
  TimeSlot(code: 'E13', day: 'Sat', startTime: '10:05', endTime: '11:35', columnIndex: 2),
  TimeSlot(code: 'F13', day: 'Sat', startTime: '11:40', endTime: '13:10', columnIndex: 3),
  TimeSlot(code: 'D23', day: 'Sat', startTime: '13:15', endTime: '14:45', columnIndex: 4),
  TimeSlot(code: 'D14', day: 'Sat', startTime: '14:50', endTime: '16:20', columnIndex: 5),
  TimeSlot(code: 'D24', day: 'Sat', startTime: '16:25', endTime: '17:55', columnIndex: 6),
  TimeSlot(code: 'E23', day: 'Sat', startTime: '18:00', endTime: '19:30', columnIndex: 7),
];