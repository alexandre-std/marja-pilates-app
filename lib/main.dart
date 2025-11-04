import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'lista_clientes.dart';
import 'resumo_financeiro_page.dart';
//import 'teste_comprovante_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('pt_BR', null);
  runApp(PilatesApp());
}

class PilatesApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pilates App',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: CadastroCliente(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('pt', 'BR'),
        const Locale('en', 'US'),
      ],
    );
  }
}

class CadastroCliente extends StatefulWidget {
  @override
  State<CadastroCliente> createState() => _CadastroClienteState();
}

class _CadastroClienteState extends State<CadastroCliente> {
  final nomeController = TextEditingController();
  final dtNascimentoController = TextEditingController();
  final cpfController = TextEditingController();
  final telefoneController = TextEditingController();

  @override
  void dispose() {
    nomeController.dispose();
    dtNascimentoController.dispose();
    cpfController.dispose();
    telefoneController.dispose();
    super.dispose();
  }

  void salvarCliente(BuildContext context) async {
    final nome = nomeController.text.trim();
    final telefone = telefoneController.text.replaceAll(RegExp(r'\D'), '');
    final cpf = cpfController.text.replaceAll(RegExp(r'\D'), '');
    final dataTexto = dtNascimentoController.text.trim();

    if (nome.isEmpty || telefone.isEmpty || cpf.isEmpty || dataTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha todos os campos obrigatórios')),
      );
      return;
    }

    if (cpf.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CPF deve ter exatamente 11 dígitos')),
      );
      return;
    }

    DateTime? dataNascimento;
    try {
      dataNascimento = DateFormat('dd/MM/yyyy').parseStrict(dataTexto);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data de nascimento inválida')),
      );
      return;
    }

    final consulta = await FirebaseFirestore.instance
        .collection('clientes')
        .where('cpf', isEqualTo: cpf)
        .get();

    if (consulta.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CPF já cadastrado')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('clientes').add({
      'nome': nome,
      'telefone': telefone,
      'cpf': cpf,
      'dataNascimento': DateFormat('dd/MM/yyyy').format(dataNascimento),
      'dataCadastro': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cliente cadastrado com sucesso!')),
    );

    limparCampos();
  }

  void limparCampos() {
    nomeController.clear();
    telefoneController.clear();
    cpfController.clear();
    dtNascimentoController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cadastro de Cliente')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(controller: nomeController, decoration: InputDecoration(labelText: 'Nome')),
            TextFormField(
              controller: telefoneController,
              decoration: InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              controller: cpfController,
              decoration: InputDecoration(labelText: 'CPF'),
              keyboardType: TextInputType.number,
            ),
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
              onPressed: () => salvarCliente(context),
              child: Text('Cadastrar'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: limparCampos,
              child: Text('Limpar campos'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListaClientes()),
                );
              },
              child: Text('Ver clientes cadastrados'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ResumoFinanceiroPage()),
                );
              },
              child: Text('Resumo Financeiro'),
            ),
            /*ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TesteComprovantePage()),
                );
              },
              child: Text('Testar envio de comprovante'),
            ),*/
          ],
        ),
      ),
    );
  }
}
