import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget{
  ProfilePage({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Profile'),
          ],
        ),
      ),
    );
  }
}