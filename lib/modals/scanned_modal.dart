import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScannedModal extends StatefulWidget {
  final String rfidData;
  final DateTime timestamp; // Add timestamp field
  final VoidCallback?
      onRemoveNotification; // Callback for removing notifications

  const ScannedModal({
    Key? key,
    required this.rfidData,
    required this.timestamp,
    this.onRemoveNotification,
  }) : super(key: key);

  @override
  _ScannedModalState createState() => _ScannedModalState();
}

class _ScannedModalState extends State<ScannedModal> {
  String? _selectedJobType; // To store the selected job type
  final List<String> _jobTypes = ['Office', 'OB']; // Dropdown options

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Material(
          color: Colors.transparent,
          child: Card(
            color: Colors.white,
            margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'RFID Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // RFID Information
                  Row(
                    children: [
                      const Text(
                        'RFID:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.rfidData,
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Row(
                    children: [
                      Text(
                        'Name:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'John Peter Faller',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Display the time logged from the passed timestamp
                  Row(
                    children: [
                      const Text(
                        'Time Logged:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatTimestamp(widget.timestamp),
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Row(
                    children: [
                      Text(
                        'Position:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Master ni Renzy',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Field Type Dropdown
                  Row(
                    children: [
                      const Text(
                        'Field type:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedJobType,
                          items: _jobTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedJobType = newValue;
                            });
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          hint: const Text('Select job type'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close modal
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent),
                        onPressed: () {
                          if (widget.onRemoveNotification != null) {
                            widget
                                .onRemoveNotification!(); // Remove notification
                          }
                          _logAction();
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Submit',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void _logAction() async {
    try {
      // Save the "logged" entry in Firestore
      await firestore.collection('logs').add({
        'action': 'logged', // Action description
        'timestamp': FieldValue.serverTimestamp(), // Current timestamp
      });
      debugPrint('Action logged successfully!');
    } catch (e) {
      debugPrint('Failed to log action: $e');
    }
  }

  // Helper function to get the current time in 12-hour format with AM/PM
  String _formatTimestamp(DateTime timestamp) {
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(timestamp);
  }
}








/* import 'package:flutter/material.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';

scannedModal(BuildContext context) {
  showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Card(
            margin: EdgeInsets.all(8.0),
            child: Center(
                child: Column(
              children: [
                Text("data"),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("data"))
              ],
            )),
          ),
        );
      });
}*/