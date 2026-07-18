const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _kWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String greeting({DateTime? now}) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

/// e.g. "Friday, 17th July"
String formatFriendlyDate(DateTime date) {
  final weekday = _kWeekdays[date.weekday - 1];
  return '$weekday, ${_ordinal(date.day)} ${_kMonths[date.month - 1]}';
}

/// e.g. "17 Jul 2026"
String formatShortDate(DateTime date) {
  return '${date.day} ${_kMonths[date.month - 1]} ${date.year}';
}

/// e.g. "3:45 PM"
String formatTime(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final period = date.hour < 12 ? 'AM' : 'PM';
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}

/// Buckets a timestamp into Today / Yesterday / Earlier for notification-style feeds.
String dayBucket(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final target = DateTime(date.year, date.month, date.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  final diff = todayDate.difference(target).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return 'Earlier';
}
