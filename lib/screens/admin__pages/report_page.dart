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
import 'package:cloud_firestore/cloud_firestore.dart';
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
  DateTime selectedMonth = DateTime.now();

  DateTimeRange? selectedDateRange;
  bool isEditMode = false; // Add this state variable

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

    try {
      // Parse the input times
      final timeIn = DateFormat('hh:mm a').parse(timeInText);
      final timeOut = DateFormat('hh:mm a').parse(timeOutText);

      if (timeIn == null || timeOut == null) {
        throw FormatException("Invalid time format");
      }

      // Fetch the attendance document by `rfid` and `date`
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('user_attendance')
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

      final updatedTimeOut = DateTime(
        existingTimeIn.year,
        existingTimeIn.month,
        existingTimeIn.day,
        timeOut.hour,
        timeOut.minute,
      );

      // Validate that Time In is before Time Out
      if (updatedTimeIn.isAfter(updatedTimeOut)) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed('Time In must be before Time Out.', context),
        );
        return;
      }

      // Update the Firestore document
      await FirebaseFirestore.instance
          .collection('user_attendance')
          .doc(attendanceDoc.id) // Use the document ID from the query
          .update({
        'timeIn': Timestamp.fromDate(updatedTimeIn),
        'timeOut': Timestamp.fromDate(updatedTimeOut),
      });

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
              title: Center(child: const Text('Select Date Range')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Start Date:'),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Color.fromRGBO(69, 90, 100, 1), // Background color
                      foregroundColor: Colors.white, // Foreground (text) color
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
                  const SizedBox(height: 16),
                  const Text('End Date:'),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Color.fromRGBO(69, 90, 100, 1), // Background color
                      foregroundColor: Colors.white, // Foreground (text) color
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
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.close),
                      label: Text('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                    TextButton(
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save), // Icon added here
                          SizedBox(
                              width: 8), // Spacing between the icon and text
                          Text('Save'),
                        ],
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

        // Reference to the `user_attendance` collection
        CollectionReference userAttendanceCollection =
            FirebaseFirestore.instance.collection('user_attendance');

        // Fetch all documents in the `user_attendance` collection
        QuerySnapshot snapshot = await userAttendanceCollection.get();

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

  Future<List<Map<String, String>>> fetchAttendanceData() async {
    try {
      // Format the selectedDate to match the custom format "MM_dd_yyyy"
      String selectedDateFormatted =
          DateFormat('MM_dd_yyyy').format(selectedDate);

      // Reference to the `user_attendance` collection
      CollectionReference userAttendanceCollection =
          FirebaseFirestore.instance.collection('user_attendance');

      // Fetch all documents in the `user_attendance` collection
      QuerySnapshot userSnapshots = await userAttendanceCollection.get();

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
    List<Map<String, String>> attendanceData = [];
    try {
      String yearMonth = DateFormat('MMM_yyyy').format(selectedMonth);
      final yearMonthRef =
          FirebaseFirestore.instance.collection('attendances').doc(yearMonth);

      List<String> days =
          List.generate(31, (index) => (index + 1).toString().padLeft(2, '0'));

      for (String day in days) {
        final userDocRef = yearMonthRef.collection(day);
        final userSnapshots =
            await userDocRef.where('rfid', isEqualTo: _selectedRfid).get();

        if (userSnapshots.docs.isEmpty) {
          continue;
        }

        for (var userDoc in userSnapshots.docs) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          DateTime? timeIn =
              userData['timeIn'] != null ? userData['timeIn'].toDate() : null;
          DateTime? timeOut =
              userData['timeOut'] != null ? userData['timeOut'].toDate() : null;

          int totalMinutes = _calculateTotalMinutes(timeIn, timeOut);
          int hours = totalMinutes ~/ 60;
          int minutes = totalMinutes % 60;

          String hourText = hours == 1 ? 'hour' : 'hours';
          String minuteText = minutes == 1 ? 'minute' : 'minutes';

          attendanceData.add({
            'monthYear':
                timeIn != null ? DateFormat('MMM dd').format(timeIn) : '',
            'rfid': userData['rfid'] ?? '',
            'timeIn':
                timeIn != null ? DateFormat('hh:mm a').format(timeIn) : '',
            'timeOut':
                timeOut != null ? DateFormat('hh:mm a').format(timeOut) : '',
            'totalHours':
                '${hours > 0 ? '$hours $hourText ' : ''}${minutes > 0 ? '$minutes $minuteText' : ''}'
                    .trim(),
          });
        }
      }

      return attendanceData;
    } catch (e) {
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
      final pdf = pw.Document();
      final ByteData imageData =
          await rootBundle.load('lib/assets/images/NLRC.jpg');
      final Uint8List imageBytes = imageData.buffer.asUint8List();

      final logo = pw.MemoryImage(imageBytes);
      final attendanceData = await fetchAttendanceData2();

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

      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(logo, width: 75, height: 75),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Republic of the Philippines',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('Department of Labor and Employment',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('National Labor Relations Commission',
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Attendance Report',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black)),
                      ],
                    ),
                    pw.SizedBox(width: 50),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('$employeeName',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.Text(DateFormat.yMMM().format(selectedMonth),
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.black)),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: ['Date', 'Time In', 'Time Out', 'Total Hours'],
                  data: [
                    ...attendanceData.map((employee) {
                      return [
                        employee['monthYear'] ?? '',
                        employee['timeIn'] ?? '',
                        employee['timeOut'] ?? '',
                        employee['totalHours'] ?? '',
                      ];
                    }).toList(),
                    // Add a row for overall total hours
                    [
                      '',
                      '',
                      '',
                      pw.Text(
                        'Overall Total: $overallHours hours $overallMinutes minutes',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  cellAlignment: pw.Alignment.center,
                  headerStyle: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.white),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellPadding: const pw.EdgeInsets.all(8),
                ),
              ],
            );
          },
        ),
      );

      // Convert the PDF document to bytes
      Uint8List pdfBytes = await pdf.save();
      final userProfile =
          Platform.environment['USERPROFILE']; // Get the user's home directory
      final directoryPath = '$userProfile\\Documents\\NLRC';

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

      // Use FilePicker to prompt the user with a "Save As" dialog
      String? outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF File',
        fileName:
            '$_selectedName - ${DateFormat.yMMM().format(selectedMonth)}.pdf',
        initialDirectory: directoryPath,
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      // If the user cancels the save dialog, exit
      if (outputFilePath == null) {
        return;
      }
      // Ensure the file name ends with `.pdf`
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
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarFailed('Failed to generate PDF', context),
      );
    } finally {
      // Close the loading dialog if still open
      if (isLoadingDialogOpen) {
        Navigator.pop(context);
      }
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
          } else if (snapshot.hasError) {
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
                                  'SELECT RANGE',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(width: 10),
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
                              return _buildPdfGenerationDialog('GENERATE PDF');
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
                              'GENERATE',
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
                      child: Text(
                        'Selected Date Range: ${DateFormat.yMMMd().format(selectedDateRange!.start)} - ${DateFormat.yMMMd().format(selectedDateRange!.end)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
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
                                              alignment: Alignment.centerLeft,
                                              child: IconButton(
                                                iconSize: 22,
                                                padding:
                                                    const EdgeInsets.all(1.0),
                                                icon: const Icon(
                                                    Icons.arrow_back),
                                                onPressed: () {
                                                  setState(() {
                                                    selectedDateRange = null;
                                                    selectedDate =
                                                        DateTime.now();
                                                  });
                                                },
                                                color: Colors.white,
                                              ),
                                            ),
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
                                            alignment: Alignment.centerLeft,
                                            child: IconButton(
                                              iconSize: 22,
                                              padding:
                                                  const EdgeInsets.all(1.0),
                                              icon:
                                                  const Icon(Icons.arrow_back),
                                              onPressed: () {
                                                setState(() {
                                                  selectedDateRange = null;
                                                  selectedDate = DateTime.now();
                                                });
                                              },
                                              color: Colors.white,
                                            ),
                                          ),
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
                                          tooltip: 'Edit Time In & Time Out',
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
                onPressed: () {
                  setState(() {
                    isEditMode = !isEditMode; // Toggle edit mode
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    snackBarSuccess(
                      isEditMode ? 'Edit Mode Enabled' : 'Edit Mode Disabled',
                      context,
                    ),
                  );
                },
                backgroundColor: Colors.transparent,
                tooltip: 'Turn On/Off Edit Mode',
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
          : null, // Hide the button if selectedDateRange is not null
    );
  }

  Widget _buildPdfGenerationDialog(String title) {
    DateTime? selectedMonth;
    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 475),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Center(
                  child: _names.isEmpty
                      ? CircularProgressIndicator()
                      : Container(
                          width: 400,
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
                            initialDate: selectedMonth ?? today,
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
                          'Choose Month & Year',
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
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          selectedMonth != null
                              ? 'Selected Month & Year: ${selectedMonth != null ? DateFormat.yMMM().format(selectedMonth!) : "--"}'
                              : 'Selected Month & Year: --',
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
                SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(
                          Icons.close,
                        ),
                        label: Text('Close'),
                        onPressed: () {
                          setState(() {
                            _selectedName = null; // Reset selected name
                            _selectedRfid = null; // Reset selected RFID
                            selectedMonth = null; // Reset selected month
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                      Tooltip(
                        message: _selectedName != null && selectedMonth != null
                            ? 'Generate PDF'
                            : 'Please Select a User and Date',
                        child: TextButton(
                          onPressed:
                              (_selectedName != null && selectedMonth != null)
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.save),
                              SizedBox(width: 8),
                              Text('Save'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
