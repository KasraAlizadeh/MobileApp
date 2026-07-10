import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
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

  List<SuggestedCity> _suggestedCities = [];
  bool _isInitialLoading = true;
  bool _locationDenied = false;

  final Map<String, String> _exploreImagesCache = {};
  bool _isExploreLoading = true;
  List<String> _randomCapitals = [];

  static const List<String> _italianCapitals = [
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

  @override
  void initState() {
    super.initState();
    _loadAllPageData(requestActivation: false);
  }

  Future<void> _loadAllPageData({bool requestActivation = true}) async {
    _randomCapitals = (List<String>.from(_italianCapitals)..shuffle()).take(5).toList();
    final preloadTask = _preloadExploreImages();

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

    final results = await Future.wait([_getSuggestedCities(), preloadTask]);

    if (!mounted) return;

    final initialList = results[0] as List<SuggestedCity>;
    setState(() {
      _locationDenied = false;
      _suggestedCities = initialList;
      _isInitialLoading = false;
    });
  }

  Future<bool> _checkLocationPermission({bool requestActivation = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (requestActivation) await Geolocator.openLocationSettings();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (requestActivation) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }

      if (permission == LocationPermission.deniedForever) {
        if (requestActivation) await Geolocator.openAppSettings();
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
      _isExploreLoading = true;
      _exploreImagesCache.clear();
    });
    _placesService.clearCache();
    await _loadAllPageData();
  }

  Future<void> _preloadExploreImages() async {
    final Map<String, String> imageTempCache = {};
    await Future.wait(_randomCapitals.map((cityName) async {
      final url = await _placesService.getPlacePhotoUrl(cityName);
      imageTempCache[cityName] = url ?? '';
    }));

    if (!mounted) return;
    setState(() {
      _exploreImagesCache.addAll(imageTempCache);
      _isExploreLoading = false;
    });
  }

  Future<List<SuggestedCity>> _getSuggestedCities() async {
    String currentCity = "Your position";

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
          debugPrint("Geocoding error: $e");
        }
        _loadNearbyCityAsynchronously(position.latitude, position.longitude, currentCity);
      }
    } catch (e) {
      debugPrint("Localization error: $e");
    }

    final imageUrl = await _placesService.getPlacePhotoUrl(currentCity);
    return [
      SuggestedCity(name: currentCity, imageUrl: imageUrl ?? '', subtitle: "Where am I?"),
      SuggestedCity(name: "Loading...", imageUrl: '', isLoading: true, subtitle: "Explore nearby"),
    ];
  }

  Future<void> _loadNearbyCityAsynchronously(double lat, double lng, String currentCity) async {
    List<String> nearbyRaw = [];
    String nearbyCity = "Milano";

    try {
      nearbyRaw = await _osmService.getNearbyCities(lat, lng, radiusInKm: 25.0);
      nearbyRaw.removeWhere((city) => city.trim().toLowerCase() == currentCity.trim().toLowerCase());

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
      debugPrint("OSM Background error: $e");
      final localFallbackList = List<String>.from(_italianCapitals)
        ..removeWhere((city) => city.trim().toLowerCase() == currentCity.trim().toLowerCase())
        ..shuffle();
      nearbyCity = localFallbackList.first;
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
        );
      }
    });
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
      final data = await _placesService.getCityStats(cityName);
      String description = data['stats'] ?? '';

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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LayoutBuilder(
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
                        ],
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: description.split('\n').map((line) {
                        if (line.trim().isEmpty) return const SizedBox(height: 10);

                        final parts = line.split(':');
                        if (parts.length < 2) {
                          return Text(line, style: Theme.of(context).dialogTheme.contentTextStyle);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${parts[0]}:',
                                  style: Theme.of(context).dialogTheme.contentTextStyle?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: parts.sublist(1).join(':'),
                                  style: Theme.of(context).dialogTheme.contentTextStyle,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }).toList(),
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
      debugPrint("Error showing city description: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text("Enable Location", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("To give you the best experience, we need to know where you are.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _isInitialLoading = true);
                    await _loadAllPageData(requestActivation: true);
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text("Allow Access"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Home', overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Suggested Cities (Anti-glitch smooth transition)
              SizedBox(
                height: 250,
                child: ListView.builder(
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
                            child: Text(city.subtitle!, style: Theme.of(context).textTheme.titleMedium),
                          ),
                        Expanded(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.4,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              // AnimatedSwitcher guarantees a cross-fade transition when isLoading changes
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeIn,
                                switchOutCurve: Curves.easeOut,
                                child: city.isLoading
                                    ? Container(
                                  key: const ValueKey('loading_container'),
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                    : Stack(
                                  key: ValueKey('city_container_${city.name}'),
                                  children: [
                                    Positioned.fill(child: _buildImageWidgetFromUrl(city.imageUrl)),
                                    Positioned(
                                      bottom: 0, left: 0, right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _showCityDescription(context, city.name),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))]
                            ),
                            child: ClipOval(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _buildImageWidgetFromUrl(imageUrl)),
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _showCityDescription(context, locationName),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(locationName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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

              // Section 3: To Be Visited (Anti-glitch optimized)
              SizedBox(
                height: 150,
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

                        // Optimization: Check the cache synchronously first to prevent the FutureBuilder flash!
                        final String lookupKey = locationName.trim().toLowerCase();
                        final bool isCached = _placesService.isPhotoCached(lookupKey);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Column(
                            children: [
                              Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))]
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: isCached
                                            ? _buildImageWidgetFromUrl(_placesService.getCachedPhotoUrl(lookupKey) ?? '')
                                            : FutureBuilder<String?>(
                                          future: _placesService.getPlacePhotoUrl(locationName),
                                          builder: (context, urlSnapshot) {
                                            // Smooth transition if it's fetching for the first time
                                            if (urlSnapshot.connectionState == ConnectionState.waiting) {
                                              return Container(color: Colors.grey[200]);
                                            }
                                            return _buildImageWidgetFromUrl(urlSnapshot.data ?? '');
                                          },
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _showJourneyDetails(context, journey),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(locationName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
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

  Widget _buildImageWidgetFromUrl(String url) {
    if (url.isEmpty) return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    return CachedNetworkImage(
      imageUrl: url, fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }
}

class SuggestedCity {
  final String name;
  final String imageUrl;
  final bool isLoading;
  final String? subtitle;
  SuggestedCity({required this.name, required this.imageUrl, this.isLoading = false, this.subtitle});
}