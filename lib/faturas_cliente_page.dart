import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'comprovante_pdf.dart';


class FaturasClientePage extends StatefulWidget {
  final String clienteId;
  final String nomeCliente;

  const FaturasClientePage({
    required this.clienteId,
    required this.nomeCliente,
    super.key,
  });

  @override
  State<FaturasClientePage> createState() => _FaturasClientePageState();
}

class _FaturasClientePageState extends State<FaturasClientePage> {
  @override
  Widget build(BuildContext context) {
    final faturasRef = FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .collection('faturas')
        .orderBy('vencimento');

    return Scaffold(
      appBar: AppBar(title: Text('Faturas de ${widget.nomeCliente}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: faturasRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar faturas'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final faturas = snapshot.data!.docs;

          if (faturas.isEmpty) {
            return Center(child: Text('Nenhuma fatura encontrada'));
          }

          return ListView.builder(
            itemCount: faturas.length,
            itemBuilder: (context, index) {
              final fatura = faturas[index];
              final dados = fatura.data() as Map<String, dynamic>;
              final valor = dados['valor'] ?? 0.0;
              final status = dados['status'] ?? 'pendente';
              final vencimento = (dados['vencimento'] as Timestamp).toDate();

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('R\$ ${valor.toStringAsFixed(2)}'),
                  subtitle: Text(
                    'Vencimento: ${vencimento.day}/${vencimento.month}/${vencimento.year} • Status: $status',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => editarFatura(fatura),
                      ),
                      if (status != 'pago') ...[
                        IconButton(
                          icon: Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'Marcar como pago',
                          onPressed: () => marcarComoPago(fatura),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => excluirFatura(fatura),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void excluirFatura(DocumentSnapshot fatura) async {
    final dados = fatura.data() as Map<String, dynamic>;
    final status = dados['status'] ?? 'pendente';

    if (status == 'pago') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fatura paga não pode ser excluída')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir esta fatura?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Excluir')),
        ],
      ),
    );

    if (confirmar == true) {
      await fatura.reference.delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fatura excluída')));
    }
  }

  void editarFatura(DocumentSnapshot fatura) {
    final dados = fatura.data() as Map<String, dynamic>;
    final valorController = TextEditingController(text: dados['valor'].toString());
    String status = dados['status'] ?? 'pendente';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Fatura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valorController,
              decoration: InputDecoration(labelText: 'Valor'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: status,
              items: ['pendente', 'pago']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => status = v!,
              decoration: InputDecoration(labelText: 'Status'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final novoValor = double.tryParse(valorController.text) ?? dados['valor'];
              await fatura.reference.update({
                'valor': novoValor,
                'status': status,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fatura atualizada')));
            },
            child: Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> marcarComoPago(DocumentSnapshot fatura) async {
    final dados = fatura.data() as Map<String, dynamic>;
    final cliente = dados['cliente'] ?? 'Cliente';
    final valor = dados['valor'] ?? 0.0;
    final referente = dados['referente'] ?? '';
    final modalidade = dados['modalidade'] ?? 'Serviço';
    final telefone = dados['telefone'] ?? '';
    final parcela = dados['parcela'] ?? 1;
    final totalParcelas = dados['totalParcelas'] ?? 1;
    final dataPagamento = DateTime.now();

    await fatura.reference.update({'status': 'pago'});

    await gerarComprovantePDF(
      nome: cliente,
      valor: valor,
      servico: modalidade,
      dataPagamento: dataPagamento,
      parcela: parcela,
      totalParcelas: totalParcelas,
    );

    final texto = Uri.encodeComponent(
        'Olá! Segue o comprovante de pagamento da fatura referente a $referente no valor de R\$ ${valor.toStringAsFixed(2)}.'
    );

    final url = 'https://wa.me/$telefone?text=$texto';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
      );
    }
  }
}