import 'package:flutter/material.dart';
import 'comprovante_pdf.dart'; // Ajuste o caminho se necessário

class TesteComprovantePage extends StatelessWidget {
  const TesteComprovantePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Teste de Comprovante')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              await gerarComprovantePDF(
                nome: 'Sandra Oliveira',
                valor: 684.18,
                servico: 'Pilates',
                dataPagamento: DateTime.now(),
                parcela: 2,
                totalParcelas: 12,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Comprovante gerado e compartilhado')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro: $e')),
              );
            }
          },
          child: Text('Testar envio de comprovante'),
        ),
      ),
    );
  }
}
