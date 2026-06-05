import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Models/destination.dart';
// import '../Services/google_places_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<String> _getImageUrl(String imagePath) async {
    try {
      return await FirebaseStorage.instance.ref(imagePath).getDownloadURL();
    } catch (e) {
      debugPrint('Error fetching image $imagePath: $e');
      return '';
    }
  }

  // Future<void> _addNewDestination(String name) async {
  //   final cleanName = name.split(',')[0];
  //
  //   await FirebaseFirestore.instance.collection('destinations').add({
  //     'name': cleanName,
  //     'description': 'Destinazione programmata tramite Google Places API.',
  //     'state': DestinationState.toBeVisited.value,
  //     'image': 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800',
  //   });
  // }

  @override
  Widget build(BuildContext context) {

    //final GooglePlacesService placesService = GooglePlacesService();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Home'),
            SizedBox(width: 8,),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            //   child: SearchAnchor(
            //     builder: (BuildContext context, SearchController controller) {
            //       return SearchBar(
            //         controller: controller,
            //         padding: const WidgetStatePropertyAll<EdgeInsets>(
            //           EdgeInsets.symmetric(horizontal: 16.0),
            //         ),
            //         onTap: () {
            //           controller.openView(); // Apre la schermata di suggerimento quando si clicca
            //         },
            //         onChanged: (_) {
            //           controller.openView();
            //         },
            //         leading: const Icon(Icons.search),
            //         hintText: 'Cerca una città in Italia...',
            //       );
            //     },
            //     suggestionsBuilder: (BuildContext context, SearchController controller) async {
            //       if (controller.text.length < 3) {
            //         return const [
            //           Center(
            //             child: Padding(
            //               padding: EdgeInsets.all(16.0),
            //               child: Text('Digita almeno 3 caratteri...'),
            //             ),
            //           )
            //         ];
            //       }
            //
            //       final results = await placesService.getSuggestions(controller.text);
            //
            //       return results.map((place) => ListTile(
            //         leading: const Icon(Icons.location_city),
            //         title: Text(place['description']),
            //         onTap: () async {
            //           controller.closeView(place['description']);
            //
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             SnackBar(content: Text('Aggiungo ${place['description']}...')),
            //           );
            //
            //           await _addNewDestination(place['description']);
            //         },
            //       )).toList();
            //     },
            //   ),
            // ),
            // Section 1: Visited (Rectangles)
            SizedBox(
              height: 250,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinations')
                    .where('state', isEqualTo: DestinationState.visited.value)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text('No visited destinations found'));
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final destination = Destination.fromFirestore(
                        docs[index].id,
                        docs[index].data() as Map<String, dynamic>,
                      );

                      return FutureBuilder<String>(
                        future: _getImageUrl(destination.image),
                        builder: (context, urlSnapshot) {
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
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _buildImageWidget(urlSnapshot),
                                  ),
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          _showDestinationDetails(context, destination);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
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
            
            // Section 2: Not Visited
            SizedBox(
              height: 200, // Increased height to accommodate labels better
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinations')
                    .where('state', isEqualTo: DestinationState.notVisited.value)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text('No places found'));
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final destination = Destination.fromFirestore(
                        docs[index].id,
                        docs[index].data() as Map<String, dynamic>,
                      );

                      return FutureBuilder<String>(
                        future: _getImageUrl(destination.image),
                        builder: (context, urlSnapshot) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Column(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
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
                                  ),
                                  child: ClipOval(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _buildImageWidget(urlSnapshot),
                                        ),
                                        Positioned.fill(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                _showDestinationDetails(context, destination);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  destination.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Text(
                "Still to be visited...",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            // Section 3: To Be Visited
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('destinations')
                    .where('state', isEqualTo: DestinationState.toBeVisited.value)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text('No destinations to be visited'));
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final destination = Destination.fromFirestore(
                        docs[index].id,
                        docs[index].data() as Map<String, dynamic>,
                      );

                      return FutureBuilder<String>(
                        future: _getImageUrl(destination.image),
                        builder: (context, urlSnapshot) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Column(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
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
                                  ),
                                  child: ClipOval(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _buildImageWidget(urlSnapshot),
                                        ),
                                        Positioned.fill(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                _showDestinationDetails(context, destination);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  destination.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDestinationDetails(BuildContext context, Destination destination) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                destination.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Chiudi'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(AsyncSnapshot<String> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    final String path = snapshot.data!;

    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }
}
