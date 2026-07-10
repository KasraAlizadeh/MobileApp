import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import '../../Services/google_places_service.dart';
import '../../Services/location_service.dart';
import '../../Services/osm_service.dart';
import '../Wallet/journey.dart';
import '../Wallet/journey_details.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  final GooglePlacesService _placesService = GooglePlacesService();
  final OsmService _osmService = OsmService();

  late Stream<QuerySnapshot> _journeyStream;
  List<SuggestedCity> _suggestedCities = [];
  bool _isInitialLoading = true;
  bool _locationDenied = false;

  Map<String, String> _exploreImagesCache = {};
  Map<String, String> _exploreGeoCache = {};
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
    _journeyStream = FirebaseFirestore.instance
        .collection('journeys')
        .where('state', isEqualTo: 'to_be_visited')
        .snapshots();
    _loadAllPageData(requestActivation: false); // Silenzioso all'avvio
  }

  Future<void> _loadAllPageData({bool requestActivation = true}) async {
    _randomCapitals = (List<String>.from(_italianCapitals)..shuffle()).take(5).toList();
    
    // Avviamo il pre-caricamento delle immagini in parallelo
    final preloadTask = _preloadExploreImages();
    
    // Controlliamo i permessi
    bool hasPermission = await _checkLocationPermission(requestActivation: requestActivation);
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _locationDenied = true;
          _isInitialLoading = false;
        });
      }
      return;
    }

    // Aspettiamo che entrambi i task (posizione e immagini esplora) siano completati
    final results = await Future.wait([
      _getSuggestedCities(),
      preloadTask,
    ]);

    final initialList = results[0] as List<SuggestedCity>;

    if (mounted) {
      setState(() {
        _locationDenied = false;
        _suggestedCities = initialList;
        _isInitialLoading = false;
      });
    }
  }

  Future<bool> _checkLocationPermission({bool requestActivation = true}) async {
    try {
      // 1. Controlla se il servizio di localizzazione è attivo
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (requestActivation) {
          await Geolocator.openLocationSettings();
        }
        return false; 
      }

      // 2. Controlla i permessi dell'app
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (requestActivation) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied) return false;
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (requestActivation) {
          await Geolocator.openAppSettings();
        }
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
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

  Future<void> _preloadExploreImages() async {
    final Map<String, String> tempCache = {};
    final Map<String, String> tempGeoCache = {};

    await Future.wait(_randomCapitals.map((cityName) async {
      // Fetch photo and location info in parallel
      final results = await Future.wait([
        _placesService.getPlacePhotoUrl(cityName),
        locationFromAddress(cityName).timeout(const Duration(seconds: 2), onTimeout: () => []),
      ]);

      tempCache[cityName] = (results[0] as String?) ?? '';
      
      final locations = results[1] as List<Location>;
      if (locations.isNotEmpty) {
        try {
          final placemarks = await placemarkFromCoordinates(
            locations.first.latitude,
            locations.first.longitude,
          ).timeout(const Duration(seconds: 2), onTimeout: () => []);
          
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final region = p.administrativeArea ?? '';
            final province = p.subAdministrativeArea ?? '';
            tempGeoCache[cityName] = region.isNotEmpty && province.isNotEmpty 
                ? "$province ($region)" 
                : (region.isNotEmpty ? region : province);
          }
        } catch (_) {}
      }
    }));

    if (mounted) {
      setState(() {
        _exploreImagesCache = tempCache;
        _exploreGeoCache = tempGeoCache;
        _isExploreLoading = false;
      });
    }
  }

  Future<List<SuggestedCity>> _getSuggestedCities() async {
    String currentCity = "Your position";
    String? currentRegion;
    String? currentProvince;

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 3), onTimeout: () => []);

          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            currentCity = p.locality ?? currentCity;
            currentRegion = p.administrativeArea;
            currentProvince = p.subAdministrativeArea;
          }
        } catch (e) {
          print("Geocoding error: $e");
        }

        _loadNearbyCityAsynchronously(position.latitude, position.longitude, currentCity);
      }
    } catch (e) {
      print("Fast localization error: $e");
    }

    final images = await Future.wait([
      _placesService.getPlacePhotoUrl(currentCity),
    ]);

    return [
      SuggestedCity(
        name: currentCity,
        imageUrl: images[0] ?? '',
        subtitle: "Where am I?",
        region: currentRegion,
        province: currentProvince,
      ),
      SuggestedCity(
        name: "Loading...",
        imageUrl: '',
        isLoading: true,
        subtitle: "Explore nearby",
      ),
    ];
  }

  // Task secondario che aggiorna localmente SOLO l'indice 1 del carosello dei suggeriti
  Future<void> _loadNearbyCityAsynchronously(double lat, double lng, String currentCity) async {
    List<String> nearbyRaw = [];
    String nearbyCity = "Milano";
    String? nearbyRegion;
    String? nearbyProvince;

    try {
      nearbyRaw = await _osmService.getNearbyCities(lat, lng, radiusInKm: 25.0);

      nearbyRaw.removeWhere((city) =>
      city.trim().toLowerCase() == currentCity.trim().toLowerCase());

      if (nearbyRaw.isNotEmpty) {
        nearbyRaw.shuffle();
        nearbyCity = nearbyRaw.first;
      } else {
        nearbyCity = "Milano";
      }

      // Fetch geo info for the nearby city
      final locations = await locationFromAddress(nearbyCity).timeout(const Duration(seconds: 2), onTimeout: () => []);
      if (locations.isNotEmpty) {
        final placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        ).timeout(const Duration(seconds: 2), onTimeout: () => []);
        if (placemarks.isNotEmpty) {
          nearbyRegion = placemarks.first.administrativeArea;
          nearbyProvince = placemarks.first.subAdministrativeArea;
        }
      }
    } catch (e) {
      print("Errore background OSM: $e");
    }

    final imageUrl = await _placesService.getPlacePhotoUrl(nearbyCity) ?? '';

    if (!mounted) return;

    setState(() {
      if (_suggestedCities.length == 2) {
        _suggestedCities[1] = SuggestedCity(
          name: nearbyCity,
          imageUrl: imageUrl,
          isLoading: false,
          subtitle: "Explore nearby",
          region: nearbyRegion,
          province: nearbyProvince,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mentre carica la prima volta o se la posizione è negata, non mostriamo la struttura della Home
    if (_isInitialLoading || _locationDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: _isInitialLoading 
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Enable Location",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "To give you the best experience, we need to know where you are.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _isInitialLoading = true);
                        await _loadAllPageData(requestActivation: true);
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text("Allow Access"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home', overflow: TextOverflow.ellipsis),
      ),
      //To activate when you don't want to load the images
      /*
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              "Home Placeholder",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text("Content is currently hidden", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      */
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Suggested Cities
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

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (city.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              city.subtitle!,
                              style: Theme.of(context).textTheme.titleMedium
                            ),
                          ),
                        Expanded(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.4,
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
                                    Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(color: Colors.white),
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
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
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Text("Explore other places", style: Theme.of(context).textTheme.titleMedium),
              ),

              // Section 2: Explore other places
              SizedBox(
                height: 150,
                child: _isExploreLoading
                    ? ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Column(
                            children: [
                              Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: 120, height: 120,
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(width: 60, height: 12, color: Colors.grey[300]),
                            ],
                          ),
                        ),
                      )
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

              // Section 3: To Be Visited
              SizedBox(
                height: 150,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _journeyStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text('Error loading data'));
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              width: 120, height: 120,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No journeys to be visited'));

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final journey = Journey.fromFirestore(docs[index]);
                        return _JourneyCircleItem(
                          journey: journey, 
                          placesService: _placesService,
                          onTap: () => _showJourneyDetails(context, journey),
                          imageBuilder: _buildImageWidgetFromUrl,
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
      String description = await _placesService.getCityStats(cityName);

      if (!context.mounted) return;
      Navigator.pop(context);

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
      return Container(
        color: Colors.grey[200],
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 500),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(color: Colors.white),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.error_outline, color: Colors.grey),
      ),
    );
  }
}

class SuggestedCity {
  final String name;
  final String imageUrl;
  final bool isLoading;
  final String? subtitle;
  final String? region;
  final String? province;

  SuggestedCity({
    required this.name,
    required this.imageUrl,
    this.isLoading = false,
    this.subtitle,
    this.region,
    this.province,
  });
}

class _JourneyCircleItem extends StatefulWidget {
  final Journey journey;
  final GooglePlacesService placesService;
  final VoidCallback onTap;
  final Widget Function(String) imageBuilder;

  const _JourneyCircleItem({
    required this.journey,
    required this.placesService,
    required this.onTap,
    required this.imageBuilder,
  });

  @override
  State<_JourneyCircleItem> createState() => _JourneyCircleItemState();
}

class _JourneyCircleItemState extends State<_JourneyCircleItem> {
  late Future<String?> _imageFuture;
  late String _locationName;

  @override
  void initState() {
    super.initState();
    _locationName = widget.journey.destinations.isNotEmpty 
        ? widget.journey.destinations.first 
        : widget.journey.name;
    _imageFuture = widget.placesService.getPlacePhotoUrl(_locationName);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _imageFuture,
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
                      Positioned.fill(child: widget.imageBuilder(urlSnapshot.data ?? '')),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(onTap: widget.onTap),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _locationName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}
