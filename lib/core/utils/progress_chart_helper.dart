import 'package:intl/intl.dart';

class ProgressChartHelper {
  static List<Map<String, dynamic>> normalizeChartData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    if (days <= 7) {
      return _generateDailyData(raw, days);
    } else if (days <= 90) {
      return _generateWeeklyData(raw, days);
    } else {
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
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);

      final hit = raw.firstWhere(
        (element) => element['date'] == key,
        orElse: () => {'date': key, 'count': 0},
      );

      result.add({
        'startDate': date,
        'endDate': null, // Single day has no end date
        'count': hit['count'],
        'day': DateFormat('E').format(date)[0], // Fallback label
      });
    }
    return result;
  }

  static List<Map<String, dynamic>> _generateWeeklyData(
    List<Map<String, dynamic>> raw,
    int days,
  ) {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    int weeks = (days / 7).ceil();

    for (int i = weeks - 1; i >= 0; i--) {
      // Create a 7-day window
      final weekEnd = DateTime(now.year, now.month, now.day).subtract(Duration(days: i * 7));
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
        'startDate': weekStart,
        'endDate': weekEnd,
        'count': count,
        'day': "${weekStart.day}-${weekEnd.day}", // Fallback label
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
    int months = (days / 30).ceil();

    for (int i = months - 1; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      // Get the last day of that month
      final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

      int count = 0;
      for (var item in raw) {
        final date = DateTime.parse(item['date']);
        if (date.year == targetMonth.year && date.month == targetMonth.month) {
          count += (item['count'] as int);
        }
      }

      result.add({
        'startDate': targetMonth,
        'endDate': lastDayOfMonth,
        'count': count,
        'day': DateFormat('MMM').format(targetMonth), // Fallback label
      });
    }
    return result;
  }
}
