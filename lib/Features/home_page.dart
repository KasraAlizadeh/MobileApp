import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final List<Map<String, String>> destinations = [
    {
      'name': 'Torino',
      'image': 'assets/images/torino.jpeg',
    },
    {
      'name': 'Milano',
      'image': 'assets/images/milano-piazza-del-duomo.jpg',
    },
    {
      'name': 'Roma',
      'image': 'assets/images/roma.png',
    },
  ];

  final List<Map<String, String>> other_places = [
    {
      'name': 'Venezia',
      'image': 'assets/images/venezia.jpg',
    },
    {
      'name': 'Napoli',
      'image': 'assets/images/napoli.jpg',
    },
    {
      'name': 'Bologna',
      'image': 'assets/images/bologna.jpg',
    },
    {
      'name': 'Genova',
      'image': 'assets/images/genova.jpg',
    },
    {
      'name': 'Firenze',
      'image': 'assets/images/firenze.jpg',
    },
    {
      'name': 'Bari',
      'image': 'assets/images/bari.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Text('Home'),
            SizedBox(width: 8,),
            Icon(Icons.airplanemode_active, color: Colors.black, size: 30,),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 250,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  return Container(
                    width: MediaQuery.of(context).size.width * 0.4,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      image: DecorationImage(
                        image: AssetImage(destination['image']!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(destination['name']!),
                              duration: const Duration(milliseconds: 500),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Text(
                "Explore other places",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Container(
              height: 250,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary, // Il verde del tuo tema
                borderRadius: BorderRadius.circular(25),      // Bordi curvi
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.map_outlined,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}