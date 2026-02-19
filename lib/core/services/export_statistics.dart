import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';

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

  final bold = await PdfGoogleFonts.openSansBold();

  /// Creates a colored cell with value
  pw.Widget coloredCell(int value, PdfColor color, {pw.Font? font}) {
    // Logic:
    // If -1: Truly empty (No Task) -> Background White, Text '-'
    // If 0: Task exists, no errors -> Background White, Text '0'
    // If >0: Errors exist -> Background Colored, Text 'Number'

    final bool hasErrors = value > 0;
    final bool taskExists = value != -1;

    final background = hasErrors
        ? PdfColor(
            (color.red + PdfColors.white.red) / 2,
            (color.green + PdfColors.white.green) / 2,
            (color.blue + PdfColors.white.blue) / 2,
          )
        : PdfColors.white;

    final textColor = hasErrors ? color : PdfColors.grey600;

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Text(
        taskExists ? '$value' : '-', // This is the fix!
        style: pw.TextStyle(
          fontSize: 10,
          font: font,
          color: textColor,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  /// Header cell
  pw.Widget headerCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 11)),
    );
  }

  /// Subheader for Doubt / Mistake or Revision cells
  pw.Widget subHeaderCell(String left, String right) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(left, style: pw.TextStyle(fontSize: 9)),
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(right, style: pw.TextStyle(fontSize: 9)),
          ),
        ),
      ],
    );
  }

  // Build table rows
  List<pw.TableRow> tableRows = [];

  // Main header
  tableRows.add(
    pw.TableRow(
      children: [
        headerCell("Juz"),
        headerCell("Memorization"),
        for (int i = 0; i < maxRevisions; i++) headerCell("Revision ${i + 1}"),
      ],
    ),
  );

  // Subheader
  tableRows.add(
    pw.TableRow(
      children: [
        pw.Container(),
        subHeaderCell("Doubt", "Mistake"),
        for (int i = 0; i < maxRevisions; i++)
          subHeaderCell("Doubt", "Mistake"),
      ],
    ),
  );

  // Data rows
  for (var row in rows) {
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: row.juz % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
        ),
        children: [
          // Juz number
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text(
              '${row.juz}',
              style: pw.TextStyle(font: bold, fontSize: 10),
            ),
          ),

          // Memorization: Doubt / Mistake
          pw.Row(
            children: [
              pw.Expanded(child: coloredCell(row.doubt, PdfColors.orange700)),
              pw.Expanded(child: coloredCell(row.mistake, PdfColors.red700)),
            ],
          ),

          // Revisions
          for (int i = 0; i < maxRevisions; i++)
            pw.Row(
              children: [
                pw.Expanded(
                  child: coloredCell(
                    i < row.revisionsDoubt.length ? row.revisionsDoubt[i] : 0,
                    PdfColors.orange700,
                  ),
                ),
                pw.Expanded(
                  child: coloredCell(
                    i < row.revisionsMistake.length
                        ? row.revisionsMistake[i]
                        : 0,
                    PdfColors.red700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Add PDF page
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        pw.Text(
          "Quran Memorization & Revision",
          style: pw.TextStyle(
            fontSize: 18,
            font: bold,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FixedColumnWidth(70),
            for (int i = 2; i < maxRevisions + 2; i++)
              i: const pw.FixedColumnWidth(55),
          },
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}
