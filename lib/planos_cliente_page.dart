import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlanosClientePage extends StatefulWidget {
  final String clienteId;

  const PlanosClientePage({required this.clienteId});

  @override
  State<PlanosClientePage> createState() => _PlanosClientePageState();
}

class _PlanosClientePageState extends State<PlanosClientePage> {
  final nomePlanoController = TextEditingController();
  final modalidadeController = TextEditingController();
  String? frequencia;
  DateTime? inicio;
  DateTime? fim;
  double? valor;

  DateTime _calcularFim(DateTime inicio, String nomePlano) {
    switch (nomePlano) {
      case 'Plano Mensal':
        return inicio.add(Duration(days: 30));
      case 'Plano Semestral':
        return DateTime(inicio.year, inicio.month + 6, inicio.day);
      case 'Plano Anual':
        return DateTime(inicio.year + 1, inicio.month, inicio.day);
      default:
        return inicio;
    }
  }

  double _calcularValor(String modalidade, String plano, String frequencia) {
    if (modalidade == 'Pilates Solo') {
      if (plano == 'Plano Anual') {
        return frequencia == '1x por semana' ? 110.0 : 140.0;
      } else if (plano == 'Plano Semestral') {
        return frequencia == '1x por semana' ? 140.0 : 160.0;
      } else if (plano == 'Plano Mensal') {
        return frequencia == '1x por semana' ? 160.0 : 180.0;
      }
    } else if (modalidade == 'Pilates Aparelho') {
      if (plano == 'Plano Anual') {
        return frequencia == '1x por semana' ? 170.0 : 280.0;
      } else if (plano == 'Plano Semestral') {
        return frequencia == '1x por semana' ? 185.0 : 295.0;
      } else if (plano == 'Plano Mensal') {
        return frequencia == '1x por semana' ? 200.0 : 320.0;
      }
    }
    return 0.0;
  }

  void _atualizarValor() {
    if (modalidadeController.text.isNotEmpty &&
        nomePlanoController.text.isNotEmpty &&
        frequencia != null) {
      setState(() {
        valor = _calcularValor(
          modalidadeController.text,
          nomePlanoController.text,
          frequencia!,
        );
      });
    } else {
      setState(() {
        valor = null;
      });
    }
  }

  Future<void> adicionarPlano() async {
    if (nomePlanoController.text.trim().isEmpty ||
        modalidadeController.text.trim().isEmpty ||
        frequencia == null ||
        inicio == null ||
        fim == null ||
        valor == null ||
        valor! <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preencha todos os campos corretamente')));
      return;
    }

    if (fim!.isBefore(inicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Data final não pode ser anterior à inicial')));
      return;
    }

    final planosRef = FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .collection('planos');

    final planosExistentes = await planosRef.get();

    for (var doc in planosExistentes.docs) {
      final dados = doc.data();
      final modalidadeExistente = dados['modalidade'];
      final inicioExistente = _parseData(dados['inicio']);
      final fimExistente = _parseData(dados['fim']);

      final sobrepoe = !(fim!.isBefore(inicioExistente) || inicio!.isAfter(fimExistente));

      if (modalidadeExistente == modalidadeController.text && sobrepoe) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Já existe um plano dessa modalidade nesse período')),
        );
        return;
      }
    }

    await planosRef.add({
      'nomePlano': nomePlanoController.text,
      'modalidade': modalidadeController.text,
      'frequencia': frequencia,
      'inicio': _formatarData(inicio!),
      'fim': _formatarData(fim!),
      'valor': valor,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    nomePlanoController.clear();
    modalidadeController.clear();
    frequencia = null;
    inicio = null;
    fim = null;
    valor = null;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plano adicionado')));
  }

  Future<void> gerarFaturasParaPlano({
    required String planoId,
    required Map<String, dynamic> dados,
  }) async {
    final inicioPlano = _parseData(dados['inicio']);
    final fimPlano = _parseData(dados['fim']);
    final valorMensal = dados['valor'] ?? 0.0;
    final nomePlano = dados['nomePlano'];

    final clienteDoc = await FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .get();

    final nomeCliente = clienteDoc['nome'] ?? 'Cliente desconhecido';

    final faturasRef = FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .collection('faturas');

    final faturasExistentes = await faturasRef
        .where('planoId', isEqualTo: planoId)
        .get();

    if (faturasExistentes.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Faturas já foram geradas para este plano')),
      );
      return;
    }

    // ✅ Define totalParcelas com base no tipo de plano
    int totalParcelas;
    switch (nomePlano) {
      case 'Plano Anual':
        totalParcelas = 12;
        break;
      case 'Plano Semestral':
        totalParcelas = 6;
        break;
      case 'Plano Mensal':
        totalParcelas = 1;
        break;
      default:
        totalParcelas = 1;
    }

    DateTime atual = DateTime(inicioPlano.year, inicioPlano.month, 10);
    if (inicioPlano.day > 10) {
      atual = DateTime(inicioPlano.year, inicioPlano.month + 1, 10);
    }

    bool primeiraFatura = true;
    int parcelaAtual = 1;

    while (parcelaAtual <= totalParcelas) {
      double valorFatura = valorMensal;
      String referente = 'Mensal ${_nomeMes(atual.month)}/${atual.year}';

      if (primeiraFatura) {
        if (inicioPlano.day > 1) {
          final ultimoDiaMes = DateTime(inicioPlano.year, inicioPlano.month + 1, 0).day;
          final diasProporcionais = ultimoDiaMes - inicioPlano.day + 1;
          valorFatura = (valorMensal / 30) * diasProporcionais;
          referente += ' (proporcional)';
        }
        primeiraFatura = false;
      }

      await faturasRef.add({
        'vencimento': Timestamp.fromDate(atual),
        'valor': double.parse(valorFatura.toStringAsFixed(2)),
        'status': 'pendente',
        'referente': referente,
        'planoId': planoId,
        'nomePlano': nomePlano,
        'modalidade': dados['modalidade'],
        'cliente': nomeCliente,
        'parcela': parcelaAtual,
        'totalParcelas': totalParcelas,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      parcelaAtual++;
      atual = DateTime(atual.year, atual.month + 1, 10);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Faturas geradas com sucesso')),
    );
  }


  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  DateTime _parseData(String data) {
    final partes = data.split('/');
    return DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
  }

  String _nomeMes(int mes) {
    const nomes = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return nomes[mes - 1];
  }

  int _calcularTotalParcelas(DateTime inicio, DateTime fim) {
    int total = 0;
    DateTime atual = DateTime(inicio.year, inicio.month);

    while (atual.isBefore(fim) || atual.isAtSameMomentAs(fim)) {
      total++;
      atual = DateTime(atual.year, atual.month + 1);
    }

    return total;
  }


  Future<void> excluirPlano(String planoId) async {
    final faturasRef = FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .collection('faturas');

    final faturasDoPlano = await faturasRef
        .where('planoId', isEqualTo: planoId)
        .limit(1)
        .get();

    if (faturasDoPlano.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não é possível excluir: existem faturas geradas para este plano')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .collection('planos')
        .doc(planoId)
        .delete();

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plano excluído com sucesso')));
  }

  @override
  Widget build(BuildContext context) {
    final planosRef = FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .collection('planos');

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text('Planos do Cliente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: nomePlanoController.text.isEmpty ? null : nomePlanoController.text,
              decoration: InputDecoration(labelText: 'Tipo do Plano'),
              items: ['Plano Semestral', 'Plano Anual']
                  .map((plano) => DropdownMenuItem(value: plano, child: Text(plano)))
                  .toList(),
              onChanged: (valorSelecionado) {
                setState(() {
                  nomePlanoController.text = valorSelecionado!;
                  if (inicio != null) {
                    fim = _calcularFim(inicio!, valorSelecionado);
                  }
                  _atualizarValor();
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: modalidadeController.text.isEmpty ? null : modalidadeController.text,
              decoration: InputDecoration(labelText: 'Modalidade'),
              items: ['Pilates Solo', 'Pilates Aparelho']
                  .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                  .toList(),
              onChanged: (valorSelecionado) {
                setState(() {
                  modalidadeController.text = valorSelecionado!;
                  _atualizarValor();
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: frequencia,
              decoration: InputDecoration(labelText: 'Frequência'),
              items: ['1x por semana', '2x por semana']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (valorSelecionado) {
                setState(() {
                  frequencia = valorSelecionado;
                  _atualizarValor();
                });
              },
            ),
            Row(
              children: [
                Expanded(
                  child: Text(inicio == null ? 'Início: --/--/----' : 'Início: ${_formatarData(inicio!)}'),
                ),
                TextButton(
                  onPressed: () async {
                    final data = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (data != null) {
                      setState(() {
                        inicio = data;
                        if (nomePlanoController.text.isNotEmpty) {
                          fim = _calcularFim(inicio!, nomePlanoController.text);
                        }
                      });
                    }
                  },
                  child: Text('Selecionar'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    fim == null ? 'Fim: --/--/----' : 'Fim: ${_formatarData(fim!)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Valor'),
              keyboardType: TextInputType.number,
              onChanged: (v) => valor = double.tryParse(v),
              controller: TextEditingController(
                text: valor?.toStringAsFixed(2) ?? '',
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(onPressed: adicionarPlano, child: Text('Adicionar Plano')),
            Divider(height: 32),
            StreamBuilder<QuerySnapshot>(
              stream: planosRef.orderBy('inicio').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final planos = snapshot.data!.docs;

                if (planos.isEmpty) return Text('Nenhum plano cadastrado');

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: planos.length,
                  itemBuilder: (context, index) {
                    final plano = planos[index];
                    final dados = plano.data() as Map<String, dynamic>;

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(dados['nomePlano']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Modalidade: ${dados['modalidade']}'),
                            Text('Frequência: ${dados['frequencia']}'),
                            Text('Início: ${dados['inicio']}'),
                            Text('Fim: ${dados['fim']}'),
                            Text('Valor: R\$ ${dados['valor'].toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.receipt_long, color: Colors.green),
                              tooltip: 'Gerar Faturas',
                              onPressed: () async {
                                await gerarFaturasParaPlano(
                                  planoId: plano.id,
                                  dados: dados,
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Excluir Plano',
                              onPressed: () => excluirPlano(plano.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
