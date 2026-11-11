/// Short "edited 5 min ago" style text, without extra packages.
String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  if (diff.inDays < 7) {
    return diff.inDays == 1 ? 'yesterday' : '${diff.inDays} days ago';
  }
  final local = time.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Today", "Tomorrow", "Fri" within a week, else "14 Nov".
String shortDay(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return _weekdays[d.weekday - 1];
  final year = d.year == today.year ? '' : ' ${d.year}';
  return '${d.day} ${_months[d.month - 1]}$year';
}

String plural(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
