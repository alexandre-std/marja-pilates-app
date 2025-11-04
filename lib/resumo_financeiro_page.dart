import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResumoFinanceiroPage extends StatefulWidget {
  const ResumoFinanceiroPage({super.key});

  @override
  State<ResumoFinanceiroPage> createState() => _ResumoFinanceiroPageState();
}

class _ResumoFinanceiroPageState extends State<ResumoFinanceiroPage> {
  String anoSelecionado = DateTime.now().year.toString();

  @override
  Widget build(BuildContext context) {
    final faturasRef = FirebaseFirestore.instance.collectionGroup('faturas');

    return Scaffold(
        appBar: AppBar(
          title: Text('Resumo Financeiro'),
          actions: [
            IconButton(
              icon: Icon(Icons.picture_as_pdf),
              tooltip: 'Exportar PDF',
              onPressed: () async {
                try {
                  await Printing.layoutPdf(onLayout: (format) async {
                    final doc = pw.Document();
                    final snapshot = await FirebaseFirestore.instance.collectionGroup('faturas').get();
                    final faturas = snapshot.docs;
                    final agora = DateTime.now();

                    final Map<String, Map<String, double>> resumoPorMes = {};
                    final Map<String, Map<String, Map<String, double>>> clientesPorMes = {};

                    for (var doc in faturas) {
                      final dados = doc.data() as Map<String, dynamic>;

                      if (dados['vencimento'] == null || dados['valor'] == null || dados['status'] == null || dados['cliente'] == null) {
                        continue;
                      }

                      final vencimento = (dados['vencimento'] as Timestamp).toDate();
                      final valor = (dados['valor'] ?? 0.0) as double;
                      final status = dados['status'] ?? 'pendente';
                      final nomeCliente = dados['cliente'] ?? 'Cliente desconhecido';

                      if (vencimento.year.toString() != anoSelecionado) continue;

                      final chaveMes = DateFormat('MMMM/yyyy', 'pt_BR').format(vencimento);
                      resumoPorMes.putIfAbsent(chaveMes, () => {
                        'total': 0.0,
                        'recebido': 0.0,
                        'pendente': 0.0,
                        'vencido': 0.0,
                      });

                      clientesPorMes.putIfAbsent(chaveMes, () => {});
                      clientesPorMes[chaveMes]!.putIfAbsent(nomeCliente, () => {
                        'pendente': 0.0,
                        'vencido': 0.0,
                      });

                      resumoPorMes[chaveMes]!['total'] = resumoPorMes[chaveMes]!['total']! + valor;

                      if (status == 'pago') {
                        resumoPorMes[chaveMes]!['recebido'] = resumoPorMes[chaveMes]!['recebido']! + valor;
                      } else {
                        if (vencimento.isBefore(DateTime(agora.year, agora.month, agora.day))) {
                          resumoPorMes[chaveMes]!['vencido'] = resumoPorMes[chaveMes]!['vencido']! + valor;
                          clientesPorMes[chaveMes]![nomeCliente]!['vencido'] =
                              clientesPorMes[chaveMes]![nomeCliente]!['vencido']! + valor;
                        } else {
                          resumoPorMes[chaveMes]!['pendente'] = resumoPorMes[chaveMes]!['pendente']! + valor;
                          clientesPorMes[chaveMes]![nomeCliente]!['pendente'] =
                              clientesPorMes[chaveMes]![nomeCliente]!['pendente']! + valor;
                        }
                      }
                    }

                    final mesesOrdenados = resumoPorMes.keys.toList()
                      ..sort((a, b) {
                        final da = DateFormat('MMMM/yyyy', 'pt_BR').parse(a);
                        final db = DateFormat('MMMM/yyyy', 'pt_BR').parse(b);
                        return da.compareTo(db);
                      });

                    doc.addPage(
                      pw.MultiPage(
                        build: (pw.Context context) {
                          return mesesOrdenados.map((mes) {
                            final valores = resumoPorMes[mes]!;
                            final clientes = clientesPorMes[mes]!;

                            return pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  '$mes',
                                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text(
                                  'Total: R\$ ${valores['total']!.toStringAsFixed(2)} | '
                                      'Recebido: R\$ ${valores['recebido']!.toStringAsFixed(2)} | '
                                      'Pendente: R\$ ${valores['pendente']!.toStringAsFixed(2)} | '
                                      'Vencido: R\$ ${valores['vencido']!.toStringAsFixed(2)}',
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text('Clientes com pendências:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                ...clientes.entries.map((clienteEntry) {
                                  final nome = clienteEntry.key;
                                  final pendente = clienteEntry.value['pendente']!;
                                  final vencido = clienteEntry.value['vencido']!;
                                  if (pendente == 0 && vencido == 0) return pw.SizedBox();
                                  return pw.Text(
                                    '- $nome: '
                                        '${pendente > 0 ? 'Pendente R\$ ${pendente.toStringAsFixed(2)} ' : ''}'
                                        '${vencido > 0 ? '| Vencido R\$ ${vencido.toStringAsFixed(2)}' : ''}',
                                  );
                                }),
                                pw.SizedBox(height: 12),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    );

                    return doc.save();
                  });
                } catch (e) {
                  print('Erro ao gerar PDF: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao gerar PDF: $e')),
                  );
                }
              },
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: faturasRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

              final faturas = snapshot.data!.docs;
              final agora = DateTime.now();
              final Map<String, Map<String, double>> resumoPorMes = {};
              double recebidoAno = 0, pendenteAno = 0, vencidoAno = 0;

              final anosDisponiveis = faturas
                  .map((doc) => (doc['vencimento'] as Timestamp).toDate().year.toString())
                  .toSet()
                  .toList()
                ..sort();

              for (var doc in faturas) {
                final dados = doc.data() as Map<String, dynamic>;
                final vencimento = (dados['vencimento'] as Timestamp).toDate();
                final valor = (dados['valor'] ?? 0.0) as double;
                final status = dados['status'] ?? 'pendente';

                if (vencimento.year.toString() != anoSelecionado) continue;

                final chaveMes = DateFormat('MM/yyyy').format(vencimento);
                resumoPorMes.putIfAbsent(chaveMes, () => {
                  'total': 0.0,
                  'recebido': 0.0,
                  'pendente': 0.0,
                  'vencido': 0.0,
                });

                resumoPorMes[chaveMes]!['total'] = resumoPorMes[chaveMes]!['total']! + valor;

                if (status == 'pago') {
                  resumoPorMes[chaveMes]!['recebido'] = resumoPorMes[chaveMes]!['recebido']! + valor;
                  recebidoAno += valor;
                } else {
                  if (vencimento.isBefore(DateTime(agora.year, agora.month, agora.day))) {
                    resumoPorMes[chaveMes]!['vencido'] = resumoPorMes[chaveMes]!['vencido']! + valor;
                    vencidoAno += valor;
                  } else {
                    resumoPorMes[chaveMes]!['pendente'] = resumoPorMes[chaveMes]!['pendente']! + valor;
                    pendenteAno += valor;
                  }
                }
              }

              final mesesOrdenados = resumoPorMes.keys.toList()
                ..sort((a, b) {
                  final da = DateFormat('MM/yyyy').parse(a);
                  final db = DateFormat('MM/yyyy').parse(b);
                  return da.compareTo(db);
                });

              return SafeArea(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
                  children: [
                  DropdownButton<String>(
                  value: anoSelecionado,
                  items: anosDisponiveis.map((ano) => DropdownMenuItem(value: ano, child: Text(ano))).toList(),
                  onChanged: (novoAno) {
                    setState(() => anoSelecionado = novoAno!);
                  },
                ),
                    ...mesesOrdenados.map((chave) {
                      final valores = resumoPorMes[chave]!;
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mês: $chave', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('Total Previsto: R\$ ${valores['total']!.toStringAsFixed(2)}'),
                              Text('Recebido: R\$ ${valores['recebido']!.toStringAsFixed(2)}', style: TextStyle(color: Colors.green)),
                              Text('Pendente: R\$ ${valores['pendente']!.toStringAsFixed(2)}', style: TextStyle(color: Colors.orange)),
                              Text('Vencido: R\$ ${valores['vencido']!.toStringAsFixed(2)}', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 24),
                    Text('Proporção no ano $anoSelecionado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 200, child: _buildPieChart(recebidoAno, pendenteAno, vencidoAno)),
                  ],
                ),
              );
            },
        ),
    );
  }

  Widget _buildPieChart(double recebido, double pendente, double vencido) {
    final total = recebido + pendente + vencido;
    if (total == 0) {
      return Center(child: Text('Sem dados para este ano'));
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: recebido,
            color: Colors.green,
            title: 'Recebido',
          ),
          PieChartSectionData(
            value: pendente,
            color: Colors.orange,
            title: 'Pendente',
          ),
          PieChartSectionData(
            value: vencido,
            color: Colors.red,
            title: 'Vencido',
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
}
