import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import 'wallet_models.dart';

const _brandDark = PdfColor.fromInt(0xFF1D3108);
const _brandAccent = PdfColor.fromInt(0xFF5BA72D);
const _brandPale = PdfColor.fromInt(0xFFE8F6E0);
const _muted = PdfColor.fromInt(0xFF8A9182);
const _border = PdfColor.fromInt(0xFFEDEFEA);

bool _isCreditType(String type) {
  final t = type.toLowerCase().replaceAll('_', '').replaceAll('-', '');
  const creditKeywords = ['deposit', 'topup', 'payout', 'refund', 'credit', 'received', 'reversal'];
  const debitKeywords = ['withdraw', 'contribution', 'debit', 'payment'];
  if (debitKeywords.any(t.contains)) return false;
  return creditKeywords.any(t.contains);
}

String _friendlyType(String type) {
  final words = type.replaceAll('_', ' ').split(' ');
  return words.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
}

/// Renders a transaction receipt as a one-page PDF and opens the native
/// share/save sheet — entirely client-side, no backend call involved.
///
/// The bundled font assets (not the PDF package's base-14 fonts, which lack
/// a ₦ glyph and render it as a broken tofu box) are embedded so the
/// currency symbol and bullet actually render.
Future<void> shareReceiptPdf(TransactionReceipt receipt) async {
  final bodyFontData = await rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf');
  final displayFontData = await rootBundle.load('assets/fonts/SpaceGrotesk-Variable.ttf');
  final logoData = await rootBundle.load('assets/images/logo.png');
  final bodyFont = pw.Font.ttf(bodyFontData);
  final displayFont = pw.Font.ttf(displayFontData);
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: bodyFont, bold: displayFont));
  final isCredit = _isCreditType(receipt.type);

  final rows = <List<String>>[
    ['Type', _friendlyType(receipt.type)],
    ['Date', formatShortDate(receipt.date)],
    ['Time', formatTime(receipt.date)],
    if (receipt.senderName != null) ['From', receipt.senderName!],
    if (receipt.recipientName != null) ['To', receipt.recipientName!],
    if (receipt.narration != null && receipt.narration!.isNotEmpty) ['Narration', receipt.narration!],
    if (receipt.reference != null && receipt.reference!.isNotEmpty) ['Reference', receipt.reference!],
    ['Transaction ID', receipt.transactionId],
  ];

  final now = DateTime.now();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header band
            pw.Container(
              width: double.infinity,
              color: _brandPale,
              padding: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 28),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(width: 40, height: 40, child: pw.Image(logoImage)),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('AjoPay', style: pw.TextStyle(font: displayFont, fontSize: 18, color: _brandDark)),
                          pw.Text('Save together. Grow together.', style: const pw.TextStyle(fontSize: 9, color: _muted)),
                        ],
                      ),
                    ],
                  ),
                  pw.Text('Transaction Receipt', style: pw.TextStyle(font: displayFont, fontSize: 12, color: _brandDark)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${isCredit ? '+' : '-'} ₦${formatAmount(receipt.amount.abs())}',
                          style: pw.TextStyle(font: displayFont, fontSize: 28, color: isCredit ? _brandAccent : _brandDark),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(color: _brandPale, borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Text(receipt.status.toUpperCase(), style: pw.TextStyle(fontSize: 9, color: _brandAccent)),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 36),
                  pw.Divider(color: _border, thickness: 1),
                  pw.SizedBox(height: 18),
                  for (final row in rows) ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(row[0], style: const pw.TextStyle(fontSize: 11, color: _muted)),
                        pw.SizedBox(
                          width: 300,
                          child: pw.Text(row[1], textAlign: pw.TextAlign.right, style: pw.TextStyle(font: displayFont, fontSize: 11, color: _brandDark)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(color: _border, thickness: 1),
                    pw.SizedBox(height: 12),
                  ],
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'Generated ${formatShortDate(now)} · ${formatTime(now)}',
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'This receipt was generated by AjoPay and is valid without a signature.',
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  final idPrefix = receipt.transactionId.substring(0, receipt.transactionId.length.clamp(0, 8));
  await Printing.sharePdf(bytes: await doc.save(), filename: 'ajopay-receipt-$idPrefix.pdf');
}
