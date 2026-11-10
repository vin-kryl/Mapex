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
