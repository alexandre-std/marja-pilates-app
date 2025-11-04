import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'planos_cliente_page.dart';
import 'faturas_cliente_page.dart';
import 'editar_cliente_page.dart'; // ✅ nova importação

class ListaClientes extends StatefulWidget {
  @override
  State<ListaClientes> createState() => _ListaClientesState();
}

class _ListaClientesState extends State<ListaClientes> {
  final nomeController = TextEditingController();
  final cpfController = TextEditingController();
  final nascimentoController = TextEditingController();
  String? modalidadeFiltro;

  List<DocumentSnapshot> todosClientes = [];
  List<DocumentSnapshot> clientesFiltrados = [];

  @override
  void initState() {
    super.initState();
    carregarClientes();
    nomeController.addListener(_filtrar);
    cpfController.addListener(_filtrar);
    nascimentoController.addListener(_filtrar);
  }

  Future<void> carregarClientes() async {
    final snapshot = await FirebaseFirestore.instance.collection('clientes').get();
    todosClientes = snapshot.docs;
    _filtrar();
  }

  void _filtrar() async {
    final nome = nomeController.text.toLowerCase();
    final cpf = cpfController.text;
    final nascimento = nascimentoController.text;

    final tarefas = todosClientes.map((cliente) async {
      final dados = cliente.data() as Map<String, dynamic>;
      final nomeCliente = dados['nome']?.toLowerCase() ?? '';
      final cpfCliente = dados['cpf'] ?? '';
      final nascimentoCliente = dados['dataNascimento'] ?? '';

      final nomeConfere = nome.isEmpty || nomeCliente.contains(nome);
      final cpfConfere = cpf.isEmpty || cpfCliente.contains(cpf);
      final nascimentoConfere = nascimento.isEmpty || nascimentoCliente.contains(nascimento);

      if (nomeConfere && cpfConfere && nascimentoConfere) {
        if (modalidadeFiltro == null || modalidadeFiltro!.isEmpty) {
          return cliente;
        }

        final planosRef = cliente.reference.collection('planos');
        final planosSnapshot = await planosRef.get();

        final temModalidade = planosSnapshot.docs.any((plano) {
          final dadosPlano = plano.data() as Map<String, dynamic>;
          return dadosPlano['modalidade'] == modalidadeFiltro;
        });

        if (temModalidade) {
          return cliente;
        }
      }

      return null;
    }).toList();

    final resultados = await Future.wait(tarefas);
    final filtrados = resultados.whereType<DocumentSnapshot>().toList();

    setState(() {
      clientesFiltrados = filtrados;
    });
  }

  void excluirCliente(String id) async {
    final planosSnapshot = await FirebaseFirestore.instance
        .collection('clientes')
        .doc(id)
        .collection('planos')
        .get();

    if (planosSnapshot.docs.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exclusão não permitida'),
          content: Text('Este cliente possui planos cadastrados e não pode ser excluído.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir este cliente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Excluir')),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance.collection('clientes').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cliente excluído')));
      carregarClientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Clientes Cadastrados')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: nomeController,
                  decoration: InputDecoration(labelText: 'Filtrar por nome'),
                ),
                TextField(
                  controller: cpfController,
                  decoration: InputDecoration(labelText: 'Filtrar por CPF'),
                ),
                TextField(
                  controller: nascimentoController,
                  decoration: InputDecoration(labelText: 'Filtrar por nascimento'),
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Filtrar por modalidade'),
                  items: ['Pilates Solo', 'Pilates Aparelho']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    modalidadeFiltro = v;
                    _filtrar();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: clientesFiltrados.isEmpty
                ? Center(child: Text('Nenhum cliente encontrado'))
                : ListView.builder(
              itemCount: clientesFiltrados.length,
              itemBuilder: (context, index) {
                final cliente = clientesFiltrados[index];
                final dados = cliente.data() as Map<String, dynamic>;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dados['nome'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('CPF: ${dados['cpf']}'),
                              Text('Telefone: ${dados['telefone']}'),
                              Text('Nascimento: ${dados['dataNascimento']}'),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.calendar_month, color: Colors.purple),
                              tooltip: 'Ver Planos',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlanosClientePage(clienteId: cliente.id),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.receipt, color: Colors.teal),
                              tooltip: 'Ver Faturas',
                              onPressed: () {
                                final dados = cliente.data() as Map<String, dynamic>;
                                final nomeCliente = dados['nome'] ?? 'Cliente';

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FaturasClientePage(
                                      clienteId: cliente.id,
                                      nomeCliente: nomeCliente,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange),
                              tooltip: 'Editar Cliente',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditarClientePage(cliente: cliente),
                                  ),
                                ).then((_) => carregarClientes());
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Excluir Cliente',
                              onPressed: () => excluirCliente(cliente.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
