import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../Services/city_loader_service.dart';
import '../../Services/file_picker_service.dart';
import '../../Services/notification_service.dart';
import '../../Models/journey.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Services/journey_storage_service.dart';
import '../../Services/photo_picker_service.dart';
import '../../Utils/journey_formatter.dart';

class JourneyDetailsPage extends StatefulWidget {
  final Journey? existingJourney;
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
  late TextEditingController _nameController;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _visaController = TextEditingController();
  final TextEditingController _ticketController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<String> _transportModes = ['Airline', 'Train', 'Taxi', 'Metro', 'Bus', 'Ship'];
  final List<Map<String, dynamic>> _extraDocs = [];
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String _selectedType = 'Travel Type';
  String _tripState = 'to_be_visited';
  File? _newVisaFile, _newTicketFile, _newInsuranceFile;
  List<String> _italianCities = [];
  bool _isCitiesLoading = true;
  List<String> _finalPdfUrls = ["", "", ""];
  List<String> _existingPhotoUrls = [];
  List<File> _newPhotosToUpload = [];
  List<TextEditingController> _destControllers = [];
  List<Map<String, dynamic>> _transportRows = [];
  List<Map<String, dynamic>> _accommodationRows = [];
  List<Map<String, dynamic>> _activityRows = [];

  final DateFormat _uiDateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    _visaController.dispose();
    _ticketController.dispose();
    _insuranceController.dispose();
    _notesController.dispose();

    for (var controller in _destControllers) {
      controller.dispose();
    }
    for (var row in _transportRows) {
      if (row['controller'] is TextEditingController) {
        (row['controller'] as TextEditingController).dispose();
      }
    }
    for (var row in _accommodationRows) {
      if (row['hotelName'] is TextEditingController) (row['hotelName'] as TextEditingController).dispose();
      if (row['address'] is TextEditingController) (row['address'] as TextEditingController).dispose();
    }
    for (var row in _activityRows) {
      if (row['activity'] is TextEditingController) (row['activity'] as TextEditingController).dispose();
      if (row['place'] is TextEditingController) (row['place'] as TextEditingController).dispose();
    }
    for (var doc in _extraDocs) {
      if (doc['name'] is TextEditingController) (doc['name'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, bool isStartDate) async {
    DateTime now = DateTime.now();
    DateTime initialDate = now;
    DateTime firstSelectableDate = now;

    if (isStartDate) {
      firstSelectableDate = DateTime(now.year, now.month, now.day);
      if (controller.text.isNotEmpty) {
        try {
          initialDate = _uiDateFormat.parse(controller.text);
        } catch (_) {}
      }
    } else {
      if (_startController.text.isNotEmpty) {
        try {
          DateTime parsedStart = _uiDateFormat.parse(_startController.text);
          firstSelectableDate = parsedStart;
          initialDate = parsedStart;
        } catch (_) {
          firstSelectableDate = DateTime(now.year, now.month, now.day);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a Start Date first! 📅"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (controller.text.isNotEmpty) {
        try {
          DateTime parsedEnd = _uiDateFormat.parse(controller.text);
          if (parsedEnd.isAfter(firstSelectableDate) || parsedEnd.isAtSameMomentAs(firstSelectableDate)) {
            initialDate = parsedEnd;
          }
        } catch (_) {}
      }
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstSelectableDate,
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        controller.text = _uiDateFormat.format(picked);

        if (isStartDate && _endController.text.isNotEmpty) {
          try {
            DateTime currentEnd = _uiDateFormat.parse(_endController.text);
            if (picked.isAfter(currentEnd)) {
              _endController.clear();
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
    final result = await FilePickerService.pickCustomFile(['pdf', 'jpg', 'png', 'doc']);
    if (result != null && mounted) {
      setState(() {
        File pickedFile = File(result.files.single.path!);
        controller.text = result.files.single.name;
        if (index == 0) _newVisaFile = pickedFile;
        if (index == 1) _newTicketFile = pickedFile;
        if (index == 2) _newInsuranceFile = pickedFile;
      });
    }
  }

  Future<void> _pickExtraDocument(int index) async {
    try {
      final result = await FilePickerService.pickCustomFile(['pdf', 'jpg', 'png', 'docx']);
      if (result != null && mounted) {
        setState(() {
          _extraDocs[index]['fileName'] = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint("File picker error: $e");
    }
  }

  Future<void> saveJourney() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSaving = true;
    });
    try {
      String newFolder = _nameController.text.trim();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("No authorized user found!");

      String userId = currentUser.uid;
      String targetJourneyId;
      DocumentReference docRef;

      String dbStartDate = '';
      String dbEndDate = '';
      try {
        if (_startController.text.isNotEmpty) {
          DateTime parsedStart = _uiDateFormat.parse(_startController.text);
          dbStartDate = DateFormat('yyyy-MM-dd').format(parsedStart);
        }
        if (_endController.text.isNotEmpty) {
          DateTime parsedEnd = _uiDateFormat.parse(_endController.text);
          dbEndDate = DateFormat('yyyy-MM-dd').format(parsedEnd);
        }
      } catch (e) {
        dbStartDate = _startController.text;
        dbEndDate = _endController.text;
      }

      if (widget.existingJourney != null) {
        targetJourneyId = widget.existingJourney!.id;
        docRef = FirebaseFirestore.instance.collection('journeys').doc(targetJourneyId);
        String oldFolder = widget.existingJourney!.name;

        if (oldFolder != newFolder) {
          _finalPdfUrls = await JourneyStorageService.moveStorageFolder(oldFolder, newFolder, _finalPdfUrls);
        }
      } else {
        docRef = FirebaseFirestore.instance.collection('journeys').doc();
        targetJourneyId = docRef.id;
      }

      if (_newVisaFile != null) {
        _finalPdfUrls[0] = await JourneyStorageService.upload("visa.pdf", _newVisaFile!, userId, targetJourneyId, "pdfs");
      }
      if (_newTicketFile != null) {
        _finalPdfUrls[1] = await JourneyStorageService.upload("ticket.pdf", _newTicketFile!, userId, targetJourneyId, "pdfs");
      }
      if (_newInsuranceFile != null) {
        _finalPdfUrls[2] = await JourneyStorageService.upload("insurance.pdf", _newInsuranceFile!, userId, targetJourneyId, "pdfs");
      }

      List<String> freshlyUploadedPhotoUrls = [];
      for (int i = 0; i < _newPhotosToUpload.length; i++) {
        String fileName = "img_\${DateTime.now().millisecondsSinceEpoch}_\$i.jpg";
        String downloadUrl = await JourneyStorageService.upload(fileName, _newPhotosToUpload[i], userId, targetJourneyId, "images");
        freshlyUploadedPhotoUrls.add(downloadUrl);
      }

      List<String> consolidatedPhotoUrls = [..._existingPhotoUrls, ...freshlyUploadedPhotoUrls];
      Map<String, dynamic> journeyData = {
        'userId': userId,
        'name': newFolder,
        'travelType': _selectedType,
        'startDate': dbStartDate,
        'endDate': dbEndDate,
        'destinations': JourneyFormatter.extractText(_destControllers),
        'transportation': JourneyFormatter.extractRows(_transportRows),
        'accommodation': JourneyFormatter.extractRows(_accommodationRows),
        'activities': JourneyFormatter.extractRows(_activityRows),
        'notes': _notesController.text.trim(),
        'pdfUrls': _finalPdfUrls,
        'photoUrls': consolidatedPhotoUrls,
        'state': _tripState,
        'fcmToken': fcmToken,
      };

      await docRef.set(journeyData, SetOptions(merge: true));

      if (widget.existingJourney != null) {
        await NotificationService.cancelTripAutomations(targetJourneyId);
      }

      if (_tripState == 'to_be_visited') {
        await NotificationService.scheduleTripAutomations(
          targetJourneyId,
          newFolder,
          dbStartDate,
          dbEndDate,
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Error saving journey: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadItalianCities() async {
    final cities = await CityLoaderService.loadCities();
    if (mounted) {
      setState(() {
        _italianCities = cities;
        _isCitiesLoading = false;
      });
    }
  }

  Future<void> _handlePhotoSelectionPermission() async {
    PermissionStatus status;
    if (Platform.isAndroid && await PhotoPickerService.getAndroidSDKVersion() >= 33) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      final selectedImages = await PhotoPickerService.pickMultiImages();
      if (mounted && selectedImages.isNotEmpty) {
        setState(() {
          _newPhotosToUpload.addAll(selectedImages);
        });
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionSettingsDialog();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission is required to upload trip photos.")),
        );
      }
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Photos Permission Required"),
        content: const Text("You have disabled photo access. Please enable it in settings to add memories."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Open Settings", style: TextStyle(fontWeight: FontWeight.bold)),
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
      final j = widget.existingJourney!;
      _nameController = TextEditingController(text: j.name);
      _tripState = j.state ?? 'to_be_visited';

      try {
        if (j.startDate != null && j.startDate!.isNotEmpty) {
          DateTime parsedStart = DateFormat('yyyy-MM-dd').parse(j.startDate!);
          _startController.text = _uiDateFormat.format(parsedStart);
        }
        if (j.endDate != null && j.endDate!.isNotEmpty) {
          DateTime parsedEnd = DateFormat('yyyy-MM-dd').parse(j.endDate!);
          _endController.text = _uiDateFormat.format(parsedEnd);
        }
      } catch (e) {
        _startController.text = j.startDate ?? '';
        _endController.text = j.endDate ?? '';
      }

      _notesController.text = j.notes ?? '';
      _selectedType = j.type ?? 'Travel Type';

      for (int i = 0; i < j.pdfUrls.length && i < 3; i++) {
        _finalPdfUrls[i] = j.pdfUrls[i];
      }
      if (_finalPdfUrls[0].isNotEmpty) _visaController.text = "Existing Visa PDF";
      if (_finalPdfUrls[1].isNotEmpty) _ticketController.text = "Existing Ticket PDF";
      if (_finalPdfUrls[2].isNotEmpty) _insuranceController.text = "Existing Insurance PDF";

      _existingPhotoUrls = List<String>.from(j.imageUrls);
      _destControllers = j.destinations.isNotEmpty
          ? j.destinations.map((d) => TextEditingController(text: d)).toList()
          : [TextEditingController()];

      _transportRows = j.transportation.isNotEmpty
          ? j.transportation.map((t) => {'mode': t['mode'] ?? 'Airline', 'controller': TextEditingController(text: t['controller'] ?? '')}).toList()
          : [{'mode': 'Airline', 'controller': TextEditingController()}];

      _accommodationRows = j.accommodation.isNotEmpty
          ? j.accommodation.map((a) => {'hotelName': TextEditingController(text: a['hotelName'] ?? ''), 'address': TextEditingController(text: a['address'] ?? ''), 'stayAt': a['stayAt'] ?? 'Primary Destination'}).toList()
          : [{'hotelName': TextEditingController(), 'address': TextEditingController(), 'stayAt': 'Primary Destination'}];

      _activityRows = j.activities.isNotEmpty
          ? j.activities.map((act) => {'activity': TextEditingController(text: act['activity'] ?? ''), 'place': TextEditingController(text: act['place'] ?? '')}).toList()
          : [{'activity': TextEditingController(), 'place': TextEditingController()}];
    } else {
      _nameController = TextEditingController();
      _destControllers = [TextEditingController()];
      _transportRows = [{'mode': 'Airline', 'controller': TextEditingController()}];
      _accommodationRows = [{'hotelName': TextEditingController(), 'address': TextEditingController(), 'stayAt': 'Primary Destination'}];
      _activityRows = [{'activity': TextEditingController(), 'place': TextEditingController()}];
    }
    _extraDocs.add({'name': TextEditingController(), 'fileName': 'No file selected'});
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
                                  key: ValueKey('autocomplete_${controller.hashCode}'),
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                                    return _italianCities.where((String city) => city.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  onSelected: (String selection) {
                                    setState(() {
                                      _destControllers[index].text = selection;
                                    });
                                  },
                                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                    if (textEditingController.text.isEmpty && controller.text.isNotEmpty) {
                                      textEditingController.text = controller.text;
                                    }
                                    focusNode.addListener(() {
                                      if (!focusNode.hasFocus) {
                                        final text = textEditingController.text.trim();
                                        if (text.isNotEmpty && !_italianCities.contains(text)) {
                                          setState(() {
                                            textEditingController.clear();
                                            _destControllers[index].clear();
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("⚠️ Invalid destination. Please select a valid city from the list!")),
                                          );
                                        }
                                      }
                                    });
                                    textEditingController.addListener(() {
                                      controller.text = textEditingController.text;
                                    });
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
                                      focusNode: focusNode,
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
                                              return ListTile(
                                                leading: const Icon(Icons.location_on, color: Color(0xFF3D5A5A), size: 18),
                                                title: Text(options.elementAt(idx), style: const TextStyle(fontSize: 14)),
                                                onTap: () => onSelected(options.elementAt(idx)),
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

                            _buildTextField(
                              "Start Date",
                              _startController,
                              icon: Icons.calendar_month,
                              onIconTap: () => _selectDate(context, _startController, true),
                              readOnly: true,
                              isMandatory: true,
                            ),
                            const SizedBox(height: 15),
                            _buildTextField(
                              "End Date",
                              _endController,
                              icon: Icons.calendar_month,
                              onIconTap: () => _selectDate(context, _endController, false),
                              readOnly: true,
                              isMandatory: true,
                            ),
                            const SizedBox(height: 15),

                            _buildDropdown(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isEditOrViewMode) ...[
                        _buildStatusSection(),
                        const SizedBox(height: 20),
                      ],
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
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _transportRows[index]['mode'],
                                          isExpanded: true,
                                          style: const TextStyle(fontSize: 12, color: Colors.black),
                                          items: _transportModes.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
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
                                            _transportRows.add({'mode': 'Airline', 'controller': TextEditingController()});
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
                                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
                                    _accommodationRows.add({'hotelName': TextEditingController(), 'address': TextEditingController(), 'stayAt': 'Destination'});
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
                                    Expanded(child: _buildTextField("Activity", _activityRows[index]['activity'])),
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
                                              _activityRows.add({'activity': TextEditingController(), 'place': TextEditingController()});
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
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A5A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                            onPressed: widget.isReadOnly ? null : () => _pickExtraDocument(index),
                                            child: const Text("Browse", style: TextStyle(color: Colors.white, fontSize: 11)),
                                          ),
                                          IconButton(
                                            icon: Icon(isPrimary ? Icons.add_circle : Icons.delete, color: isPrimary ? const Color(0xFF3D5A5A) : Colors.red),
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
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: widget.isReadOnly
                ? Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isSaving
                        ? null
                        : () async {
                      bool confirmDelete = await showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            title: const Text("Delete Trip", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                            content: const Text("Are you sure you want to permanently delete this trip and all its attached files?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text("Cancel", style: TextStyle(color: Color(0xFF3D5A5A)))),
                              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
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
                            final ListResult pdfsDir = await FirebaseStorage.instance.ref().child('media/$userId/$journeyId/pdfs').listAll();
                            for (Reference fileRef in pdfsDir.items) {
                              await fileRef.delete();
                            }
                            final ListResult imagesDir = await FirebaseStorage.instance.ref().child('media/$userId/$journeyId/images').listAll();
                            for (Reference fileRef in imagesDir.items) {
                              await fileRef.delete();
                            }
                          }
                          await NotificationService.cancelTripAutomations(journeyId);
                          await FirebaseFirestore.instance.collection('journeys').doc(journeyId).delete();
                          if (mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (mounted) setState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting trip: $e")));
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
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A5A), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => JourneyDetailsPage(existingJourney: widget.existingJourney, isReadOnly: false)),
                      );
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text("Edit Trip", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
                : ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A5A), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _isSaving
                  ? null
                  : () async {
                if (_formKey.currentState!.validate()) {
                  await saveJourney();
                  if (mounted) Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all mandatory fields!")));
                }
              },
              child: _isSaving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(widget.existingJourney == null ? "Save" : "Update", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return _buildSectionWrapper(
      title: "Trip Status",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statusOption("Planned", 'to_be_visited', Colors.orange),
          _statusOption("Visited", 'visited', Colors.green),
          _statusOption("Canceled", 'canceled', Colors.red),
        ],
      ),
    );
  }

  Widget _statusOption(String label, String value, Color color) {
    bool isSelected = _tripState == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? color : Colors.grey.shade100,
            foregroundColor: isSelected ? Colors.white : Colors.black87,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
            ),
          ),
          onPressed: widget.isReadOnly ? null : () => setState(() => _tripState = value),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {IconData? icon, VoidCallback? onIconTap, Color? iconColor, bool readOnly = false, bool isMandatory = false, FocusNode? focusNode}) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: widget.isReadOnly ? true : readOnly,
      onTap: (widget.isReadOnly ? null : (readOnly ? onIconTap : null)),
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      validator: (value) {
        if (isMandatory && (value == null || value.trim().isEmpty)) return 'This field is required';
        return null;
      },
      decoration: InputDecoration(
        hintText: isMandatory ? "$hint *" : hint,
        hintStyle: const TextStyle(fontSize: 12),
        suffixIcon: icon != null
            ? IconButton(
          icon: Icon(icon, color: iconColor ?? Colors.grey, size: 18),
          onPressed: onIconTap,
          padding: EdgeInsets.zero,
        )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSectionWrapper({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(15)),
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
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedType == 'Travel Type' ? null : _selectedType,
          hint: const Text("Travel Type", style: TextStyle(fontSize: 12)),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black87),
          items: <String>['Business', 'Vacation', 'Family'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black87)));
          }).toList(),
          onChanged: (val) => setState(() => _selectedType = val!),
        ),
      ),
    );
  }

  Widget _buildStayAtDropdown(int index) {
    List<String> currentDestinations = _destControllers.map((c) => c.text.isEmpty ? "Unnamed Destination" : c.text).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text("Which destination is this for?", style: TextStyle(fontSize: 12)),
          items: currentDestinations.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 12)))).toList(),
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
        Expanded(child: _buildTextField(label, controller, readOnly: true, icon: hasRemote ? Icons.cloud_done : Icons.picture_as_pdf)),
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