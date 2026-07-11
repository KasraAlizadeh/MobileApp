import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../Services/notification_service.dart';
import 'journey.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class JourneyDetailsPage extends StatefulWidget {
  final Journey? existingJourney; // If null, we are ADDING. If not null, we are EDITING, simple bro!
  final bool isReadOnly;
  const JourneyDetailsPage({
    super.key,
    this.existingJourney,
    this.isReadOnly = false,
  });
  @override
  State<JourneyDetailsPage> createState() => _JourneyDetailsPageState();
}

class _JourneyDetailsPageState extends State<JourneyDetailsPage> {
  TextEditingController _nameController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _visaController = TextEditingController();
  final TextEditingController _ticketController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<String> _transportModes = ['Airline', 'Train', 'Taxi', 'Metro', 'Bus', 'Ship'];
  final List<Map<String, dynamic>> _extraDocs = [{'name': TextEditingController(), 'fileName': 'No file selected'}];
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String _selectedType = 'Travel Type';
  File? _newVisaFile, _newTicketFile, _newInsuranceFile;
  List<String> _italianCities = [];
  bool _isCitiesLoading = true;
  List<String> _finalPdfUrls = ["", "", ""]; // IN ORDER [Visa, Ticket, Insurance]
  List<String> _existingPhotoUrls = []; // Track photos fetched from Firestore
  List<File> _newPhotosToUpload = [];   // Track new photos selected in this session
  List<String> pdfUrls = [];
  List<TextEditingController> _destControllers = [TextEditingController()];
  List<Map<String, dynamic>> _transportRows = [{'mode': 'Airline', 'controller': TextEditingController()}];
  List<Map<String, dynamic>> _accommodationRows = [
    {
      'hotelName': TextEditingController(),
      'address': TextEditingController(),
      'stayAt': 'Primary Destination',
    }
  ];
  List<Map<String, dynamic>> _activityRows = [
    {'activity': TextEditingController(), 'place': TextEditingController()}
  ];
  List<String> _extractText(List<TextEditingController> controllers) {
    return controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }
  List<Map<String, dynamic>> _extractRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final Map<String, dynamic> cleanRow = {};
      row.forEach((key, value) {
        if (value is TextEditingController) {
          cleanRow[key] = value.text.trim();
        } else {
          cleanRow[key] = value;
        }
      });
      return cleanRow;
    }).toList();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, bool isStartDate) async {
    DateTime now = DateTime.now();

    // Default initial calendar view context setup
    DateTime initialDate = now;
    DateTime firstSelectableDate = now;

    if (isStartDate) {
      // Start date can only be selected from TODAY onwards - no time travelling
      firstSelectableDate = DateTime(now.year, now.month, now.day);

      // If there's already a valid date in the text field, keep it as calendar focal point
      if (controller.text.isNotEmpty) {
        try {
          initialDate = DateFormat('yyyy-MM-dd').parse(controller.text);
        } catch (_) {}
      }
    } else {
      // End date depends completely on what was selected for the Start Date- here i try to avoid confusions
      if (_startController.text.isNotEmpty) {
        try {
          DateTime parsedStart = DateFormat('yyyy-MM-dd').parse(_startController.text);
          // The earliest possible end date is now locked to the chosen start dte
          firstSelectableDate = parsedStart;
          initialDate = parsedStart;
        } catch (_) {
          firstSelectableDate = DateTime(now.year, now.month, now.day);
        }
      } else {
        // If they try to choose an end date before picking a start date, giving a reminder to select start date first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a Start Date first! 📅"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // If an end date was already filled, keep it as the default display point
      if (controller.text.isNotEmpty) {
        try {
          DateTime parsedEnd = DateFormat('yyyy-MM-dd').parse(controller.text);
          if (parsedEnd.isAfter(firstSelectableDate) || parsedEnd.isAtSameMomentAs(firstSelectableDate)) {
            initialDate = parsedEnd;
          }
        } catch (_) {}
      }
    }

    // Open the restricted date picker overlay window interface
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstSelectableDate, //this locks out the past dates
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);

        // in case of changing the starting date, user have to refìverify end date
        if (isStartDate && _endController.text.isNotEmpty) {
          try {
            DateTime currentEnd = DateFormat('yyyy-MM-dd').parse(_endController.text);
            if (picked.isAfter(currentEnd)) {
              _endController.clear(); // sfely forces them to pick a valid new end date
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Start date changed! Please re-verify your End Date. 🔄"),
                  backgroundColor: Colors.blueGrey,
                ),

              );
            }
          } catch (_) {}
        }
      });
    }
  }
  Future<void> _pickFile(TextEditingController controller, int index) async {
    // open the file explorer with specific filters
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc'], // Restrict to docs/images
    );

    //check if the user actually picked something
    if (result != null) {
      // Get the file name from the result
      PlatformFile file = result.files.first;

      //update the UI to show the selected file name
      setState(() {
        File pickedFile = File(result.files.single.path!);
        controller.text = result.files.single.name;
        if (index == 0) _newVisaFile = pickedFile;
        if (index == 1) _newTicketFile = pickedFile;
        if (index == 2) _newInsuranceFile = pickedFile;
      });
      print("Selected file path: ${file.path}"); //just for checking
    } else {
      print("User canceled the picker"); //just for checking
    }
  }
  Future<void> _pickExtraDocument(int index) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'docx'],
      );
      if (result != null) {
        setState(() {
          // Update the 'fileName' string in our Map at the specific index
          _extraDocs[index]['fileName'] = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint("File picker error: $e");
    }
  }
  Future<String> _upload(String fileName, File file, String userId, String journeyId, String subFolder) async {

    Reference ref = FirebaseStorage.instance
        .ref()
        .child('media/$userId/$journeyId/$subFolder/$fileName');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
  Future<List<String>> _moveStorageFolder(String oldFolderName, String newFolderName, List<String> currentUrls) async {
    List<String> updatedUrls = List.from(currentUrls);
    List<String> fileNames = ["visa.pdf", "ticket.pdf", "insurance.pdf"];

    for (int i = 0; i < currentUrls.length; i++) {
      if (currentUrls[i].isEmpty) continue;

      try {
        // fetching the point to the old file location
        Reference oldRef = FirebaseStorage.instance.ref().child('pdfs/$oldFolderName/${fileNames[i]}');
        // fetching the point to the new destination file location
        Reference newRef = FirebaseStorage.instance.ref().child('pdfs/$newFolderName/${fileNames[i]}');

        // just down the file into memory as bytes
        final data = await oldRef.getData();
        if (data != null) {
          // upload the bytes to the new folder location prefix
          await newRef.putData(data);
          // grab the new download URL
          updatedUrls[i] = await newRef.getDownloadURL();

          // remove old folder
          await oldRef.delete();
          print("Moved ${fileNames[i]} from folder '$oldFolderName' to '$newFolderName'");
        }
      } catch (e) {
        print("Skipped or failed moving file index $i: $e");
      }
    }
    return updatedUrls;
  }
  Future<void> saveJourney() async {
    setState(() {
      _isSaving = true;
    });
    try {
      String newFolder = _nameController.text.trim();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("No authorized user found!");
      }
      String userId = currentUser.uid;
      String targetJourneyId;
      DocumentReference docRef;
      // check if we are in EDIT mode and if the name actually changed
      if (widget.existingJourney != null) {
        targetJourneyId = widget.existingJourney!.id;
        docRef = FirebaseFirestore.instance.collection('journeys').doc(targetJourneyId);
        String oldFolder = widget.existingJourney!.name;

        if (oldFolder != newFolder) {
          print("🔄 Journey name changed from '$oldFolder' to '$newFolder'. Moving storage files...");
          // xecute the folder move operation for existing files
          _finalPdfUrls = await _moveStorageFolder(oldFolder, newFolder, _finalPdfUrls);
        }
      }else {
        // Create a fresh doc reference beforehand to claim its unique auto-generated ID
        docRef = FirebaseFirestore.instance.collection('journeys').doc();
        targetJourneyId = docRef.id;
      }

      // handle any brand new file uploads picked during this session
      if (_newVisaFile != null) _finalPdfUrls[0] = await _upload("visa.pdf", _newVisaFile!, userId, targetJourneyId, "pdfs");
      if (_newTicketFile != null) _finalPdfUrls[1] = await _upload("ticket.pdf", _newTicketFile!, userId, targetJourneyId, "pdfs");
      if (_newInsuranceFile != null) _finalPdfUrls[2] = await _upload("insurance.pdf", _newInsuranceFile!,userId, targetJourneyId, "pdfs");
      List<String> freshlyUploadedPhotoUrls = [];
      for (int i = 0; i < _newPhotosToUpload.length; i++) {
        String fileName = "img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
        String downloadUrl = await _upload(fileName, _newPhotosToUpload[i], userId, targetJourneyId, "images");
        freshlyUploadedPhotoUrls.add(downloadUrl);
      }

      List<String> consolidatedPhotoUrls = [..._existingPhotoUrls, ...freshlyUploadedPhotoUrls];
      Map<String, dynamic> journeyData = {
        'userId': userId,
        'name': newFolder,
        'travelType': _selectedType,
        'startDate': _startController.text,
        'endDate': _endController.text,
        'destinations': _extractText(_destControllers),
        'transportation': _extractRows(_transportRows),
        'accommodation': _extractRows(_accommodationRows),
        'activities': _extractRows(_activityRows),
        'notes': _notesController.text.trim(),
        'pdfUrls': _finalPdfUrls,
        'photoUrls': consolidatedPhotoUrls,
        'state': 'to_be_visited',
        'fcmToken': fcmToken,
      };
      await docRef.set(journeyData, SetOptions(merge: true));
      if (widget.existingJourney != null) {
        // If editing, wipe previous calendars clean first to avoid duplicate ghosts
        await NotificationService.cancelTripAutomations(targetJourneyId);
      }
      await NotificationService.scheduleTripAutomations(
        targetJourneyId,
        newFolder, // Journey Name
        _startController.text,
        _endController.text,
      );
      print("Successfully saved and synced files to updated folder paths!");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving journey: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }
  Future<void> _loadItalianCities() async {
    try {
      // 1. Read your it.json asset file
      final String jsonString = await rootBundle.loadString('assets/data/it.json');

      // 2. Decode the JSON string
      final List<dynamic> jsonResponse = jsonDecode(jsonString);

      // 3. Extract only the 'city' name strings and eliminate any duplicate entries
      final Set<String> uniqueCities = jsonResponse
          .map((item) => item['city'].toString().trim())
          .where((cityName) => cityName.isNotEmpty)
          .toSet();

      if (mounted) {
        setState(() {
          _italianCities = uniqueCities.toList()..sort(); // Sorted alphabetically
          _isCitiesLoading = false;
          debugPrint("Loaded ${_italianCities.length} cities from it.json!");
        });
      }
    } catch (e) {
      debugPrint("Error loading or parsing it.json: $e");
      if (mounted) {
        setState(() => _isCitiesLoading = false);
      }
    }
  }

// 🌟 THE PERMISSION GUARD FUNCTION
  Future<void> _handlePhotoSelectionPermission() async {
    PermissionStatus status;

    // Android 13+ (API 33+) requires checking READ_MEDIA_IMAGES
    if (Platform.isAndroid && await _getAndroidSDKVersion() >= 33) {
      status = await Permission.photos.status;
      if (status.isDenied) {
        status = await Permission.photos.request();
      }
    } else {
      // Android 12 and below requires checking STORAGE
      status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    }

    // Handle the results gracefully
    if (status.isGranted) {
      // Permission allowed! Safe to open your existing picker method
      _pickImage();
    } else if (status.isPermanentlyDenied) {
      // The user clicked "Don't ask again". Guide them to Device Settings.
      _showPermissionSettingsDialog();
    } else {
      // User denied it this time
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Storage permission is required to upload trip photos.")),
      );
    }
  }

// Helper to find out the active Android SDK version dynamically
  Future<int> _getAndroidSDKVersion() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt;
    }
    return 0;
  }

// Dialog explaining how to unlock permissions manually if permanently locked out
  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Photos Permission Required"),
        content: const Text("You have disabled photo access. Please enable it in the device settings to add journey memories."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Native shortcut opens app settings instantly
            },
            child: const Text("Open Settings", style: TextStyle(color: Color(0xFF3D5A5A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    _loadItalianCities();
    if (widget.existingJourney != null) {
      // WE ARE IN EDIT MODE
      final j = widget.existingJourney!;

      // Simple Strings
      _nameController = TextEditingController(text: j.name);
      _startController.text = j.startDate ?? '';
      _endController.text = j.endDate ?? '';
      _notesController.text = j.notes ?? '';
      _selectedType = j.type ?? 'Travel Type';
      // Load existing URLs into our fixed list
      for (int i = 0; i < j.pdfUrls.length && i < 3; i++) {
        _finalPdfUrls[i] = j.pdfUrls[i];
      }
      // Update Text to show user there is a file saved
      if (_finalPdfUrls[0].isNotEmpty) _visaController.text = "Existing Visa PDF";
      if (_finalPdfUrls[1].isNotEmpty) _ticketController.text = "Existing Ticket PDF";
      if (_finalPdfUrls[2].isNotEmpty) _insuranceController.text = "Existing Insurance PDF";
      _existingPhotoUrls = List<String>.from(j.imageUrls);
      //  Destintions List
      if (j.destinations.isNotEmpty) {
        _destControllers = j.destinations.map((d) => TextEditingController(text: d)).toList();
      } else {
        _destControllers = [TextEditingController()];
      }
      // Transprtation List
      if (j.transportation.isNotEmpty) {
        _transportRows = j.transportation.map((t) => {
          'mode': t['mode'] ?? 'Airline',
          'controller': TextEditingController(text: t['controller'] ?? '')
        }).toList();
      }
      // Accommodation List
      if (j.accommodation.isNotEmpty) {
        _accommodationRows = j.accommodation.map((a) => {
          'hotelName': TextEditingController(text: a['hotelName'] ?? ''),
          'address': TextEditingController(text: a['address'] ?? ''),
          'stayAt': a['stayAt'] ?? 'Primary Destination',
        }).toList();
      }
      // Activity List
      if (j.activities.isNotEmpty) {
        _activityRows = j.activities.map((act) => {
          'activity': TextEditingController(text: act['activity'] ?? ''),
          'place': TextEditingController(text: act['place'] ?? ''),
        }).toList();
      }
    } else {
      _nameController = TextEditingController();
      _destControllers = [TextEditingController()];
    }
  }
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 80,
    );
    if (images.isNotEmpty) {
      setState(() {
        _newPhotosToUpload.addAll(
            images.map((xFile) => File(xFile.path)).toList()
        );
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    bool isEditOrViewMode = widget.existingJourney != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isReadOnly
              ? 'Journey Details'
              : (widget.existingJourney == null ? 'New Journey' : 'Edit Journey'),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: IgnorePointer(
                  ignoring: widget.isReadOnly,
                  child: Column(
                    children: [
                      _buildSectionWrapper(
                        title: "Basic Trip Details",
                        child: Column(
                          children: [
                            _buildTextField("Name your new trip", _nameController, isMandatory: true),
                            const SizedBox(height: 15),

                            ..._destControllers.asMap().entries.map((entry) {
                              int index = entry.key;
                              TextEditingController controller = entry.value;
                              bool isPrimary = index == 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _isCitiesLoading
                                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF3D5A5A)))
                                    : Autocomplete<String>(
                                  // Pass a unique key matching the controller hash to help Flutter trace it in the loop
                                  key: ValueKey('autocomplete_${controller.hashCode}'),
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    return _italianCities.where((String city) {
                                      return city.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                    });
                                  },
                                  onSelected: (String selection) {
                                    setState(() {
                                      _destControllers[index].text = selection;
                                    });
                                    debugPrint('Validated city chosen at index $index: $selection');
                                  },
                                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                    // Sync initial value if editing an existing journey
                                    if (textEditingController.text.isEmpty && controller.text.isNotEmpty) {
                                      textEditingController.text = controller.text;
                                    }

                                    // 🛡️ Garbage Filter Validation: Wipe input instantly if it's not a valid city on focus loss
                                    focusNode.addListener(() {
                                      if (!focusNode.hasFocus) {
                                        final text = textEditingController.text.trim();
                                        if (text.isNotEmpty && !_italianCities.contains(text)) {
                                          setState(() {
                                            textEditingController.clear();
                                            _destControllers[index].clear();
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("⚠️ Invalid destination. Please select a valid city from the list!"),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    });

                                    // Keep your array controller data synced with typing
                                    textEditingController.addListener(() {
                                      controller.text = textEditingController.text;
                                    });

                                    // 🎯 THE FIX APPLIED: Forward the critical focusNode to your custom field template!
                                    return _buildTextField(
                                      isPrimary ? "Destination" : "Destination ${index + 1}",
                                      textEditingController,
                                      icon: isPrimary ? Icons.add_box : Icons.delete,
                                      iconColor: isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
                                      onIconTap: widget.isReadOnly ? null : () {
                                        setState(() {
                                          if (isPrimary) {
                                            _destControllers.add(TextEditingController());
                                          } else {
                                            _destControllers.removeAt(index);
                                          }
                                        });
                                      },
                                      isMandatory: true,
                                      focusNode: focusNode, // <-- Critical focus hook assignment!
                                    );
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 8.0,
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: MediaQuery.of(context).size.width - 40,
                                          constraints: const BoxConstraints(maxHeight: 200),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (BuildContext context, int idx) {
                                              final String option = options.elementAt(idx);
                                              return ListTile(
                                                leading: const Icon(Icons.location_on, color: Color(0xFF3D5A5A), size: 18),
                                                title: Text(
                                                  option,
                                                  style: TextStyle(
                                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                onTap: () => onSelected(option),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 10),

                            // --- DATE FIELDS ---
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                      "Start Date",
                                      _startController,
                                      icon: Icons.calendar_month,
                                      onIconTap: () => _selectDate(context, _startController, true),
                                      readOnly: true,
                                      isMandatory: true),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildTextField(
                                      "End Date",
                                      _endController,
                                      icon: Icons.calendar_month,
                                      onIconTap: () => _selectDate(context, _endController, false),
                                      readOnly: true,
                                      isMandatory: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildDropdown(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isEditOrViewMode) ...[
                        _buildSectionWrapper(
                          title: "Journey Memories 📸",
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_existingPhotoUrls.isEmpty && _newPhotosToUpload.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text("No photos uploaded yet.", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _existingPhotoUrls.length + _newPhotosToUpload.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                                  itemBuilder: (context, idx) {
                                    if (idx < _existingPhotoUrls.length) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(_existingPhotoUrls[idx], fit: BoxFit.cover),
                                      );
                                    } else {
                                      int localIdx = idx - _existingPhotoUrls.length;
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(_newPhotosToUpload[localIdx], fit: BoxFit.cover),
                                      );
                                    }
                                  },
                                ),
                              const SizedBox(height: 15),
                              if (!widget.isReadOnly)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A5A), foregroundColor: Colors.white),
                                  onPressed: _handlePhotoSelectionPermission,
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text("Add Photo"),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _buildSectionWrapper(
                        title: "Transportation Info",
                        child: Column(
                          children: _transportRows.asMap().entries.map((entry) {
                            int index = entry.key;
                            bool isPrimary = index == 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _transportRows[index]['mode'],
                                          isExpanded: true,
                                          style: const TextStyle(fontSize: 12, color: Colors.black),
                                          items: _transportModes.map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (newValue) {
                                            setState(() {
                                              _transportRows[index]['mode'] = newValue;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 3,
                                    child: _buildTextField(
                                      "TP Number",
                                      _transportRows[index]['controller'],
                                      icon: isPrimary ? Icons.add_box : Icons.delete,
                                      iconColor: isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
                                      onIconTap: widget.isReadOnly ? null : () {
                                        setState(() {
                                          if (isPrimary) {
                                            _transportRows.add({
                                              'mode': 'Airline',
                                              'controller': TextEditingController()
                                            });
                                          } else {
                                            _transportRows.removeAt(index);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionWrapper(
                        title: "Accommodation Info",
                        child: Column(
                          children: [
                            ..._accommodationRows.asMap().entries.map((entry) {
                              int index = entry.key;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Place ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        if (index != 0)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () => setState(() => _accommodationRows.removeAt(index)),
                                          ),
                                      ],
                                    ),
                                    _buildTextField("Hotel Name", _accommodationRows[index]['hotelName']),
                                    const SizedBox(height: 10),
                                    _buildTextField("Address", _accommodationRows[index]['address']),
                                    const SizedBox(height: 10),
                                    _buildStayAtDropdown(index),
                                  ],
                                ),
                              );
                            }),
                            if (!widget.isReadOnly)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _accommodationRows.add({
                                      'hotelName': TextEditingController(),
                                      'address': TextEditingController(),
                                      'stayAt': 'Destination',
                                    });
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF3D5A5A)),
                                label: const Text("Add another stay", style: TextStyle(color: Color(0xFF3D5A5A))),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionWrapper(
                        title: "Activities / Places",
                        child: Column(
                          children: [
                            ..._activityRows.asMap().entries.map((entry) {
                              int index = entry.key;
                              bool isPrimary = index == 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField("Activity", _activityRows[index]['activity']),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTextField(
                                        "Place",
                                        _activityRows[index]['place'],
                                        icon: isPrimary ? Icons.add_box : Icons.delete,
                                        iconColor: isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
                                        onIconTap: widget.isReadOnly ? null : () {
                                          setState(() {
                                            if (isPrimary) {
                                              _activityRows.add({
                                                'activity': TextEditingController(),
                                                'place': TextEditingController()
                                              });
                                            } else {
                                              _activityRows.removeAt(index);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: "Something special to remember...",
                                hintStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionWrapper(
                              title: "Special Documents",
                              child: Column(
                                children: [
                                  _buildFilePickerRow("Visa", _visaController, 0),
                                  const SizedBox(height: 10),
                                  _buildFilePickerRow("Ticket", _ticketController, 1),
                                  const SizedBox(height: 10),
                                  _buildFilePickerRow("Travel Insurance", _insuranceController, 2),
                                  const SizedBox(height: 15),
                                  const Divider(),
                                  const Text("Other Documents", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  ..._extraDocs.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    bool isPrimary = index == 0;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              "${_extraDocs[index]['fileName']}",
                                              style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF3D5A5A),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: widget.isReadOnly ? null : () => _pickExtraDocument(index),
                                            child: const Text("Browse", style: TextStyle(color: Colors.white, fontSize: 11)),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isPrimary ? Icons.add_circle : Icons.delete,
                                              color: isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
                                            ),
                                            onPressed: widget.isReadOnly ? null : () {
                                              setState(() {
                                                if (isPrimary) {
                                                  _extraDocs.add({'name': TextEditingController(), 'fileName': ''});
                                                } else {
                                                  _extraDocs.removeAt(index);
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
              ),
              )
            ),
          ),
          // Locate the final bottom Padding inside your build method and replace it with this:
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: widget.isReadOnly
                ? Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                      // Triggers a custom validation alert directly on screen
                      bool confirmDelete = await showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            title: const Text("Delete Trip", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color:Colors.teal)),
                            content: const Text("Are you sure you want to permanently delete this trip and all its attached files?",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text("Cancel", style: TextStyle(color: Color(0xFF3D5A5A))),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      ) ?? false;

                      if (confirmDelete) {
                        setState(() => _isSaving = true);
                        try {
                          String userId = widget.existingJourney?.userId ?? '';
                          String journeyId = widget.existingJourney?.id ?? '';
                          if (userId.isNotEmpty && journeyId.isNotEmpty) {
                            final ListResult pdfsDir = await FirebaseStorage.instance
                                .ref().child('media/$userId/$journeyId/pdfs').listAll();
                            for (Reference fileRef in pdfsDir.items) {
                              await fileRef.delete();
                            }
                            final ListResult imagesDir = await FirebaseStorage.instance
                                .ref().child('media/$userId/$journeyId/images').listAll();
                            for (Reference fileRef in imagesDir.items) {
                              await fileRef.delete();
                            }
                          }

                          await NotificationService.cancelTripAutomations(journeyId);

                          await FirebaseFirestore.instance.collection('journeys').doc(journeyId).delete();

                          if (mounted) {
                            Navigator.pop(context, true); // Returns true to trigger updates on wallet screen
                          }
                        } catch (e) {
                          setState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error deleting trip: $e")),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                    label: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5A5A),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // Direct navigation trick: re-opens the same page but with isReadOnly turned off!
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JourneyDetailsPage(
                            existingJourney: widget.existingJourney,
                            isReadOnly: false, // Opens edit fields up instantly!
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text("Edit Trip", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5A5A),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving
                  ? null
                  : () async {
                if (_formKey.currentState!.validate()) {
                  await saveJourney();
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill in all mandatory fields!")),
                  );
                }
              },
              child: _isSaving
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
                  : Text(widget.existingJourney == null ? "Save" : "Update", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTextField(String hint,
      TextEditingController controller,
      {IconData? icon, VoidCallback? onIconTap, Color? iconColor, bool readOnly = false, bool isMandatory = false, FocusNode? focusNode,} // Added isMandatory
      )
  {return TextFormField(
      controller: controller,
    focusNode: focusNode,
      readOnly: widget.isReadOnly ? true : readOnly,
      onTap: (widget.isReadOnly ? null : (readOnly ? onIconTap : null)),
      validator: (value) {
        if (isMandatory && (value == null || value.trim().isEmpty)) {
          return 'This field is required'; // Error message
        }
        return null; // Null means it passed validation
      },
      decoration: InputDecoration(
        hintText: isMandatory ? "$hint *" : hint, // mandatory fields
        hintStyle: const TextStyle(fontSize: 12),
        suffixIcon: icon != null
            ? IconButton(
          icon: Icon(icon, color: iconColor ?? Colors.grey, size: 20),
          onPressed: onIconTap,
        )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );}

  Widget _buildSectionWrapper({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          child,
        ],
      ),
    );
  }
  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedType == 'Travel Type' ? null : _selectedType,
          hint: const Text("Travel Type", style: TextStyle(fontSize: 12)),style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
          items: <String>['Business', 'Vacation', 'Family'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value,
            style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal, // Removes bold styling inside the popup
                color: Colors.black87,
            )
            )
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedType = val!),
        ),
      ),
    );
  }
  Widget _buildStayAtDropdown(int index) {
    // use to get all current destination names from  _destControllers
    List<String> currentDestinations = _destControllers
        .map((c) => c.text.isEmpty ? "Unnamed Destination" : c.text)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text("Which destination is this for?", style: TextStyle(fontSize: 12)),
          items: currentDestinations.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 12)));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _accommodationRows[index]['stayAt'] = val;
            });
          },
        ),
      ),
    );
  }
  Widget _buildFilePickerRow(String label, TextEditingController controller, int index) {
    bool hasRemote = _finalPdfUrls[index].isNotEmpty;
    return Row(
      children: [
        Expanded(child: _buildTextField(label, controller, readOnly: true,  icon: hasRemote ? Icons.cloud_done : Icons.picture_as_pdf)),
        const SizedBox(width: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A5A)),
          onPressed: () => _pickFile(controller, index),
          child: Text(hasRemote ? "REPLACE" : "BROWSE", style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
      ],
    );
  }
}
class DestinationAutocompleteField extends StatefulWidget {
  final int index;
  final TextEditingController controller;
  final bool isPrimary;
  final bool isReadOnly;
  final List<String> citiesList;
  final Function() onIconTap;
  final Widget Function(String, TextEditingController, {IconData? icon, Color? iconColor, VoidCallback? onIconTap, bool isMandatory}) buildTextField;

  const DestinationAutocompleteField({
    super.key,
    required this.index,
    required this.controller,
    required this.isPrimary,
    required this.isReadOnly,
    required this.citiesList,
    required this.onIconTap,
    required this.buildTextField,
  });

  @override
  State<DestinationAutocompleteField> createState() => _DestinationAutocompleteFieldState();
}

class _DestinationAutocompleteFieldState extends State<DestinationAutocompleteField> {
  late TextEditingController _localAutoCompleteController;

  @override
  void initState() {
    super.initState();
    _localAutoCompleteController = TextEditingController(text: widget.controller.text);

    // Sync changes from the autocomplete view back to the master controller array safely
    _localAutoCompleteController.addListener(() {
      widget.controller.text = _localAutoCompleteController.text;
    });
  }

  @override
  void didUpdateWidget(covariant DestinationAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the master controller text changes from outside, sync the local controller text view
    if (widget.controller.text != _localAutoCompleteController.text) {
      _localAutoCompleteController.text = widget.controller.text;
    }
  }

  @override
  void dispose() {
    _localAutoCompleteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return widget.citiesList.where((String city) {
          return city.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        setState(() {
          _localAutoCompleteController.text = selection;
          widget.controller.text = selection;
        });
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        // Enforce synchronization during render intervals
        if (textEditingController.text != _localAutoCompleteController.text) {
          textEditingController.text = _localAutoCompleteController.text;
        }

        // Garbage Validation Filter on Focus Loss
        focusNode.addListener(() {
          if (!focusNode.hasFocus) {
            final text = textEditingController.text.trim();
            if (text.isNotEmpty && !widget.citiesList.contains(text)) {
              setState(() {
                textEditingController.clear();
                _localAutoCompleteController.clear();
                widget.controller.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Invalid destination. Please select a valid city from the list!"),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        });

        // Reuse your original field layout parameters
        return widget.buildTextField(
          widget.isPrimary ? "Destination" : "Destination ${widget.index + 1}",
          textEditingController,
          icon: widget.isPrimary ? Icons.add_box : Icons.delete,
          iconColor: widget.isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
          onIconTap: widget.isReadOnly ? null : widget.onIconTap,
          isMandatory: true,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8.0,
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int idx) {
                  final String option = options.elementAt(idx);
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF3D5A5A), size: 18),
                    title: Text(
                      option,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

