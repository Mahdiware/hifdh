import 'package:intl/intl.dart';

class ProgressChartHelper {
  static List<Map<String, dynamic>> normalizeChartData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    if (days <= 7) {
      return _generateDailyData(raw, days);
    } else if (days <= 90) {
      // Weekly aggregation for 30 and 90 days
      return _generateWeeklyData(raw, days);
    } else {
      // Monthly aggregation for 6 months and 1 year
      return _generateMonthlyData(raw, days);
    }
  }

  static List<Map<String, dynamic>> _generateDailyData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);

      final hit = raw.firstWhere(
        (element) => element['date'] == key,
        orElse: () => {'date': key, 'count': 0},
      );
      result.add({
        'day': DateFormat('E').format(d)[0], // M, T, W...
        'fullDate': DateFormat('MMM d').format(d),
        'count': hit['count'],
      });
    }
    return result;
  }

  static List<Map<String, dynamic>> _generateWeeklyData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    // Group by Week (Week Ending Date)
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();

    // Align to weeks? Or just raw chunks of 7 days?
    // Let's do raw chunks back from today
    int weeks = (days / 7).ceil();
    for (int i = weeks - 1; i >= 0; i--) {
      final weekEnd = now.subtract(Duration(days: i * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));

      int count = 0;
      for (var item in raw) {
        final date = DateTime.parse(item['date']);
        if (date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
            date.isBefore(weekEnd.add(const Duration(seconds: 1)))) {
          count += (item['count'] as int);
        }
      }

      result.add({
        'day': "${weekStart.day}-${weekEnd.day}", // 12-19
        'fullDate':
            "${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}",
        'count': count,
      });
    }
    return result;
  }

  static List<Map<String, dynamic>> _generateMonthlyData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    int months = (days / 30).ceil(); // Approx

    for (int i = months - 1; i >= 0; i--) {
      // This is rough monthly calculation (30 days blocks)
      // Better to use actual months?
      // Let's use 30 day blocks for simplicity consistent with "days"
      // Or actual calendar months? Calendar months is more user friendly "Jan, Feb".
      // Let's try Calendar months.
      final targetMonth = DateTime(now.year, now.month - i, 1);

      int count = 0;
      for (var item in raw) {
        final date = DateTime.parse(item['date']);
        if (date.year == targetMonth.year && date.month == targetMonth.month) {
          count += (item['count'] as int);
        }
      }

      result.add({
        'day': DateFormat('MMM').format(targetMonth), // Jan, Feb
        'fullDate': DateFormat('MMMM yyyy').format(targetMonth),
        'count': count,
      });
    }
    return result;
  }
}
