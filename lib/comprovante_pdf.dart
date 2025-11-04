import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

Future<void> gerarComprovantePDF({
  required String nome,
  required double valor,
  required String servico,
  required DateTime dataPagamento,
  required int parcela,
  required int totalParcelas,
}) async {
  final pdf = pw.Document();
  final dataFormatada = DateFormat('dd/MM/yyyy').format(dataPagamento);

  // Carrega o logotipo
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/logo_marja.webp')).buffer.asUint8List(),
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(32),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Image(logo, height: 80)),
              pw.SizedBox(height: 16),
              pw.Container(
                color: PdfColors.blue800,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                width: double.infinity,
                child: pw.Center(
                  child: pw.Text(
                    'RECIBO DE PAGAMENTO',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text('Confirmamos o recebimento de:',
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text(nome,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('O valor de:',
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text('R\$ ${valor.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text(
                  'Referente à parcela $parcela de $totalParcelas para serviços prestados de:',
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text(servico,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 24),
              pw.Text('Data do pagamento: $dataFormatada',
                  style: pw.TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    ),
  );

  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/comprovante_${nome.replaceAll(' ', '_')}.pdf');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: 'Olá $nome! Aqui está seu comprovante de pagamento.',
  );
}
