/// Formats a [DateTime] as a short, human-readable local date and time,
/// e.g. "17 Sep 2026, 4:05 PM". Avoids adding an intl dependency for a
/// single, simple display format.
String formatDateTime(DateTime dt) {
  const months = [
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
  final local = dt.toLocal();
  final day = local.day;
  final month = months[local.month - 1];
  final year = local.year;

  final hour24 = local.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day $month $year, $hour12:$minute $period';
}
