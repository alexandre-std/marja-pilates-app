import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditarClientePage extends StatefulWidget {
  final DocumentSnapshot cliente;

  EditarClientePage({required this.cliente});

  @override
  State<EditarClientePage> createState() => _EditarClientePageState();
}

class _EditarClientePageState extends State<EditarClientePage> {
  late final TextEditingController nomeController;
  late final TextEditingController telefoneController;
  late final TextEditingController cpfController;
  late final TextEditingController dtNascimentoController;

  @override
  void initState() {
    super.initState();
    final dados = widget.cliente.data() as Map<String, dynamic>;
    nomeController = TextEditingController(text: dados['nome'] ?? '');
    telefoneController = TextEditingController(text: dados['telefone'] ?? '');
    cpfController = TextEditingController(text: dados['cpf'] ?? '');
    dtNascimentoController = TextEditingController(text: dados['dataNascimento'] ?? '');
  }

  @override
  void dispose() {
    nomeController.dispose();
    telefoneController.dispose();
    cpfController.dispose();
    dtNascimentoController.dispose();
    super.dispose();
  }

  Future<void> atualizarCliente() async {
    final nome = nomeController.text.trim();
    final telefone = telefoneController.text.replaceAll(RegExp(r'\D'), '');
    final cpf = cpfController.text.replaceAll(RegExp(r'\D'), '');
    final dataTexto = dtNascimentoController.text.trim();

    if (nome.isEmpty || telefone.isEmpty || cpf.isEmpty || dataTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha todos os campos')),
      );
      return;
    }

    if (cpf.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CPF deve ter 11 dígitos')),
      );
      return;
    }

    try {
      DateFormat('dd/MM/yyyy').parseStrict(dataTexto);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data de nascimento inválida')),
      );
      return;
    }

    final clienteRef = widget.cliente.reference;
    final clienteId = clienteRef.id;

    // Atualiza o documento principal
    await clienteRef.update({
      'nome': nome,
      'telefone': telefone,
      'cpf': cpf,
      'dataNascimento': dataTexto,
    });

    // Atualiza o nome nos planos
    final planos = await clienteRef.collection('planos').get();
    for (final plano in planos.docs) {
      await plano.reference.update({'nome': nome});
    }

    // Atualiza o nome nas faturas da subcoleção
    final faturasSub = await clienteRef.collection('faturas').get();
    for (final fatura in faturasSub.docs) {
      await fatura.reference.update({
        'nome': nome,
        'cliente': nome,
      });
    }

    // Atualiza o nome nas faturas da coleção raiz
    final faturasRaiz = await FirebaseFirestore.instance
        .collection('faturas')
        .where('clienteId', isEqualTo: clienteId)
        .get();

    for (final fatura in faturasRaiz.docs) {
      await fatura.reference.update({
        'nome': nome,
        'cliente': nome,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cliente atualizado com sucesso')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Cliente')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(controller: nomeController, decoration: InputDecoration(labelText: 'Nome')),
            TextFormField(controller: telefoneController, decoration: InputDecoration(labelText: 'Telefone')),
            TextFormField(controller: cpfController, decoration: InputDecoration(labelText: 'CPF')),
            TextFormField(
              controller: dtNascimentoController,
              decoration: InputDecoration(
                labelText: 'Data Nascimento',
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () async {
                    final data = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (data != null) {
                      dtNascimentoController.text = DateFormat('dd/MM/yyyy').format(data);
                    }
                  },
                ),
              ),
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: atualizarCliente,
              child: Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );
  }
}
