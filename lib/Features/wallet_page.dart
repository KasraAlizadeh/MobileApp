import 'package:flutter/material.dart';

class WalletPage extends StatelessWidget{
  WalletPage({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Wallet'),
          ],
        ),
      ),
    );
  }
}