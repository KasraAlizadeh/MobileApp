import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import '../Services/google_places_service.dart';
import '../Services/location_service.dart';
import '../Services/osm_service.dart';
import 'Wallet/journey.dart';
import 'Wallet/journey_details.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  final GooglePlacesService _placesService = GooglePlacesService();
  final OsmService _osmService = OsmService();

  // Stati locali per evitare i re-build compulsivi dei FutureBuilder
  List<SuggestedCity> _suggestedCities = [];
  bool _isInitialLoading = true;

  // Mappa per salvare le immagini della sezione "Explore" ed evitare il flash
  Map<String, String> _exploreImagesCache = {};
  bool _isExploreLoading = true;

  final List<String> _italianCapitals = [
    'Roma', 'Milano', 'Napoli', 'Torino', 'Palermo', 'Genova', 'Bologna', 'Firenze',
    'Bari', 'Catania', 'Venezia', 'Verona', 'Messina', 'Padova', 'Trieste', 'Brescia',
    'Parma', 'Taranto', 'Prato', 'Modena', 'Reggio Calabria', 'Reggio Emilia', 'Perugia',
    'Ravenna', 'Livorno', 'Cagliari', 'Foggia', 'Rimini', 'Salerno', 'Ferrara', 'Sassari',
    'Latina', 'Monza', 'Siracusa', 'Pescara', 'Bergamo', 'Forlì', 'Trento', 'Vicenza',
    'Terni', 'Bolzano', 'Novara', 'Piacenza', 'Ancona', 'Andria', 'Arezzo', 'Udine',
    'Cesena', 'Lecce', 'Pesaro', 'Barletta', 'Alessandria', 'La Spezia', 'Pistoia', 'Pisa',
    'Catanzaro', 'Lucca', 'Brindisi', 'Treviso', 'Como', 'Marsala', 'Grosseto', 'Varese',
    'Asti', 'Caserta', 'Gela', 'Ragusa', 'Pavia', 'Cremona', 'Lamezia Terme', 'Massa',
    'Viterbo', 'Cosenza', 'Potenza', 'Crotone', 'Savona', 'Matera', 'Olbia', 'Benevento',
    'Agrigento', 'Faenza', 'Cuneo', 'Trapani', 'Nuoro', 'Oristano', 'Enna', 'Isernia',
    'Verbania', 'Biella', 'Lecco', 'Lodi', 'Mantova', 'Sondrio', 'Vercelli', 'Belluno',
    'Rovigo', 'Gorizia', 'Pordenone', 'Imperia', 'Siena', 'Rieti', 'Chieti', 'Avellino',
    'Frosinone', 'Campobasso', 'Aosta'
  ];
  late List<String> _randomCapitals;

  @override
  void initState() {
    super.initState();
    _loadAllPageData();
  }

  // Unico punto di ingresso per caricare i dati in modo sincrono/asincrono controllato
  Future<void> _loadAllPageData() async {
    // 1. Genera le 5 città casuali
    _randomCapitals = (List<String>.from(_italianCapitals)..shuffle()).take(5).toList();

    // 2. Avvia subito il recupero delle immagini per la sezione "Explore"
    _preloadExploreImages();

    // 3. Avvia il recupero delle città suggerite (Posizione + Catania)
    final initialList = await _getSuggestedCities();

    if (mounted) {
      setState(() {
        _suggestedCities = initialList;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isInitialLoading = true;
      _isExploreLoading = true;
      _exploreImagesCache.clear();
    });
    await _loadAllPageData();
  }

  // Pre-carica gli URL della seconda sezione UNA VOLTA SOLA
  Future<void> _preloadExploreImages() async {
    final Map<String, String> tempCache = {};

    await Future.wait(_randomCapitals.map((cityName) async {
      final url = await _placesService.getPlacePhotoUrl(cityName) ?? '';
      tempCache[cityName] = url;
    }));

    if (mounted) {
      setState(() {
        _exploreImagesCache = tempCache;
        _isExploreLoading = false;
      });
    }
  }

  // Caricamento asincrono rapido dei primi blocchi stabili
  Future<List<SuggestedCity>> _getSuggestedCities() async {
    String currentCity = "La tua posizione";

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 3), onTimeout: () => []);

          if (placemarks.isNotEmpty) {
            currentCity = placemarks.first.locality ?? currentCity;
          }
        } catch (e) {
          print("Errore Geocoding: $e");
        }

        // Lanciamo Overpass in background senza await
        _loadNearbyCityAsynchronously(position.latitude, position.longitude, currentCity);
      }
    } catch (e) {
      print("Errore geolocalizzazione rapida: $e");
    }

    final images = await Future.wait([
      _placesService.getPlacePhotoUrl(currentCity),
      _placesService.getPlacePhotoUrl("Catania"),
    ]);

    return [
      SuggestedCity(name: currentCity, imageUrl: images[0] ?? ''),
      SuggestedCity(name: "Sto cercando...", imageUrl: '', isLoading: true),
      SuggestedCity(name: "Catania", imageUrl: images[1] ?? ''),
    ];
  }

  // Task secondario che aggiorna localmente SOLO l'indice 1 del carosello dei suggeriti
  Future<void> _loadNearbyCityAsynchronously(double lat, double lng, String currentCity) async {
    List<String> nearbyRaw = [];
    String nearbyCity = "Milano";

    try {
      nearbyRaw = await _osmService.getNearbyCities(lat, lng, radiusInKm: 25.0);

      nearbyRaw.removeWhere((city) =>
      city.trim().toLowerCase() == currentCity.trim().toLowerCase());

      if (nearbyRaw.isNotEmpty) {
        nearbyRaw.shuffle();
        nearbyCity = nearbyRaw.first;
      } else {
        final localFallbackList = List<String>.from(_italianCapitals)
          ..removeWhere((city) => city.trim().toLowerCase() == currentCity.trim().toLowerCase())
          ..shuffle();
        nearbyCity = localFallbackList.first;
      }
    } catch (e) {
      print("Errore background OSM: $e");
      final localFallbackList = List<String>.from(_italianCapitals)
        ..removeWhere((city) => city.trim().toLowerCase() == currentCity.trim().toLowerCase())
        ..shuffle();
      nearbyCity = localFallbackList.first;
    }

    final imageUrl = await _placesService.getPlacePhotoUrl(nearbyCity) ?? '';

    if (!mounted) return;

    setState(() {
      if (_suggestedCities.length == 3) {
        _suggestedCities[1] = SuggestedCity(name: nearbyCity, imageUrl: imageUrl, isLoading: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home', overflow: TextOverflow.ellipsis),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Suggested Cities
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Text("Suggested for you", style: Theme.of(context).textTheme.titleMedium),
              ),
              SizedBox(
                height: 250,
                child: _isInitialLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestedCities.length,
                  itemBuilder: (context, index) {
                    final SuggestedCity city = _suggestedCities[index];

                    return Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
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
                            if (city.isLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              )
                            else ...[
                              Positioned.fill(child: _buildImageWidgetFromUrl(city.imageUrl)),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                      colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                    ),
                                  ),
                                  child: Text(
                                    city.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(onTap: () => _showCityDescription(context, city.name)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Text("Explore other places", style: Theme.of(context).textTheme.titleMedium),
              ),

              // Section 2: Explore other places (RIVOLUZIONATA: Niente più FutureBuilder, zero flash!)
              SizedBox(
                height: 200,
                child: _isExploreLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemCount: _randomCapitals.length,
                  itemBuilder: (context, index) {
                    final String locationName = _randomCapitals[index];
                    final String imageUrl = _exploreImagesCache[locationName] ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        children: [
                          Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10, offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _buildImageWidgetFromUrl(imageUrl)),
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(onTap: () => _showCityDescription(context, locationName)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            locationName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Text("Still to be visited...", style: Theme.of(context).textTheme.titleMedium),
              ),

              // Section 3: To Be Visited (Usa uno StreamBuilder nativo che gestisce la cache da solo)
              SizedBox(
                height: 200,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('journeys')
                      .where('state', isEqualTo: 'to_be_visited')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text('Error loading data'));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No journeys to be visited'));

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final journey = Journey.fromFirestore(docs[index]);
                        final String locationName = journey.destinations.isNotEmpty ? journey.destinations.first : journey.name;

                        return FutureBuilder<String?>(
                          future: _placesService.getPlacePhotoUrl(locationName), // Legato alla cache interna del Service
                          initialData: '',
                          builder: (context, urlSnapshot) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Column(
                                children: [
                                  Container(
                                    width: 120, height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 10, offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Stack(
                                        children: [
                                          Positioned.fill(child: _buildImageWidgetFromUrl(urlSnapshot.data ?? '')),
                                          Positioned.fill(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(onTap: () => _showJourneyDetails(context, journey)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    locationName,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  void _showJourneyDetails(BuildContext context, Journey journey) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyDetailsPage(existingJourney: journey, isReadOnly: true),
      ),
    );
  }

  void _showCityDescription(BuildContext context, String cityName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String description = await _placesService.getPlaceDescription(cityName);

      if (description.length > 200) {
        final pattern = RegExp(r'\.(?!\d)');
        final match = pattern.firstMatch(description.substring(200));
        if (match != null) {
          description = description.substring(0, 200 + match.start + 1);
        }
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Chiude il loader

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final bool hasSpaces = cityName.contains(' ');
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: hasSpaces
                                ? ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                              child: Text(
                                cityName,
                                style: Theme.of(context).dialogTheme.titleTextStyle,
                                textAlign: TextAlign.center, softWrap: true, maxLines: 2,
                              ),
                            )
                                : Text(
                              cityName,
                              style: Theme.of(context).dialogTheme.titleTextStyle,
                              textAlign: TextAlign.center, maxLines: 1,
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      description,
                      style: Theme.of(context).dialogTheme.contentTextStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text("Cool!"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      print("Errore nel recupero della descrizione: $e");
    }
  }

  Widget _buildImageWidgetFromUrl(String url) {
    if (url.isEmpty) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }
}

class SuggestedCity {
  final String name;
  final String imageUrl;
  final bool isLoading;

  SuggestedCity({
    required this.name,
    required this.imageUrl,
    this.isLoading = false,
  });
}