import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add 'intl' to your pubspec.yaml for date formatting
import 'package:file_picker/file_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'journey.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class JourneyDetailsPage extends StatefulWidget {
  final Journey? existingJourney; // If null, we are ADDING. If not null, we are EDITING.
  const JourneyDetailsPage({super.key, this.existingJourney});

  @override
  State<JourneyDetailsPage> createState() => _JourneyDetailsPageState();


}

class _JourneyDetailsPageState extends State<JourneyDetailsPage> {

  TextEditingController _nameController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  // Primary document controllers
  final TextEditingController _passportController = TextEditingController();
  final TextEditingController _visaController = TextEditingController();
  final TextEditingController _ticketController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();

// List for "Any Other" dynamic documents
  List<Map<String, dynamic>> _extraDocs = [
    {'name': TextEditingController(), 'fileName': 'No file selected'}
  ];
  String _selectedType = 'Travel Type';
  // List of controllers for dynamic destinations
  // The first one (index 0) is our "Primary" destination
  List<TextEditingController> _destControllers = [TextEditingController()];

  List<Map<String, dynamic>> _transportRows = [
    {'mode': 'Airline', 'controller': TextEditingController()}
  ];

  List<Map<String, dynamic>> _accommodationRows = [
    {
      'hotelName': TextEditingController(),
      'address': TextEditingController(),
      'stayAt': 'Primary Destination', // Default value
    }
  ];
  List<Map<String, dynamic>> _activityRows = [
    {'activity': TextEditingController(), 'place': TextEditingController()}
  ];

  final TextEditingController _notesController = TextEditingController();
  final List<String> _transportModes = ['Airline', 'Train', 'Taxi', 'Metro', 'Bus', 'Ship'];
  // Function to show DatePicker
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }
  Future<void> _pickFile(TextEditingController controller) async {
    // 1. Open the file explorer with specific filters
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc'], // Restrict to docs/images
    );

    // 2. Check if the user actually picked something
    if (result != null) {
      // Get the file name from the result
      PlatformFile file = result.files.first;

      // 3. Update the UI to show the selected file name
      setState(() {
        controller.text = file.name;
      });

      // Note: You can also get the path using file.path to upload it later
      print("Selected file path: ${file.path}");
    } else {
      // User canceled the picker
      print("User canceled the picker");
    }
  }
  // Update this function in your _JourneyDetailsPageState
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
  Future<void> testFirebase() async {
    try {
      print("🚀 Attempting to save to Firebase...");

      await FirebaseFirestore.instance.collection('journeys').add({
        'name': 'Test Trip to Paris',
        'destinations': ['Paris', 'Lyon'],
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Connection Success!'
      });

      print("✅ Successfully saved to Firestore!");
    } catch (e) {
      print("❌ Firebase Error: $e");
    }
  }
  @override
  void initState() {
    super.initState();

    if (widget.existingJourney != null) {
      // 1. Fill basic name
      _nameController = TextEditingController(text: widget.existingJourney!.name);

      // 2. Safely handle destinations
      // Use the '??' operator to provide an empty list if it's null
      final savedDests = widget.existingJourney!.destinations ?? [];

      if (savedDests.isNotEmpty) {
        _destControllers = savedDests.map((d) => TextEditingController(text: d.toString())).toList();
      } else {
        _destControllers = [TextEditingController()];
      }
    } else {
      // If it's a completely new journey
      _nameController = TextEditingController();
      _destControllers = [TextEditingController()];
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Journey ✈️')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildSectionWrapper(
              title: "Basic Trip Details",
              child: Column(
                children: [
                  _buildTextField("Name your new trip", _nameController),
                  const SizedBox(height: 15),

                  // --- DYNAMIC DESTINATIONS ---
                  ..._destControllers.asMap().entries.map((entry) {
                    int index = entry.key;
                    TextEditingController controller = entry.value;
                    bool isPrimary = index == 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildTextField(
                        isPrimary ? "Destination" : "Destination ${index + 1}",
                        controller,
                        icon: isPrimary ? Icons.add_box : Icons.delete,
                        iconColor: isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
                        onIconTap: () {
                          setState(() {
                            if (isPrimary) {
                              _destControllers.add(TextEditingController());
                            } else {
                              _destControllers.removeAt(index);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 10),

                  // --- DATE FIELDS ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          "Start Date",
                          _startController,
                          icon: Icons.calendar_month,
                          onIconTap: () => _selectDate(context, _startController),
                          readOnly: true, // User must use the calendar
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          "End Date",
                          _endController,
                          icon: Icons.calendar_month,
                          onIconTap: () => _selectDate(context, _endController),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildDropdown(),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                        // --- DROPDOWN FOR MODE ---
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

                        // --- TEXT FIELD FOR NUMBER ---
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            "TP Number",
                            _transportRows[index]['controller'],
                            icon: isPrimary ? Icons.add_box : Icons.delete,
                            iconColor: isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
                            onIconTap: () {
                              setState(() {
                                if (isPrimary) {
                                  // Add a new row
                                  _transportRows.add({
                                    'mode': 'Airline',
                                    'controller': TextEditingController()
                                  });
                                } else {
                                  // Remove this row
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
                  // Loop through each hotel/stay
                  ..._accommodationRows.asMap().entries.map((entry) {
                    int index = entry.key;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Place ${index + 1}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (index != 0) // Only show delete for extra hotels
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
                          // Optional: A dropdown to link it to Destination 1, 2, or 3
                          _buildStayAtDropdown(index),
                        ],
                      ),
                    );
                  }).toList(),

                  // ADD HOTEL BUTTON
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
                  // --- DYNAMIC ACTIVITY ROWS ---
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
                              onIconTap: () {
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
                  }).toList(),

                  const SizedBox(height: 15),

                  // --- NOTES SECTION (Multi-line) ---
                  TextField(
                    controller: _notesController,
                    maxLines: 3, // Makes it a larger "Box" as seen in the image
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
                        _buildFilePickerRow("Passport", _passportController),
                        const SizedBox(height: 10),
                        _buildFilePickerRow("Visa", _visaController),
                        const SizedBox(height: 10),
                        _buildFilePickerRow("Ticket", _ticketController),
                        const SizedBox(height: 10),
                        _buildFilePickerRow("Travel Insurance", _insuranceController),
                        const SizedBox(height: 15),

                        const Divider(),
                        const Text("Other Documents", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),

                        const SizedBox(height: 10),

                        // --- DYNAMIC EXTRA DOCUMENTS ---
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

                                  onPressed: () => _pickExtraDocument(index),
                                  child: const Text("Browse", style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isPrimary ? Icons.add_circle : Icons.delete,
                                    color: isPrimary ? const Color(0xFF3D5A5A) : Colors.red,
                                  ),
                                  onPressed: () {
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
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5A5A),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // For now, returning just the trip name
                testFirebase();
                Navigator.pop(context, _nameController.text);

              },
              child: Text(widget.existingJourney == null ? "Save" : "Update", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  // Updated Helper for TextFields with Icon Taps
  Widget _buildTextField(
      String hint,
      TextEditingController controller,
      {IconData? icon, VoidCallback? onIconTap, Color? iconColor, bool readOnly = false}
      ) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: readOnly ? onIconTap : null, // Opens calendar if field is tapped
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }

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
          hint: const Text("Travel Type", style: TextStyle(fontSize: 12)),
          items: <String>['Business', 'Vacation', 'Family'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (val) => setState(() => _selectedType = val!),
        ),
      ),
    );
  }
  Widget _buildStayAtDropdown(int index) {
    // Get all current destination names from your _destControllers
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
  Widget _buildFilePickerRow(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 12),
              hintText: "No file selected",
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D5A5A)),
        onPressed: () => _pickFile(controller), // Calls the logic above
        child: const Text("Browse Files", style: TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ],
    );
  }


}