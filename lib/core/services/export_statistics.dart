import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Represents one Juz row with doubts, mistakes, and revision counts.
class JuzRow {
  final int juz;
  final int doubt;
  final int mistake;
  final List<int> revisionsDoubt;
  final List<int> revisionsMistake;

  JuzRow({
    required this.juz,
    required this.doubt,
    required this.mistake,
    required this.revisionsDoubt,
    required this.revisionsMistake,
  });
}

/// Utility class to quickly create JuzRow data
class JuzDataBuilder {
  int juz = 1;
  int doubt = 0;
  int mistake = 0;
  List<int> revisionsDoubt = [];
  List<int> revisionsMistake = [];

  /// Set the current Juz number
  JuzDataBuilder setJuz(int j) {
    juz = j;
    return this;
  }

  /// Set memorize counts for doubt and mistake
  JuzDataBuilder setMemorize({int d = 0, int m = 0}) {
    doubt = d;
    mistake = m;
    return this;
  }

  /// Add revision counts for this Juz
  JuzDataBuilder setRevisions(List<int> revDoubt, List<int> revMistake) {
    revisionsDoubt = revDoubt;
    revisionsMistake = revMistake;
    return this;
  }

  /// Build the JuzRow
  JuzRow build() {
    return JuzRow(
      juz: juz,
      doubt: doubt,
      mistake: mistake,
      revisionsDoubt: revisionsDoubt,
      revisionsMistake: revisionsMistake,
    );
  }
}

/// Export a Quran memorization & revision PDF
Future<void> exportJuzRevisionPdf(
  List<JuzRow> rows, {
  int maxRevisions = 5,
}) async {
  final pdf = pw.Document();
  final base = await PdfGoogleFonts.interRegular();
  final semiBold = await PdfGoogleFonts.interSemiBold();
  final bold = await PdfGoogleFonts.interBold();

  String twoDigits(int value) => value < 10 ? '0$value' : '$value';

  String formatTimestamp(DateTime dt) {
    return '${dt.year}-${twoDigits(dt.month)}-${twoDigits(dt.day)} '
        '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }

  PdfColor tint(PdfColor color, double amount) {
    return PdfColor(
      color.red + (1 - color.red) * amount,
      color.green + (1 - color.green) * amount,
      color.blue + (1 - color.blue) * amount,
    );
  }

  int inferredMaxRevisions = 0;
  for (final row in rows) {
    if (row.revisionsDoubt.length > inferredMaxRevisions) {
      inferredMaxRevisions = row.revisionsDoubt.length;
    }
    if (row.revisionsMistake.length > inferredMaxRevisions) {
      inferredMaxRevisions = row.revisionsMistake.length;
    }
  }
  final effectiveMaxRevisions = maxRevisions > inferredMaxRevisions
      ? maxRevisions
      : inferredMaxRevisions;

  int memorizationTasks = 0;
  int revisionTasks = 0;
  int totalDoubts = 0;
  int totalMistakes = 0;

  for (final row in rows) {
    final hasMemTask = row.doubt != -1 || row.mistake != -1;
    if (hasMemTask) memorizationTasks++;

    if (row.doubt > 0) totalDoubts += row.doubt;
    if (row.mistake > 0) totalMistakes += row.mistake;

    for (int i = 0; i < effectiveMaxRevisions; i++) {
      final doubt = i < row.revisionsDoubt.length ? row.revisionsDoubt[i] : -1;
      final mistake = i < row.revisionsMistake.length
          ? row.revisionsMistake[i]
          : -1;
      final hasRevisionTask = doubt != -1 || mistake != -1;
      if (hasRevisionTask) revisionTasks++;
      if (doubt > 0) totalDoubts += doubt;
      if (mistake > 0) totalMistakes += mistake;
    }
  }

  final generatedAt = formatTimestamp(DateTime.now());

  pw.Widget statCard({
    required String label,
    required String value,
    required PdfColor accent,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: tint(accent, 0.88),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: tint(accent, 0.7), width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(font: bold, fontSize: 14, color: accent),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: pw.TextStyle(font: semiBold, fontSize: 9, color: accent),
          ),
        ],
      ),
    );
  }

  pw.Widget valueChip(int value, PdfColor accent) {
    final hasValue = value != -1;
    final hasIssues = value > 0;
    final background = hasIssues
        ? tint(accent, 0.8)
        : (hasValue ? PdfColors.white : PdfColors.grey50);
    final textColor = hasIssues
        ? accent
        : (hasValue ? PdfColors.blueGrey800 : PdfColors.grey500);

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.5),
      ),
      child: pw.Text(
        hasValue ? '$value' : '-',
        style: pw.TextStyle(font: semiBold, fontSize: 9, color: textColor),
      ),
    );
  }

  pw.Widget pairHeaderCell() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Doubt',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: semiBold, fontSize: 8),
            ),
          ),
          pw.SizedBox(width: 2),
          pw.Expanded(
            child: pw.Text(
              'Mistake',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: semiBold, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget pairDataCell(int left, int right) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(child: valueChip(left, PdfColors.orange700)),
          pw.SizedBox(width: 2),
          pw.Expanded(child: valueChip(right, PdfColors.red700)),
        ],
      ),
    );
  }

  final tableRows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            'Juz',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            'Memorization',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
          ),
        ),
        for (int i = 0; i < effectiveMaxRevisions; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              'Revision ${i + 1}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
            ),
          ),
      ],
    ),
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
      children: [
        pw.SizedBox(),
        pairHeaderCell(),
        for (int i = 0; i < effectiveMaxRevisions; i++) pairHeaderCell(),
      ],
    ),
  ];

  for (final row in rows) {
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: row.juz.isEven ? PdfColors.blue50 : PdfColors.white,
        ),
        children: [
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Text(
              '${row.juz}',
              style: pw.TextStyle(font: bold, fontSize: 10),
            ),
          ),
          pairDataCell(row.doubt, row.mistake),
          for (int i = 0; i < effectiveMaxRevisions; i++)
            pairDataCell(
              i < row.revisionsDoubt.length ? row.revisionsDoubt[i] : -1,
              i < row.revisionsMistake.length ? row.revisionsMistake[i] : -1,
            ),
        ],
      ),
    );
  }

  final columnWidths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(34),
    1: const pw.FlexColumnWidth(1.3),
    for (int i = 2; i < effectiveMaxRevisions + 2; i++)
      i: const pw.FlexColumnWidth(1),
  };

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(base: base, bold: bold),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated at $generatedAt',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColors.indigo800, PdfColors.blue700],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Quran Memorization Report',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Juz progress and revision quality overview',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${rows.length}',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 16,
                        color: PdfColors.indigo800,
                      ),
                    ),
                    pw.Text(
                      'Juz in report',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: statCard(
                label: 'Memorization Tasks',
                value: '$memorizationTasks',
                accent: PdfColors.indigo700,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: statCard(
                label: 'Revision Tasks',
                value: '$revisionTasks',
                accent: PdfColors.blue700,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: statCard(
                label: 'Total Doubts',
                value: '$totalDoubts',
                accent: PdfColors.orange700,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: statCard(
                label: 'Total Mistakes',
                value: '$totalMistakes',
                accent: PdfColors.red700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.7),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                'Legend:',
                style: pw.TextStyle(font: semiBold, fontSize: 9),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                '-  No task',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                '0  Task completed with no issues',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                '>0  Issues recorded',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        if (rows.isEmpty)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'No data available for export',
                  style: pw.TextStyle(font: bold, fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Complete tasks and add notes to generate a detailed report.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          )
        else
          pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.8),
            ),
            child: pw.Table(
              columnWidths: columnWidths,
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: tableRows,
            ),
          ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}
