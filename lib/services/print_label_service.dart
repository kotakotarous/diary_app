import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintLabelService {
  static const double paperWidthMm = 58.0;
  static const double labelHeightMm = 40.0;

  static PdfPageFormat get labelFormat => PdfPageFormat(
        paperWidthMm * PdfPageFormat.mm,
        labelHeightMm * PdfPageFormat.mm,
        marginAll: 2 * PdfPageFormat.mm,
      );

  Future<void> printLabel({
    required String modelNumber,
    required String janCode,
    Uint8List? logoImageBytes,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdfBytes(
        modelNumber: modelNumber,
        janCode: janCode,
        logoImageBytes: logoImageBytes,
      ),
      name: 'InkLabel-$modelNumber',
      format: labelFormat,
    );
  }

  Future<Uint8List> buildPdfBytes({
    required String modelNumber,
    required String janCode,
    Uint8List? logoImageBytes,
  }) async {
    final doc = pw.Document(compress: true);

    // バーコード SVG（テキスト描画はPDF側で行うので drawText: false）
    String? barcodeSvg;
    if (RegExp(r'^\d{13}$').hasMatch(janCode)) {
      barcodeSvg = Barcode.ean13().toSvg(
        janCode,
        width: 140,
        height: 40,
        drawText: false,
      );
    }

    pw.ImageProvider? logo;
    if (logoImageBytes != null) {
      logo = pw.MemoryImage(logoImageBytes);
    }

    doc.addPage(
      pw.Page(
        pageFormat: labelFormat,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Image(logo,
                    height: 9 * PdfPageFormat.mm,
                    fit: pw.BoxFit.contain),
                pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
              ],
              pw.Text(
                modelNumber,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (barcodeSvg != null) ...[
                pw.SizedBox(height: 2 * PdfPageFormat.mm),
                pw.SvgImage(svg: barcodeSvg, height: 11 * PdfPageFormat.mm),
                pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
                pw.Text(
                  janCode,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ] else if (janCode.isNotEmpty) ...[
                pw.SizedBox(height: 2 * PdfPageFormat.mm),
                pw.Text(
                  janCode,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
