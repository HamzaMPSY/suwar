import '../../core/quran_repository.dart';

String prayerClock(DateTime time) => displayNumber(
  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
);
String prayerDate(DateTime time) {
  const days = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'ماي',
    'يونيو',
    'يوليوز',
    'غشت',
    'شتنبر',
    'أكتوبر',
    'نونبر',
    'دجنبر',
  ];
  return '${days[time.weekday - 1]}، ${displayNumber(time.day)} ${months[time.month - 1]} ${displayNumber(time.year)}';
}

String prayerCountdown(Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil().clamp(0, 2880);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return hours > 0
      ? 'باقي ${displayNumber(hours)} ساعة و${displayNumber(rest)} دقيقة'
      : 'باقي ${displayNumber(rest)} دقيقة';
}
