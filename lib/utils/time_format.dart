// Textos de tiempo en español para las pantallas.

/// "Actualizado hace un momento / hace 5 min / hace 2 h / ayer / hace 3 días".
String formatUpdatedAgo(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'Actualizado hace un momento';
  if (d.inMinutes < 60) return 'Actualizado hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'Actualizado hace ${d.inHours} h';
  return d.inDays == 1 ? 'Actualizado ayer' : 'Actualizado hace ${d.inDays} días';
}

/// "sale ahora", "en 15 min", "en 1 h", "en 1 h 5 min".
String formatInMinutes(int minutes) {
  if (minutes <= 0) return 'sale ahora';
  if (minutes < 60) return 'en $minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? 'en $h h' : 'en $h h $m min';
}

/// Fecha y hora cortas en la hora del teléfono: "10/11 a las 13:00".
String formatShortDateTime(DateTime date) {
  final d = date.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} a las ${two(d.hour)}:${two(d.minute)}';
}
