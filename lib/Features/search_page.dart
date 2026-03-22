import 'package:flutter/material.dart';

class SearchPage extends StatelessWidget{
  SearchPage({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Search'),
          ],
        ),
      ),
    );
  }
}