import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:pdf/pdf.dart'; // For PDF generation
import 'package:pdf/widgets.dart' as pw; // PDF Widgets
import 'package:printing/printing.dart'; // For printing PDFs
import 'package:flutter/services.dart'; // For loading images
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class ReportPage extends StatefulWidget {
  @override
  _ReportPage createState() => _ReportPage();
}

class _ReportPage extends State<ReportPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  DateTimeRange? selectedDateRange;

  void adjustDate(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
  }

  // Add controllers for timeIn and timeOut
  final TextEditingController _timeInController = TextEditingController();
  final TextEditingController _timeOutController = TextEditingController();
  String? _userIdToEdit;
  @override
  void dispose() {
    _timeInController.dispose();
    _timeOutController.dispose();
    super.dispose();
  }

  void _showEditAttendanceModal(
      String? userId, String yearMonth, String day, Map<String, dynamic> user) {
    _userIdToEdit = userId;

    // Handle both String and Timestamp cases
    _timeInController.text = _parseTime(user['timeIn']);
    _timeOutController.text = _parseTime(user['timeOut']);

    showDialog(
      context: context,
      builder: (context) {
        return _buildAttendanceFormDialog(
            () => _updateAttendance(yearMonth, day));
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

  void _updateAttendance(String yearMonth, String day) async {
    final timeInText = _timeInController.text.trim();
    final timeOutText = _timeOutController.text.trim();

    try {
      // Parse the input times
      final timeIn = DateFormat('hh:mm a').parse(timeInText);
      final timeOut = DateFormat('hh:mm a').parse(timeOutText);

      if (timeIn == null || timeOut == null) {
        throw FormatException("Invalid time format");
      }

      // Get the original date (assume it's stored as part of the document structure)
      final attendanceDoc = await firestore
          .collection('attendances')
          .doc(yearMonth)
          .collection(day)
          .doc(_userIdToEdit)
          .get();

      if (!attendanceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackBarFailed('Attendance record not found.', context),
        );
        return;
      }

      // Extract the date from the existing `timeIn` field
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

      // Update Firestore document
      await firestore
          .collection('attendances')
          .doc(yearMonth)
          .collection(day)
          .doc(_userIdToEdit)
          .update({
        'timeIn': Timestamp.fromDate(updatedTimeIn),
        'timeOut': Timestamp.fromDate(updatedTimeOut),
      });

      // Trigger a UI update
      setState(() {
        // Update local variables or state if necessary
        // For example, if you are storing attendance locally:
      });

      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        snackBarSuccess('Time Updated Successfully!', context),
      );
    } catch (e) {
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
              title: const Text('Select Date Range'),
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
      Map<String, Map<String, dynamic>> combinedData = {};

      DateTime currentDate = selectedDateRange!.start;
      while (currentDate.isBefore(selectedDateRange!.end) ||
          currentDate.isAtSameMomentAs(selectedDateRange!.end)) {
        String yearMonth =
            DateFormat('MMM_yyyy').format(currentDate); // e.g., Dec_2024
        String day = DateFormat('dd').format(currentDate); // e.g., 12

        CollectionReference dayCollection =
            firestore.collection('attendances').doc(yearMonth).collection(day);

        QuerySnapshot snapshot = await dayCollection.get();

        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String id = doc.id;
          String name = data['name'] ?? '';

          if (!combinedData.containsKey(id)) {
            combinedData[id] = {
              'name': name,
              'totalHours': 0,
            };
          }

          DateTime? timeIn =
              data['timeIn'] != null ? data['timeIn'].toDate() : null;
          DateTime? timeOut =
              data['timeOut'] != null ? data['timeOut'].toDate() : null;
          combinedData[id]!['totalHours'] +=
              _calculateTotalMinutes(timeIn, timeOut);
        }

        currentDate = currentDate.add(Duration(days: 1));
      }

      return combinedData.entries.map((entry) {
        int totalMinutes = entry.value['totalHours'] as int;
        int hours = totalMinutes ~/ 60;
        int minutes = totalMinutes % 60;

        // Determine the correct singular or plural form for hours and minutes
        String hourText = hours == 1 ? 'hour' : 'hours';
        String minuteText = minutes == 1 ? 'minute' : 'minutes';

        return {
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
      String yearMonth =
          DateFormat('MMM_yyyy').format(selectedDate); // e.g., Jan_2025
      String day = DateFormat('dd').format(selectedDate); // e.g., 01

      // Reference to the specific day collection
      CollectionReference dayCollection =
          firestore.collection('attendances').doc(yearMonth).collection(day);

      // Fetch all user documents for the selected day
      QuerySnapshot userSnapshots = await dayCollection.get();

      // Process each user document (_userIdToEdit)
      List<Map<String, String>> attendanceData = [];

      for (var userDoc in userSnapshots.docs) {
        String userId = userDoc.id; // e.g., "12345"
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

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

        attendanceData.add({
          'id': userId, // Include the user ID
          'yearMonth': yearMonth, // Include the yearMonth
          'day': day, // Include the day
          'name': (userData['name'] ?? '').toString(),
          'timeIn': timeIn != null ? DateFormat('hh:mm a').format(timeIn) : '',
          'timeOut':
              timeOut != null ? DateFormat('hh:mm a').format(timeOut) : '',
          'totalHours':
              '${hours > 0 ? '$hours $hourText ' : ''}${minutes > 0 ? '$minutes $minuteText' : ''}'
                  .trim(),
        });
      }

      return attendanceData;
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      return [];
    }
  }

  String _calculateTotalHours(DateTime? timeIn, DateTime? timeOut) {
    if (timeIn == null || timeOut == null) return '';
    try {
      Duration diff = timeOut.difference(timeIn);
      int hours = diff.inHours;
      int minutes = diff.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } catch (e) {
      debugPrint('Error calculating total hours: $e');
      return '';
    }
  }

  Future<void> generateAndPrintPDF() async {
    final pdf = pw.Document();
    final ByteData imageData =
        await rootBundle.load('lib/assets/images/NLRC-WHITE.png');
    final Uint8List imageBytes = imageData.buffer.asUint8List();

    final logo = pw.MemoryImage(imageBytes);
    final String currentDate = DateFormat('MMMM d, y').format(selectedDate);

    final attendanceData = await fetchAttendanceData();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(
                    logo,
                    width: 75,
                    height: 75,
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'National Labor Relations Commission',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        currentDate,
                        style: const pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 50),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'PERFORMANCE ANALYSIS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Name', 'Time In', 'Time Out', 'Total Hours'],
                data: attendanceData.map((employee) {
                  return [
                    employee['name'] ?? '',
                    employee['timeIn'] ?? '',
                    employee['timeOut'] ?? '',
                    employee['totalHours'] ?? '',
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColors.blue, width: 1),
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 10,
                ),
                cellPadding: const pw.EdgeInsets.all(8),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
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
                            'REPORT ANALYSIS',
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
                          child: const Text(
                            'SELECT RANGE',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 5.0),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Color.fromRGBO(69, 90, 100, 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              selectedDateRange = null; // Reset the range
                            });
                          },
                          child: const Text(
                            'RESET TO DEFAULT VIEW',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
                        onPressed: generateAndPrintPDF,
                        child: const Text(
                          'GENERATE',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                        'Selected Range: ${DateFormat.yMMMd().format(selectedDateRange!.start)} - ${DateFormat.yMMMd().format(selectedDateRange!.end)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    if (attendanceData1.isEmpty)
                      Expanded(
                        child: Center(
                          child: const Text(
                            'No records found for this date range',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Table(
                          border: TableBorder.all(color: Colors.grey, width: 1),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(3),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Colors.blueGrey,
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
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
                        child: Center(
                          child: const Text(
                            'No records found for this date',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Table(
                          border: TableBorder.all(color: Colors.grey, width: 1),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
                            4: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Colors.blueGrey,
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
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
                                Padding(
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
                                Padding(
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
                                Padding(
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
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blueAccent),
                                      onPressed: () => _showEditAttendanceModal(
                                        employee['id'] ?? '',
                                        employee['yearMonth'] ?? '',
                                        employee['day'] ?? '',
                                        employee,
                                      ),
                                      tooltip: 'Edit Time In & Time Out',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
