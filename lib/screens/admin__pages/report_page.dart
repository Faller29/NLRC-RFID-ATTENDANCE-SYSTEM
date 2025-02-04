import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:pdf/pdf.dart'; // For PDF generation
import 'package:pdf/widgets.dart' as pw; // PDF Widgets
import 'package:printing/printing.dart'; // For printing PDFs
import 'package:flutter/services.dart'; // For loading images
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:file_picker/file_picker.dart';

class ReportPage extends StatefulWidget {
  @override
  _ReportPage createState() => _ReportPage();
}

class _ReportPage extends State<ReportPage> {
  Map<String, String> _nameToRfid = {}; // Map to store name-to-rfid mapping
  List<String> _names = []; // List to store only the names
  String? _selectedName; // Selected name
  String? _selectedRfid; // Selected RFID for the selected name
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  DateTime? selectedMonth;
  DateTime? selectedDate1;

  DateTimeRange? selectedDateRange;
  bool isEditMode = false; // Add this state variable
  int editClicks = 0;
  @override
  void initState() {
    super.initState();
    fetchUsers(); // Fetch data on initialization
  }

  void adjustDate(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
  }

  // Add controllers for timeIn and timeOut
  final TextEditingController _timeInController = TextEditingController();
  final TextEditingController _timeOutController = TextEditingController();
  String? _userIdToEdit;
  String? _selectedDateToEdit;
  @override
  void dispose() {
    _timeInController.dispose();
    _timeOutController.dispose();
    super.dispose();
  }

  void _showEditAttendanceModal(
      String? userId, Map<String, dynamic> user, String date) {
    _userIdToEdit = userId;
    _selectedDateToEdit = date; // Store the date for use during update

    _timeInController.text = _parseTime(user['timeIn']);
    _timeOutController.text = _parseTime(user['timeOut']);

    showDialog(
      context: context,
      builder: (context) {
        return _buildAttendanceFormDialog(() => _updateAttendance());
      },
    );
  }

  String _parseTime(dynamic time) {
    if (time is Timestamp) {
      return DateFormat('hh:mm a').format(time.toDate());
    } else if (time is String) {
      return time;
    }
    return '';
  }

  void _selectTime(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) async {
    // Parse the existing time in the controller to retain its date
    DateTime originalDateTime;
    try {
      originalDateTime = DateFormat('hh:mm a').parse(controller.text);
    } catch (_) {
      originalDateTime =
          DateTime.now(); // Fallback to current time if parsing fails
    }

    final initialTime = TimeOfDay.fromDateTime(originalDateTime);

    // Show the time picker dialog
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select $label',
      initialEntryMode:
          TimePickerEntryMode.input, // Set default to text input mode
    );

    if (pickedTime != null) {
      // Combine the original date with the new time selected
      final updatedDateTime = DateTime(
        originalDateTime.year,
        originalDateTime.month,
        originalDateTime.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // Update the controller text with the new time while retaining the original date
      controller.text = DateFormat('hh:mm a').format(updatedDateTime);
    }
  }

  void _updateAttendance() async {
    final timeInText = _timeInController.text.trim();
    final timeOutText = _timeOutController.text.trim();
    DateTime? timeOut;
    try {
      // Parse the input times
      final timeIn = DateFormat('hh:mm a').parse(timeInText);
      print(timeOutText);
      if (timeOutText.isNotEmpty) {
        timeOut = DateFormat('hh:mm a').parse(timeOutText);
      } else {
        timeOut = null;
      }
      /* if (timeIn == null || timeOut == null) {
        throw FormatException("Invalid time format");
      } */

      // Fetch the attendance document by `rfid` and `date`
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('user_attendances')
          .where('rfid',
              isEqualTo: _userIdToEdit) // RFID as the unique identifier
          .where('date', isEqualTo: _selectedDateToEdit) // Selected date
          .limit(1)
          .get();

      if (attendanceQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed('Attendance record not found.', context),
        );
        return;
      }

      // Extract the attendance document
      final attendanceDoc = attendanceQuery.docs.first;

      // Extract existing `timeIn` date for reference
      final existingTimeIn = (attendanceDoc['timeIn'] as Timestamp).toDate();

      // Combine the existing date with the new time inputs
      final updatedTimeIn = DateTime(
        existingTimeIn.year,
        existingTimeIn.month,
        existingTimeIn.day,
        timeIn.hour,
        timeIn.minute,
      );

      if (timeOut != null) {
        final updatedTimeOut = DateTime(
          existingTimeIn.year,
          existingTimeIn.month,
          existingTimeIn.day,
          timeOut!.hour,
          timeOut!.minute,
        );
        if (updatedTimeIn.isAfter(updatedTimeOut)) {
          ScaffoldMessenger.of(context).showSnackBar(
            snackBarFailed('Time In must be before Time Out.', context),
          );
          return;
        }
        await FirebaseFirestore.instance
            .collection('user_attendances')
            .doc(attendanceDoc.id) // Use the document ID from the query
            .update({
          'timeIn': Timestamp.fromDate(updatedTimeIn),
          'timeOut': Timestamp.fromDate(updatedTimeOut),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('user_attendances')
            .doc(attendanceDoc.id) // Use the document ID from the query
            .update({
          'timeIn': Timestamp.fromDate(updatedTimeIn),
        });
      }
      // Validate that Time In is before Time Out

      // Update the Firestore document

      // Trigger a UI update
      setState(() {
        // Update local variables or state if necessary
      });

      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarSuccess('Time Updated Successfully!', context),
      );
    } catch (e) {
      debugPrint('Error updating attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed(
            'Both Time In and Time Out fields are required.', context),
      );
    }
  }

  Widget _buildAttendanceFormDialog(VoidCallback onSave) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _buildTimePicker('Time In', _timeInController),
              SizedBox(height: 8),
              _buildTimePicker('Time Out', _timeOutController),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.close),
                    label: Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Save'),
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () => _selectTime(context, controller, label),
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.access_time),
          ),
          readOnly: true,
        ),
      ),
    );
  }

// Helper function to build text fields
  Future<void> pickCustomDateRange(BuildContext parentContext) async {
    DateTime startDate = selectedDateRange?.start ??
        DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = selectedDateRange?.end ?? DateTime.now();

    final pickedRange = await showDialog<DateTimeRange>(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        DateTime tempStart = startDate;
        DateTime tempEnd = endDate;

        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setState) {
            return AlertDialog(
              title: Center(
                  child: const Text(
                'Generate Workers Data',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )),
              content: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Start Date:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(
                                69, 90, 100, 1), // Background color
                            foregroundColor:
                                Colors.white, // Foreground (text) color
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: tempStart,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                tempStart = picked;
                              });
                            }
                          },
                          child: Text(
                            '${tempStart.toLocal()}'.split(' ')[0],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'End Date:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(
                                69, 90, 100, 1), // Background color
                            foregroundColor:
                                Colors.white, // Foreground (text) color
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: tempEnd,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                tempEnd = picked;
                              });
                            }
                          },
                          child: Text(
                            '${tempEnd.toLocal()}'.split(' ')[0],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Compare only the date parts (ignoring time)
                        if (tempStart.year == tempEnd.year &&
                            tempStart.month == tempEnd.month &&
                            tempStart.day == tempEnd.day) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            snackBarFailed(
                              'Start and end dates cannot be the same.',
                              parentContext,
                            ),
                          );
                        } else if (tempStart.isAfter(tempEnd)) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            snackBarFailed(
                              'Start date cannot be later than end date.',
                              parentContext,
                            ),
                          );
                        } else {
                          Navigator.pop(dialogContext,
                              DateTimeRange(start: tempStart, end: tempEnd));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedRange != null) {
      // Update the global selectedDateRange and UI
      setState(() {
        selectedDateRange = pickedRange;
      });
    }
  }

  Future<List<Map<String, String>>> fetchAttendanceData1() async {
    try {
      if (selectedDateRange == null) return [];

      // Use a Map to aggregate data by RFID
      Map<String, Map<String, dynamic>> aggregatedData = {};

      DateTime currentDate = selectedDateRange!.start;

      while (currentDate.isBefore(selectedDateRange!.end) ||
          currentDate.isAtSameMomentAs(selectedDateRange!.end)) {
        // Format the current date in "MM_dd_yyyy"
        String formattedDate = DateFormat('MM_dd_yyyy').format(currentDate);

        // Reference to the `user_attendances` collection
        CollectionReference userAttendanceCollection =
            FirebaseFirestore.instance.collection('user_attendances');

        // Fetch all documents in the `user_attendances` collection
        QuerySnapshot snapshot =
            await userAttendanceCollection.orderBy('name').get();

        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Match the document's date with the formatted date
          if (data['date'] == formattedDate) {
            String rfid = data['rfid'] ?? '';
            String name = data['name'] ?? '';

            DateTime? timeIn =
                data['timeIn'] != null ? data['timeIn'].toDate() : null;
            DateTime? timeOut =
                data['timeOut'] != null ? data['timeOut'].toDate() : null;

            int totalMinutes = _calculateTotalMinutes(timeIn, timeOut);

            // Adjust total minutes if timeIn is before 12 PM
            if (timeIn != null && timeIn.hour < 12) {
              if (totalMinutes > 60) {
                totalMinutes -= 60;
              } else {
                totalMinutes = 0;
              }
            }

            // If the RFID is already in the aggregated data, add their minutes
            if (aggregatedData.containsKey(rfid)) {
              aggregatedData[rfid]!['totalMinutes'] += totalMinutes;
            } else {
              // Otherwise, initialize their data
              aggregatedData[rfid] = {
                'rfid': rfid,
                'name': name,
                'totalMinutes': totalMinutes,
              };
            }
          }
        }

        // Move to the next day
        currentDate = currentDate.add(Duration(days: 1));
      }

      // Convert aggregated data to a list
      return aggregatedData.entries.map((entry) {
        int totalMinutes = entry.value['totalMinutes'] as int;
        int hours = totalMinutes ~/ 60;
        int minutes = totalMinutes % 60;

        // Determine the correct singular or plural form for hours and minutes
        String hourText = hours == 1 ? 'hour' : 'hours';
        String minuteText = minutes == 1 ? 'minute' : 'minutes';

        return {
          'rfid': entry.value['rfid'] as String,
          'name': entry.value['name'] as String,
          'totalHours':
              '${hours > 0 ? '$hours $hourText ' : ''}${minutes > 0 ? '$minutes $minuteText' : ''}'
                  .trim(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      return [];
    }
  }

  int _calculateTotalMinutes(DateTime? timeIn, DateTime? timeOut) {
    if (timeIn == null || timeOut == null) return 0;
    try {
      Duration diff = timeOut.difference(timeIn);
      return diff.inMinutes;
    } catch (e) {
      debugPrint('Error calculating total minutes: $e');
      return 0;
    }
  }

  Future<void> pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> pickDate1() async {
    final DateTime? pickedDate1 = await showDatePicker(
      context: context,
      initialDate: selectedDate1 ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate1 != null && pickedDate1 != selectedDate1) {
      setState(() {
        selectedDate1 = pickedDate1;
      });
    }
  }

  Future<List<Map<String, String>>> fetchAttendanceData() async {
    try {
      // Format the selectedDate to match the custom format "MM_dd_yyyy"
      String selectedDateFormatted =
          DateFormat('MM_dd_yyyy').format(selectedDate);

      // Reference to the `user_attendances` collection
      CollectionReference userAttendanceCollection =
          FirebaseFirestore.instance.collection('user_attendances');

      // Fetch all documents in the `user_attendances` collection
      QuerySnapshot userSnapshots =
          await userAttendanceCollection.orderBy('name').get();

      // Initialize the attendance data list
      List<Map<String, String>> attendanceData = [];

      // Process each document
      for (var userDoc in userSnapshots.docs) {
        String userId = userDoc.id; // Document ID
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // Check if the document's date matches the selected date
        String? recordDate =
            userData['date']; // Custom date field in the document
        if (recordDate == selectedDateFormatted) {
          // Extract additional fields
          String name = userData['name'] ?? '';
          String rfid = userData['rfid'] ?? '';
          DateTime? timeIn =
              userData['timeIn'] != null ? userData['timeIn'].toDate() : null;
          DateTime? timeOut =
              userData['timeOut'] != null ? userData['timeOut'].toDate() : null;

          int totalMinutes = _calculateTotalMinutes(timeIn, timeOut);
          int hours = totalMinutes ~/ 60;
          int minutes = totalMinutes % 60;

          // Subtract 1 hour if timeIn is before 12 PM
          if (timeIn != null && timeIn.hour < 12) {
            if (hours > 1 || (hours == 1 && minutes > 0)) {
              totalMinutes -= 60;
              hours = totalMinutes ~/ 60;
              minutes = totalMinutes % 60;
            } else {
              // Set total hours to 0 if less than 1 hour
              hours = 0;
              minutes = 0;
            }
          }

          // Determine the correct singular or plural form for hours and minutes
          String hourText = hours == 1 ? 'hour' : 'hours';
          String minuteText = minutes == 1 ? 'minute' : 'minutes';

          // Add the document's attendance data to the list
          attendanceData.add({
            'id': userId, // Include the document ID
            'name': name, // Include the user's name
            'rfid': rfid, // Include the user's RFID
            'timeIn': timeIn != null
                ? DateFormat('hh:mm a').format(timeIn)
                : '', // Formatted timeIn
            'timeOut': timeOut != null
                ? DateFormat('hh:mm a').format(timeOut)
                : '', // Formatted timeOut
            'totalHours':
                '${hours > 0 ? '$hours $hourText ' : ''}${minutes > 0 ? '$minutes $minuteText' : ''}'
                    .trim(),
            'date':
                recordDate ?? '', // Directly include the document's date field
          });
        }
      }

      return attendanceData;
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> fetchAttendanceDataToday() async {
    try {
      // Format the selectedDate to match the custom format "MM_dd_yyyy"
      String selectedDateFormatted =
          DateFormat('MM_dd_yyyy').format(selectedDate1!);

      // Reference to the `user_attendances` collection
      CollectionReference userAttendanceCollection =
          FirebaseFirestore.instance.collection('user_attendances');

      // Fetch all documents in the `user_attendances` collection
      QuerySnapshot userSnapshots =
          await userAttendanceCollection.orderBy('name').get();

      // Initialize the attendance data list
      List<Map<String, String>> attendanceData = [];

      // Process each document
      for (var userDoc in userSnapshots.docs) {
        String userId = userDoc.id; // Document ID
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // Check if the document's date matches the selected date
        String? recordDate =
            userData['date']; // Custom date field in the document
        if (recordDate == selectedDateFormatted) {
          // Extract additional fields
          String name = userData['name'] ?? '';
          String rfid = userData['rfid'] ?? '';
          DateTime? timeIn =
              userData['timeIn'] != null ? userData['timeIn'].toDate() : null;
          DateTime? timeOut =
              userData['timeOut'] != null ? userData['timeOut'].toDate() : null;

          int totalMinutes = _calculateTotalMinutes(timeIn, timeOut);

          // Adjust total minutes if timeIn is before 12 PM
          if (timeIn != null && timeIn.hour < 12) {
            if (totalMinutes > 60) {
              totalMinutes -= 60;
            } else {
              totalMinutes = 0;
            }
          }

          int hours = totalMinutes ~/ 60;
          int minutes = totalMinutes % 60;

          // Determine the correct singular or plural form for hours and minutes
          String hourText = hours == 1 ? 'hour' : 'hours';
          String minuteText = minutes == 1 ? 'minute' : 'minutes';

          // Add the document's attendance data to the list
          attendanceData.add({
            'id': userId, // Include the document ID
            'name': name, // Include the user's name
            'rfid': rfid, // Include the user's RFID
            'timeIn': timeIn != null
                ? DateFormat('hh:mm a').format(timeIn)
                : '', // Formatted timeIn
            'timeOut': timeOut != null
                ? DateFormat('hh:mm a').format(timeOut)
                : '', // Formatted timeOut
            'totalHours':
                '${hours > 0 ? '$hours $hourText ' : ''}${minutes > 0 ? '$minutes $minuteText' : ''}'
                    .trim(),
            'date':
                recordDate ?? '', // Directly include the document's date field
          });
        }
      }

      return attendanceData;
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      return [];
    }
  }

  Future<void> fetchUsers() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .get(); // Get all documents in the 'users' collection

      // Create a name-to-rfid mapping and a list of names
      Map<String, String> nameToRfid = {};
      querySnapshot.docs.forEach((doc) {
        String name = doc['name'] as String;
        String rfid = doc['rfid'] as String;
        nameToRfid[name] = rfid;
      });

      setState(() {
        _nameToRfid = nameToRfid; // Update the map
        _names = nameToRfid.keys.toList(); // Extract names
      });
    } catch (e) {
      debugPrint('Error fetching user names and rfids: $e');
    }
  }

  Future<List<Map<String, String>>> fetchAttendanceData2() async {
    try {
      if (selectedMonth == null) return [];

      // Use a map to aggregate data by day
      Map<String, Map<String, dynamic>> aggregatedData = {};

      // Get number of days in the selected month
      int daysInMonth =
          DateUtils.getDaysInMonth(selectedMonth!.year, selectedMonth!.month);

      for (int day = 1; day <= daysInMonth; day++) {
        String formattedDate = DateFormat('MM_dd_yyyy').format(
          DateTime(selectedMonth!.year, selectedMonth!.month, day),
        );

        // Reference to the user_attendances collection
        CollectionReference userAttendanceCollection =
            FirebaseFirestore.instance.collection('user_attendances');

        // Fetch documents matching the formatted date and RFID
        QuerySnapshot snapshot = await userAttendanceCollection
            .where('rfid', isEqualTo: _selectedRfid)
            .where('date', isEqualTo: formattedDate)
            .get();

        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          DateTime? timeIn =
              data['timeIn'] != null ? data['timeIn'].toDate() : null;
          DateTime? timeOut =
              data['timeOut'] != null ? data['timeOut'].toDate() : null;

          int totalMinutes = _calculateTotalMinutes(timeIn, timeOut);

          // Adjust total minutes if timeIn is before 12 PM
          if (timeIn != null && timeIn.hour < 12) {
            totalMinutes = totalMinutes > 60 ? totalMinutes - 60 : 0;
          }

          // Store aggregated data for the specific day
          aggregatedData[formattedDate] = {
            'monthYear': DateFormat('MMM dd').format(
                DateTime(selectedMonth!.year, selectedMonth!.month, day)),
            'rfid': data['rfid'] ?? '',
            'timeIn':
                timeIn != null ? DateFormat('hh:mm a').format(timeIn) : '',
            'timeOut':
                timeOut != null ? DateFormat('hh:mm a').format(timeOut) : '',
            'totalMinutes': totalMinutes,
          };
        }
      }

      // Convert aggregated data into a list format
      return aggregatedData.entries.map((entry) {
        int totalMinutes = entry.value['totalMinutes'] as int;
        int hours = totalMinutes ~/ 60;
        int minutes = totalMinutes % 60;

        String hourText = hours == 1 ? 'hour' : 'hours';
        String minuteText = minutes == 1 ? 'minute' : 'minutes';

        return {
          'monthYear': entry.value['monthYear'] as String,
          'rfid': entry.value['rfid'] as String,
          'timeIn': entry.value['timeIn'] as String,
          'timeOut': entry.value['timeOut'] as String,
          'totalHours':
              '${hours > 0 ? '$hours $hourText ' : ''}${minutes > 0 ? '$minutes $minuteText' : ''}'
                  .trim(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      return [];
    }
  }

  Future<void> generateAndPrintPDF(BuildContext context) async {
    bool isLoadingDialogOpen = false;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        isLoadingDialogOpen = true; // Set the flag
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Generating PDF, Please wait a moment..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      final attendanceData = await fetchAttendanceData2();

      // Check if attendance data is empty
      if (attendanceData == null || attendanceData.isEmpty) {
        if (isLoadingDialogOpen) {
          Navigator.pop(context); // Close the loading dialog
          isLoadingDialogOpen = false; // Reset the flag
        }

        // Show a snackbar or dialog to notify the user
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed(
            'No records found to generate PDF',
            context,
          ),
        );

        return; // Stop further execution
      }

      final pdf = pw.Document();
      final ByteData imageData =
          await rootBundle.load('lib/assets/images/NLRC.jpg');
      final Uint8List imageBytes = imageData.buffer.asUint8List();

      final ByteData imageData1 =
          await rootBundle.load('lib/assets/images/BAGONG_PILIPINAS.png');
      final Uint8List imageBytes1 = imageData1.buffer.asUint8List();

      final ByteData imageData2 =
          await rootBundle.load('lib/assets/images/AB.jpg');
      final Uint8List imageBytes2 = imageData2.buffer.asUint8List();

      final logo = pw.MemoryImage(imageBytes);
      final logo1 = pw.MemoryImage(imageBytes1);
      final logo2 = pw.MemoryImage(imageBytes2);

      // Ensure the employee name is fetched using RFID
      String employeeName = _selectedName ?? 'Employee Name';

      // Calculate total hours
      int totalMinutes = attendanceData.fold(0, (sum, data) {
        String totalHoursString = data['totalHours'] ?? '0 hours 0 minutes';
        final regex = RegExp(r'(\d+)\s*hours?\s*(\d+)?\s*minutes?');
        final match = regex.firstMatch(totalHoursString);

        int hours = 0;
        int minutes = 0;
        if (match != null) {
          hours = int.parse(match.group(1) ?? '0');
          minutes = int.parse(match.group(2) ?? '0');
        }
        return sum + (hours * 60) + minutes;
      });

      int overallHours = totalMinutes ~/ 60;
      int overallMinutes = totalMinutes % 60;
      String hourText = overallHours == 1 ? 'hour' : 'hours';
      String minuteText = overallMinutes == 1 ? 'minute' : 'minutes';

      const int rowsPerPage = 20;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.only(top: 20, bottom: 20, left: 40, right: 40),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.SizedBox(width: 30),
                  pw.Image(logo, width: 65, height: 65),
                  pw.SizedBox(width: 30),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Republic of the Philippines',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Department of Labor and Employment',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('NATIONAL LABOR RELATIONS COMMISSION',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('REGIONAL ARBITRATION BRANCH No. IV',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('3rd & 4th Floor, Hectan Penthouse, Chipeco Ave.',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Brgy. Halang, Calamba City, Laguna',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Attendance Report',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black)),
                    ],
                  ),
                  pw.SizedBox(width: 5),
                  pw.Image(logo1, width: 65, height: 65),
                  pw.SizedBox(width: 5),
                  pw.Image(logo2, width: 65, height: 45),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 5),
            ],
          ),
          build: (context) {
            final totalPages = (attendanceData.length / rowsPerPage).ceil();
            final chunks = List.generate(
              totalPages,
              (i) => attendanceData
                  .skip(i * rowsPerPage)
                  .take(rowsPerPage)
                  .toList(),
            );

            return chunks.map((chunk) {
              return pw.Column(
                children: [
                  pw.Text('$employeeName',
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black)),
                  pw.Text(DateFormat.yMMM().format(selectedMonth!),
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.black)),
                  pw.SizedBox(height: 10),
                  pw.Table.fromTextArray(
                    headers: ['Date', 'Time In', 'Time Out', 'Total Hours'],
                    data: [
                      ...chunk.map((employee) {
                        return [
                          employee['monthYear'] ?? '',
                          employee['timeIn'] ?? '',
                          employee['timeOut'] ?? '',
                          employee['totalHours'] ?? '',
                        ];
                      }).toList(),
                    ],
                    border:
                        pw.TableBorder.all(color: PdfColors.black, width: 1),
                    cellAlignment: pw.Alignment.center,
                    headerStyle: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.black),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    cellPadding: const pw.EdgeInsets.all(8),
                  ),
                ],
              );
            }).toList();
          },
        ),
      );

      // Convert the PDF document to bytes
      Uint8List pdfBytes = await pdf.save();
      final userProfile =
          Platform.environment['USERPROFILE']; // Get the user's home directory
      final directoryPath =
          '$userProfile\\Documents\\NLRC\\Attendance Report (BY MONTH)';

      // Ensure the NLRC directory exists
      final Directory nlrcDirectory = Directory(directoryPath);
      if (!nlrcDirectory.existsSync()) {
        // If NLRC directory does not exist, create it
        nlrcDirectory.createSync(recursive: true);
      }

      // Dismiss the loading dialog before opening the "Save As" dialog
      if (isLoadingDialogOpen) {
        Navigator.pop(context); // Close the loading dialog
        isLoadingDialogOpen = false; // Reset the flag
      }

      // Show the PDF preview dialog
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Text('PDF Preview'),
              actions: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Color.fromRGBO(69, 90, 100, 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.download, color: Colors.white),
                  label: Text('Download PDF',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      )),
                  onPressed: () async {
                    Navigator.pop(context); // Close the preview dialog
                    final Uint8List pdfBytes = await pdf.save();

                    // Use FilePicker to prompt the user with a "Save As" dialog
                    String? outputFilePath = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save PDF File',
                      fileName:
                          '$_selectedName - ${DateFormat.yMMM().format(selectedMonth!)}.pdf',
                      allowedExtensions: ['pdf'],
                      initialDirectory: directoryPath,
                      type: FileType.custom,
                    );

                    // If the user cancels the save dialog, exit
                    if (outputFilePath == null) {
                      return;
                    }

                    // Ensure the file name ends with .pdf
                    if (!outputFilePath.endsWith('.pdf')) {
                      outputFilePath = '$outputFilePath.pdf';
                    }

                    // Save the PDF file to the selected location
                    final file = File(outputFilePath);
                    await file.writeAsBytes(pdfBytes);

                    // Optionally, open the file after saving
                    try {
                      await Process.start('explorer', [outputFilePath]);
                    } catch (e) {
                      print("Error opening file: $e");
                    }
                  },
                ),
                SizedBox(width: 10),
              ],
            ),
            body: PdfPreview(
              build: (format) => pdf.save(),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              maxPageWidth: 750,
              initialPageFormat:
                  PdfPageFormat.a4, // Set default zoom to fit content
            ),
          );
        },
      );
    } catch (e) {
      print("Error: $e");
      if (isLoadingDialogOpen) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(snackBarFailed('Failed to generate PDF', context));
    }
  }

  Future<void> generateAndPrintPDFbyDay(BuildContext context) async {
    bool isLoadingDialogOpen = false;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        isLoadingDialogOpen = true; // Set the flag
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Generating PDF, Please wait a moment..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      final attendanceData = await fetchAttendanceDataToday();

      // Check if attendance data is empty
      if (attendanceData == null || attendanceData.isEmpty) {
        if (isLoadingDialogOpen) {
          Navigator.pop(context); // Close the loading dialog
          isLoadingDialogOpen = false; // Reset the flag
        }

        // Show a snackbar or dialog to notify the user
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed(
            'No records found to generate PDF',
            context,
          ),
        );

        return; // Stop further execution
      }

      final pdf = pw.Document();
      final ByteData imageData =
          await rootBundle.load('lib/assets/images/NLRC.jpg');
      final Uint8List imageBytes = imageData.buffer.asUint8List();

      final ByteData imageData1 =
          await rootBundle.load('lib/assets/images/BAGONG_PILIPINAS.png');
      final Uint8List imageBytes1 = imageData1.buffer.asUint8List();

      final ByteData imageData2 =
          await rootBundle.load('lib/assets/images/AB.jpg');
      final Uint8List imageBytes2 = imageData2.buffer.asUint8List();

      final logo = pw.MemoryImage(imageBytes);
      final logo1 = pw.MemoryImage(imageBytes1);
      final logo2 = pw.MemoryImage(imageBytes2);

      const int rowsPerPage =
          23; // Adjust based on your layout and desired number of rows per page

      attendanceData
          .sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.only(top: 20, bottom: 20, left: 40, right: 40),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.SizedBox(width: 30),
                  pw.Image(logo, width: 65, height: 65),
                  pw.SizedBox(width: 30),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Republic of the Philippines',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Department of Labor and Employment',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('NATIONAL LABOR RELATIONS COMMISSION',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('REGIONAL ARBITRATION BRANCH No. IV',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '3rd & 4th Floor, Hectan Penthouse, Chipeco Ave.,',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Brgy. Halang, Calamba City, Laguna',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Attendance Report',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black)),
                    ],
                  ),
                  pw.SizedBox(width: 5),
                  pw.Image(logo1, width: 65, height: 65),
                  pw.SizedBox(width: 5),
                  pw.Image(logo2, width: 65, height: 45),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(DateFormat('MMM dd, yyyy').format(selectedDate1!),
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
              pw.SizedBox(height: 10),
            ],
          ),
          build: (context) {
            final totalPages = (attendanceData.length / rowsPerPage).ceil();

            final chunks = List.generate(
              totalPages,
              (i) => attendanceData
                  .skip(i * rowsPerPage)
                  .take(rowsPerPage)
                  .toList(),
            );

            return chunks.map((chunk) {
              return pw.Table.fromTextArray(
                headers: ['Name', 'Time In', 'Time Out', 'Total Hours'],
                data: chunk.map((employee) {
                  return [
                    employee['name'] ?? '',
                    employee['timeIn'] ?? '',
                    employee['timeOut'] ?? '',
                    employee['totalHours'] ?? '',
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.black),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(8),
              );
            }).toList();
          },
        ),
      );

      // Convert the PDF document to bytes
      Uint8List pdfBytes = await pdf.save();
      final userProfile =
          Platform.environment['USERPROFILE']; // Get the user's home directory
      final directoryPath =
          '$userProfile\\Documents\\NLRC\\Attendance Report (BY DAY)';

      // Ensure the NLRC directory exists
      final Directory nlrcDirectory = Directory(directoryPath);
      if (!nlrcDirectory.existsSync()) {
        // If NLRC directory does not exist, create it
        nlrcDirectory.createSync(recursive: true);
      }

      // Dismiss the loading dialog before opening the "Save As" dialog
      if (isLoadingDialogOpen) {
        Navigator.pop(context); // Close the loading dialog
        isLoadingDialogOpen = false; // Reset the flag
      }

      // Show the PDF preview dialog
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Text('PDF Preview'),
              actions: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Color.fromRGBO(69, 90, 100, 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.download, color: Colors.white),
                  label: Text('Download PDF',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      )),
                  onPressed: () async {
                    Navigator.pop(context); // Close the preview dialog
                    final Uint8List pdfBytes = await pdf.save();

                    // Use FilePicker to prompt the user with a "Save As" dialog
                    String? outputFilePath = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save PDF File',
                      fileName:
                          'Attendance Report in ${DateFormat.yMMMd().format(selectedDate1!)}.pdf',
                      allowedExtensions: ['pdf'],
                      initialDirectory: directoryPath,
                      type: FileType.custom,
                    );

                    // If the user cancels the save dialog, exit
                    if (outputFilePath == null) {
                      return;
                    }

                    // Ensure the file name ends with .pdf
                    if (!outputFilePath.endsWith('.pdf')) {
                      outputFilePath = '$outputFilePath.pdf';
                    }

                    // Save the PDF file to the selected location
                    final file = File(outputFilePath);
                    await file.writeAsBytes(pdfBytes);

                    // Optionally, open the file after saving
                    try {
                      await Process.start('explorer', [outputFilePath]);
                    } catch (e) {
                      print("Error opening file: $e");
                    }
                  },
                ),
                SizedBox(width: 10),
              ],
            ),
            body: PdfPreview(
              build: (format) => pdf.save(),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              maxPageWidth: 750,
              initialPageFormat:
                  PdfPageFormat.a4, // Set default zoom to fit content
            ),
          );
        },
      );
    } catch (e) {
      print("Error: $e");
      if (isLoadingDialogOpen) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(snackBarFailed('Failed to generate PDF', context));
    }
  }

  Future<void> generateAndPrintByRange(BuildContext context) async {
    bool isLoadingDialogOpen = false;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        isLoadingDialogOpen = true; // Set the flag
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Generating PDF, Please wait a moment..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      final attendanceData = await fetchAttendanceData1();

      // Check if attendance data is empty
      if (attendanceData == null || attendanceData.isEmpty) {
        if (isLoadingDialogOpen) {
          Navigator.pop(context); // Close the loading dialog
          isLoadingDialogOpen = false; // Reset the flag
        }

        // Show a snackbar or dialog to notify the user
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed(
            'No records found to generate PDF',
            context,
          ),
        );

        return; // Stop further execution
      }

      final pdf = pw.Document();
      final ByteData imageData =
          await rootBundle.load('lib/assets/images/NLRC.jpg');
      final Uint8List imageBytes = imageData.buffer.asUint8List();

      final ByteData imageData1 =
          await rootBundle.load('lib/assets/images/BAGONG_PILIPINAS.png');
      final Uint8List imageBytes1 = imageData1.buffer.asUint8List();

      final ByteData imageData2 =
          await rootBundle.load('lib/assets/images/AB.jpg');
      final Uint8List imageBytes2 = imageData2.buffer.asUint8List();

      final logo = pw.MemoryImage(imageBytes);
      final logo1 = pw.MemoryImage(imageBytes1);
      final logo2 = pw.MemoryImage(imageBytes2);

      const int rowsPerPage =
          23; // Adjust based on your layout and desired number of rows per page

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.only(top: 20, bottom: 20, left: 40, right: 40),
          header: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.SizedBox(width: 30),
                    pw.Image(logo, width: 65, height: 65),
                    pw.SizedBox(width: 30),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Republic of the Philippines',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('Department of Labor and Employment',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('NATIONAL LABOR RELATIONS COMMISSION',
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('REGIONAL ARBITRATION BRANCH No. IV',
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            '3rd & 4th Floor, Hectan Penthouse, Chipeco Ave.,',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('Brgy. Halang, Calamba City, Laguna',
                            style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.SizedBox(width: 5),
                    pw.Image(logo1, width: 65, height: 65),
                    pw.SizedBox(width: 5),
                    pw.Image(logo2, width: 65, height: 45),
                  ],
                ),
                pw.Divider(),
              ],
            );
          },
          build: (context) {
            final sortedData = List.from(attendanceData)
              ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

            return [
              pw.Center(
                  child: pw.Column(children: [
                pw.Text('Attendance Report',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.SizedBox(width: 5),
                pw.Text(
                  '${DateFormat.yMMMd().format(selectedDateRange!.start)} - ${DateFormat.yMMMd().format(selectedDateRange!.end)}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
                ),
              ])),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Name', 'Total Hours'],
                data: sortedData.map((employee) {
                  return [
                    employee['name'] ?? '',
                    employee['totalHours'] ?? '',
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.black),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(8),
              ),
            ];
          },
        ),
      );

      // Convert the PDF document to bytes
      Uint8List pdfBytes = await pdf.save();

      // Dismiss the loading dialog before showing the "Save As" dialog
      if (isLoadingDialogOpen) {
        Navigator.pop(context); // Close the loading dialog
        isLoadingDialogOpen = false; // Reset the flag
      }

      // Use FilePicker to prompt the user with a "Save As" dialog
      String? outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF File',
        fileName:
            'Report Attendance - ${DateFormat.yMMMd().format(selectedDateRange!.start)} - ${DateFormat.yMMMd().format(selectedDateRange!.end)}.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      // If the user cancels the save dialog, exit
      if (outputFilePath == null) {
        return;
      }

      // Ensure the file name ends with .pdf
      if (!outputFilePath.endsWith('.pdf')) {
        outputFilePath = '$outputFilePath.pdf';
      }

      // Save the PDF file to the selected location
      final file = File(outputFilePath);
      await file.writeAsBytes(pdfBytes);

      // Optionally, open the file after saving
      try {
        await Process.start('explorer', [outputFilePath]);
      } catch (e) {
        print("Error opening file: $e");
      }
    } catch (e) {
      print("Error: $e");
      if (isLoadingDialogOpen) {
        Navigator.pop(context); // Close the loading dialog
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(snackBarFailed('Failed to generate PDF', context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime currentDate = DateTime.now();
    final bool isForwardDisabled =
        selectedDate.add(Duration(days: 1)).isAfter(currentDate);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<List<List<Map<String, String>>>>(
        future: Future.wait([fetchAttendanceData1(), fetchAttendanceData()]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching data'));
          } else {
            final attendanceData1 = snapshot.data?[0] ?? [];
            final attendanceData = snapshot.data?[1] ?? [];
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
                          child: Text(
                            'REPORT ATTENDANCE',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color.fromRGBO(55, 71, 79, 1),
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      if (selectedDateRange == null)
                        SizedBox(
                            height: 33,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    const Color.fromRGBO(69, 90, 100, 1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                pickCustomDateRange(
                                    context); // Call the full-screen date range picker
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.date_range, // Date range icon
                                    color: Colors.white,
                                  ),
                                  const SizedBox(
                                      width: 8), // Space between icon and text
                                  Text(
                                    'DATE SELECT',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      if (selectedDateRange == null) const SizedBox(width: 10),
                      if (selectedDateRange == null)
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Color.fromRGBO(69, 90, 100, 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return _buildPdfGenerationDialog1(
                                    'GENERATE PDF');
                              },
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.picture_as_pdf, // PDF icon
                                color: Colors.white,
                              ),
                              const SizedBox(
                                  width: 8), // Space between icon and text
                              Text(
                                'OVERALL',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (selectedDateRange == null) const SizedBox(width: 10),
                      if (selectedDateRange == null)
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Color.fromRGBO(69, 90, 100, 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return _buildPdfGenerationDialog(
                                    'GENERATE PDF');
                              },
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.picture_as_pdf, // PDF icon
                                color: Colors.white,
                              ),
                              const SizedBox(
                                  width: 8), // Space between icon and text
                              Text(
                                'WORKER',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                    ],
                  ),
                  const Divider(
                    color: Color.fromRGBO(55, 71, 79, 1),
                    thickness: 3,
                  ),
                  if (selectedDateRange != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              iconSize: 22,
                              padding: const EdgeInsets.all(1.0),
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                setState(() {
                                  selectedDateRange = null;
                                  selectedDate = DateTime.now();
                                });
                              },
                              color: Color.fromRGBO(55, 71, 79, 1),
                            ),
                          ),
                          SizedBox(
                            width: 20,
                          ),
                          Text(
                            'Selected Date Range: ${DateFormat.yMMMd().format(selectedDateRange!.start)} - ${DateFormat.yMMMd().format(selectedDateRange!.end)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (attendanceData1.isEmpty)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Table(
                                border: TableBorder.all(
                                    color: Colors.grey, width: 1),
                                columnWidths: const {
                                  0: FlexColumnWidth(2),
                                  1: FlexColumnWidth(2),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: Colors.blueGrey,
                                    ),
                                    children: [
                                      Container(
                                        height:
                                            40, // Adjust this height to match your desired header height
                                        padding: const EdgeInsets.all(1.0),
                                        child: Stack(
                                          children: [
                                            Align(
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Name',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height:
                                            40, // Ensure the same height for consistency
                                        padding: const EdgeInsets.all(1.0),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment
                                                .center, // Align text vertically
                                            children: const [
                                              Text(
                                                'Total Hours',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Spacer(), // Pushes the text to the bottom if desired
                            Align(
                              alignment: Alignment
                                  .center, // Adjust alignment as needed
                              child: Text(
                                'No records found for this date range',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Spacer(
                                flex: 2), // Adds spacing below the text
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Table(
                              border:
                                  TableBorder.all(color: Colors.grey, width: 1),
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(2),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Colors.blueGrey,
                                  ),
                                  children: [
                                    Container(
                                      height:
                                          40, // Adjust this height to match your desired header height
                                      padding: const EdgeInsets.all(1.0),
                                      child: Stack(
                                        children: [
                                          Align(
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'Name',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      height:
                                          40, // Ensure the same height for consistency
                                      padding: const EdgeInsets.all(1.0),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment
                                              .center, // Align text vertically
                                          children: const [
                                            Text(
                                              'Total Hours',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ...attendanceData1.map((employee) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          employee['name'] ?? '',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          employee['totalHours'] ?? '',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => adjustDate(-1),
                        ),
                        TextButton(
                          onPressed: pickDate,
                          child: Text(
                            DateFormat('MMMM d, y').format(selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromRGBO(55, 71, 79, 1),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed:
                              isForwardDisabled ? null : () => adjustDate(1),
                        ),
                      ],
                    ),
                    if (attendanceData.isEmpty)
                      Expanded(
                        child: Column(
                          children: [
                            // Table appears first
                            Table(
                              border:
                                  TableBorder.all(color: Colors.grey, width: 1),
                              columnWidths: {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(2),
                                3: FlexColumnWidth(2),
                                if (isEditMode)
                                  4: FlexColumnWidth(
                                      1), // Conditionally add column width
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Colors.blueGrey,
                                  ),
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize
                                            .min, // Adjusts to content size
                                        crossAxisAlignment: CrossAxisAlignment
                                            .center, // Centers content horizontally
                                        children: [
                                          Text(
                                            'Name',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Time In',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Time Out',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Total Hours',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Add vertical space
                            const SizedBox(height: 0),
                            // Expanded widget to vertically center the text
                            Expanded(
                              child: Center(
                                child: Text(
                                  'No records found for this date',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Table(
                            border:
                                TableBorder.all(color: Colors.grey, width: 1),
                            columnWidths: {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(2),
                              if (isEditMode)
                                4: FlexColumnWidth(
                                    1), // Conditionally add column width
                            },
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Colors.blueGrey,
                                ),
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize
                                          .min, // Adjusts to content size
                                      crossAxisAlignment: CrossAxisAlignment
                                          .center, // Centers content horizontally
                                      children: [
                                        Text(
                                          'Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Time In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Time Out',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Total Hours',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (isEditMode)
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Edit Time',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                              ...attendanceData.map((employee) {
                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        employee['name'] ?? '',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        employee['timeIn'] ?? '',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        employee['timeOut'] ?? '',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        employee['totalHours'] ?? '',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    if (isEditMode)
                                      Padding(
                                        padding: const EdgeInsets.all(1.0),
                                        child: IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blueAccent),
                                          onPressed: () {
                                            final date = employee['date'] ??
                                                ''; // Provide a default empty string if null

                                            _showEditAttendanceModal(
                                              employee['rfid'], // Pass the RFID
                                              employee, // Pass the employee data map
                                              date, // Ensure the date is non-null
                                            );
                                          },
                                          /* tooltip: 'Edit Time In & Time Out', */
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: selectedDateRange == null
          ? SizedBox(
              width: 80,
              height: 80,
              child: FloatingActionButton(
                mouseCursor: SystemMouseCursors.basic,
                onPressed: () {
                  setState(() {
                    editClicks++;
                    if (isEditMode && editClicks == 2) {
                      isEditMode = !isEditMode;
                    }
                    if (editClicks == 8) {
                      isEditMode = !isEditMode; // Toggle edit mode
                      editClicks = 0;
                    }

                    print(editClicks);
                  });
                  /* ScaffoldMessenger.of(context).showSnackBar(
                    snackBarSuccess(
                      isEditMode ? 'Edit Mode Enabled' : 'Edit Mode Disabled',
                      context,
                    ),
                  ); */
                },
                backgroundColor: Colors.transparent,
                /* tooltip: 'Turn On/Off Edit Mode', */
                shape: const CircleBorder(),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3.0),
                    image: const DecorationImage(
                      image: AssetImage('lib/assets/images/NLRC.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            )
          : FloatingActionButton(
              backgroundColor: const Color.fromRGBO(69, 90, 100, 1),
              onPressed: () {
                generateAndPrintByRange(context);
              },
              tooltip: 'Download this record.',
              child: const Icon(
                Icons.picture_as_pdf,
                color: Colors.white,
                size: 28,
              ),
              shape: const CircleBorder(),
            ),
    );
  }

  Widget _buildPdfGenerationDialog(String title) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Center(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Generate individual worker data for the selected Date',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black38,
                      fontWeight: FontWeight.bold,
                      height: 0.9,
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  )
                ],
              ),
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: _names.isEmpty
                      ? CircularProgressIndicator()
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedName,
                            hint: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 16.0,
                              ),
                              child: Text(
                                _selectedName ?? "SELECT A USER",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            isExpanded: true,
                            items: _names.map((name) {
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedName = value; // Set selected name
                                _selectedRfid = _nameToRfid[
                                    value]; // Get RFID for selected name
                              });
                            },
                            underline: SizedBox.shrink(),
                            selectedItemBuilder: (BuildContext context) {
                              return _names.map<Widget>((String item) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.0,
                                      horizontal: 16.0,
                                    ),
                                    child: Text(item),
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          selectedMonth != null
                              ? 'Selected Date: ${selectedMonth != null ? DateFormat.yMMM().format(selectedMonth!) : "--"}'
                              : 'Selected Date: --',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(55, 71, 79, 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit
                      .scaleDown, // Ensures the content scales down to fit
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(69, 90, 100, 1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          final DateTime today = DateTime.now();
                          final DateTime dynamicLastDate =
                              DateTime(today.year, today.month + 1, 0);

                          showMonthPicker(
                            context: context,
                            initialDate: selectedMonth ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: dynamicLastDate,
                            headerTitle: Text(
                              'Choose Month & Year',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            monthPickerDialogSettings:
                                MonthPickerDialogSettings(
                              headerSettings: PickerHeaderSettings(
                                headerBackgroundColor:
                                    const Color.fromRGBO(55, 71, 79, 1),
                                headerPadding: const EdgeInsets.all(30),
                                headerCurrentPageTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                headerSelectedIntervalTextStyle:
                                    const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              dialogSettings: PickerDialogSettings(
                                forcePortrait: true,
                                dialogRoundedCornersRadius: 20,
                                dialogBackgroundColor: Colors.blueGrey[50],
                              ),
                              dateButtonsSettings: PickerDateButtonsSettings(
                                selectedMonthBackgroundColor: Colors.blueGrey,
                                selectedMonthTextColor: Colors.white,
                                unselectedMonthsTextColor: Colors.black,
                                currentMonthTextColor: Colors.black,
                                yearTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                                monthTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ).then((dateMonth) {
                            if (dateMonth != null) {
                              setState(() {
                                selectedMonth = dateMonth;
                              });
                            }
                          });
                        },
                        child: const Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedName = null; // Reset selected name
                      _selectedRfid = null; // Reset selected RFID
                      selectedMonth = null; // Reset selected month
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
                Tooltip(
                  message: _selectedName != null && selectedMonth != null
                      ? 'Generate PDF'
                      : 'Please Select a User and Date',
                  child: TextButton(
                    onPressed: (_selectedName != null && selectedMonth != null)
                        ? () {
                            generateAndPrintPDF(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (_selectedName != null && selectedMonth != null)
                              ? Colors.green
                              : Colors.grey,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.grey[300],
                      padding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPdfGenerationDialog1(String title) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Center(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Generate workers data for the selected Date',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black38,
                      fontWeight: FontWeight.bold,
                      height: 0.9,
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  )
                ],
              ),
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    selectedDate1 != null
                        ? 'Selected Date: ${selectedDate1 != null ? DateFormat.yMMMd().format(selectedDate1!) : "--"}'
                        : 'Selected Date: --',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(55, 71, 79, 1),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                FittedBox(
                  fit: BoxFit
                      .scaleDown, // Ensures the content scales down to fit
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(69, 90, 100, 1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      showDatePicker(
                        context: context,
                        initialDate: selectedDate1 ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      ).then((dateToday) {
                        if (dateToday != null) {
                          setState(() {
                            selectedDate1 = dateToday;
                          });
                        }
                      });
                    },
                    child: const Text(
                      'Choose a Date',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      selectedDate1 = null; // Reset selected month
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
                Tooltip(
                  message: selectedDate1 != null
                      ? 'Generate PDF'
                      : 'Please Select a Date',
                  child: TextButton(
                    onPressed: (selectedDate1 != null)
                        ? () {
                            generateAndPrintPDFbyDay(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (selectedDate1 != null) ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.grey[300],
                      padding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
