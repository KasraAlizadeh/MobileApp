import 'package:flutter/material.dart';

class HomePage extends StatelessWidget{
  HomePage({super.key});



  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Text('Home'),
            SizedBox(width: 8,),
            Icon(Icons.airplanemode_active, color: Colors.black,),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Mano'),
          ],
        ),
      ),
    );
  }
}