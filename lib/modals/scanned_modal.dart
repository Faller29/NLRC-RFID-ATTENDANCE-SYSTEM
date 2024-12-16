import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScannedModal extends StatefulWidget {
  final String rfidData;
  final DateTime timestamp;
  final Map<String, dynamic> userData;
  final VoidCallback? onRemoveNotification;

  const ScannedModal({
    Key? key,
    required this.rfidData,
    required this.timestamp,
    required this.userData,
    this.onRemoveNotification,
  }) : super(key: key);

  @override
  _ScannedModalState createState() => _ScannedModalState();
}

class _ScannedModalState extends State<ScannedModal> {
  String? _selectedJobType;
  final List<String> _jobTypes = ['Office', 'OB'];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

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
                  Row(
                    children: [
                      const Text(
                        'Name:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.userData['name'] ?? 'Unknown',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                  Row(
                    children: [
                      const Text(
                        'Position:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.userData['position'] ?? 'Unknown',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Office:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.userData['office'] ?? 'Unknown',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          _saveAttendance(); // Save attendance to Firestore
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

  void _saveAttendance() async {
    try {
      final userId = widget.rfidData; // Assuming RFID is unique to the user
      final today = widget.timestamp; // Use the timestamp passed to the modal
      final monthYear =
          DateFormat('MMM_yyyy').format(today); // Get current month and year
      final day = DateFormat('dd').format(today); // Get the day
      final attendanceRef = firestore
          .collection('attendances')
          .doc(monthYear) // Collection for the current month/year
          .collection(day) // Subcollection for the current day
          .doc(userId); // Document for the specific user (RFID)

      final attendanceDoc = await attendanceRef.get();

      if (!attendanceDoc.exists) {
        // First scan, save as Time In
        await attendanceRef.set({
          'name': widget.userData['name'],
          'officeType': widget.userData['office'],
          'timeIn': widget.timestamp, // Use the timestamp passed to the modal
          'timeOut': null,
        });
        debugPrint('Time In saved for $monthYear $day');
      } else {
        // If Time In exists, update Time Out
        await attendanceRef.update({
          'timeOut': widget.timestamp, // Use the timestamp passed to the modal
        });
        debugPrint('Time Out saved for $monthYear $day');
      }
    } catch (e) {
      debugPrint('Error saving attendance: $e');
    }
  }

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