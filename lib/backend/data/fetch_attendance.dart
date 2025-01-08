import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

int loggedUsersCount = 0;
List<Map<String, dynamic>> numberOfUsers = [];
Map<String, double> workHours = {};
Map<String, double> weeklyWorkHours = {}; // For weekly aggregation
Map<String, double> monthlyWorkHours = {}; // For monthly aggregation
Map<String, double> yearlyWorkHours = {};
final FirebaseFirestore firestore = FirebaseFirestore.instance;
bool isLoading = true;

// Fetch user data from Firebase
Future<void> fetchUsers() async {
  try {
    final usersRef = firestore.collection('users');
    final snapshot = await usersRef.get();
    final fetchedUsers = snapshot.docs.map((doc) {
      return {
        'rfid': doc['rfid'],
        'name': doc['name'],
        'office': doc['office'],
        'position': doc['position'],
      };
    }).toList();

    numberOfUsers = fetchedUsers;

    // Fetch attendance data for each user
  } catch (e) {
    debugPrint('Error fetching users: $e');
  }
}

Future<void> fetchLoggedUsers() async {
  try {
    final today = DateTime.now();
    final todayDate =
        DateFormat('MM_dd_yyyy').format(today); // Format: 12_08_2024

    // Reference to the new user_attendance collection
    final attendanceRef = firestore.collection('user_attendance');

    // Fetch attendance records for today's date
    final snapshot =
        await attendanceRef.where('date', isEqualTo: todayDate).get();

    // Count how many users have logged in today (those who have a timeIn)
    int count = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timeIn = (data['timeIn'] as Timestamp?)?.toDate();
      if (timeIn != null) {
        count++;
      }
    }

    loggedUsersCount = count;
  } catch (e) {
    debugPrint('Error fetching logged users: $e');
  }
}

Future<void> fetchAttendanceData() async {
  try {
    final today = DateTime.now();
    final todayDate = DateFormat('MM_dd_yyyy').format(today);

    // Initialize worked hours map
    workHours.clear();

    for (var user in numberOfUsers) {
      final userId = user['rfid'];
      double workedHours = 0;

      // Query the user_attendance collection for today's date
      final attendanceRef = firestore
          .collection('user_attendance')
          .where('rfid',
              isEqualTo:
                  userId) // Ensure only the current user's attendance is fetched
          .where('date', isEqualTo: todayDate);

      final attendanceDoc = await attendanceRef.get();

      // If documents are found, calculate worked hours
      if (attendanceDoc.docs.isNotEmpty) {
        for (var doc in attendanceDoc.docs) {
          final data = doc.data();
          final timeIn = (data['timeIn'] as Timestamp?)?.toDate();
          DateTime? timeOut = (data['timeOut'] as Timestamp?)?.toDate();

          // Substitute timeOut with DateTime.now() if it is null
          if (timeIn != null) {
            timeOut ??= DateTime.now();
            final workedDuration = timeOut.difference(timeIn);
            workedHours += workedDuration.inHours +
                (workedDuration.inMinutes.remainder(60) / 60);
          }
        }
      }

      // If no attendance record is found, workedHours remains 0
      workHours[userId] = workedHours;
    }

    // Fetch additional data for weekly, monthly, and yearly attendance
    await _fetchWeeklyAttendanceData();
    await _fetchMonthlyAttendanceData();
    await fetchYearlyAttendanceData();
  } catch (e) {
    debugPrint('Error fetching attendance data: $e');
  }
}

Future<void> _fetchWeeklyAttendanceData() async {
  try {
    final today = DateTime.now();
    final weekStart = today.subtract(
        Duration(days: today.weekday - 1)); // Start of the week (Monday)
    final weekEnd =
        weekStart.add(Duration(days: 6)); // End of the week (Sunday)

    // Format the start and end dates to match the 'MM_dd_yyyy' format in Firestore
    final weekStartDate = DateFormat('MM_dd_yyyy').format(weekStart);
    final weekEndDate = DateFormat('MM_dd_yyyy').format(weekEnd);

    // Reference to the user_attendance collection
    for (var user in numberOfUsers) {
      final rfid = user['rfid'];
      double totalWeeklyHours = 0;

      // Query attendance records for the user across the entire year by date range
      final yearlyAttendanceRef = firestore
          .collection('user_attendance')
          .where('rfid', isEqualTo: rfid) // Filter by rfid
          .where('date',
              isGreaterThanOrEqualTo: weekStartDate) // Start of the year
          .where('date', isLessThanOrEqualTo: weekEndDate) // End of the year
          .get();

      final querySnapshot = await yearlyAttendanceRef;

      // Loop through the entire year’s attendance and calculate total worked hours
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timeIn = (data['timeIn'] as Timestamp?)?.toDate();
        final timeOut = (data['timeOut'] as Timestamp?)?.toDate();

        // Calculate worked hours if both timeIn and timeOut exist
        if (timeIn != null && timeOut != null) {
          final workedDuration = timeOut.difference(timeIn);
          final workedHours = workedDuration.inHours +
              (workedDuration.inMinutes.remainder(60) / 60);
          totalWeeklyHours += workedHours;
        }
      }

      // Store the total yearly hours for the user
      weeklyWorkHours[rfid] = totalWeeklyHours;
    }
  } catch (e) {
    debugPrint('Error fetching weekly attendance data: $e');
  }
}

// Fetch attendance data for the month
Future<void> _fetchMonthlyAttendanceData() async {
  try {
    /* final today = DateTime.now();
    final monthYear =
        DateFormat('MM_dd_yyyy').format(today); // Get current month and year

    for (var user in users) {
      final userId = user['rfid'];
      double totalMonthlyHours = 0;

      final totalHoursRef = firestore
          .collection('attendances')
          .doc(monthYear)
          .collection('total_hours')
          .doc(userId);

      final totalHoursDoc = await totalHoursRef.get();

      if (totalHoursDoc.exists) {
        final data = totalHoursDoc.data();
        totalMonthlyHours = data?['totalHours'] ?? 0.0;
      }

      monthlyWorkHours[userId] = totalMonthlyHours;
    } */

    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    for (var user in numberOfUsers) {
      final rfid = user['rfid'];
      double totalMonthlyHours = 0;

      // Query attendance records for the user across the entire year by date range
      final yearlyAttendanceRef = firestore
          .collection('user_attendance')
          .where('rfid', isEqualTo: rfid) // Filter by rfid
          .where('date',
              isGreaterThanOrEqualTo: DateFormat('MM_dd_yyyy').format(
                  DateTime(currentYear, currentMonth, 1))) // Start of the year
          .where('date',
              isLessThanOrEqualTo: DateFormat('MM_dd_yyyy').format(
                  DateTime(currentYear, currentMonth, 31))) // End of the year
          .get();

      final querySnapshot = await yearlyAttendanceRef;

      // Loop through the entire year’s attendance and calculate total worked hours
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timeIn = (data['timeIn'] as Timestamp?)?.toDate();
        final timeOut = (data['timeOut'] as Timestamp?)?.toDate();

        // Calculate worked hours if both timeIn and timeOut exist
        if (timeIn != null && timeOut != null) {
          final workedDuration = timeOut.difference(timeIn);
          final workedHours = workedDuration.inHours +
              (workedDuration.inMinutes.remainder(60) / 60);
          totalMonthlyHours += workedHours;
        }
      }

      // Store the total yearly hours for the user
      monthlyWorkHours[rfid] = totalMonthlyHours;
    }
  } catch (e) {
    debugPrint('Error fetching monthly attendance data: $e');
  }
}

Future<void> fetchYearlyAttendanceData() async {
  try {
    final currentYear =
        DateTime.now().year; // Dynamically determine the current year

    for (var user in numberOfUsers) {
      final rfid = user['rfid'];
      double totalYearlyHours = 0;

      // Query attendance records for the user across the entire year by date range
      final yearlyAttendanceRef = firestore
          .collection('user_attendance')
          .where('rfid', isEqualTo: rfid) // Filter by rfid
          .where('date',
              isGreaterThanOrEqualTo: DateFormat('MM_dd_yyyy')
                  .format(DateTime(currentYear, 1, 1))) // Start of the year
          .where('date',
              isLessThanOrEqualTo: DateFormat('MM_dd_yyyy')
                  .format(DateTime(currentYear, 12, 31))) // End of the year
          .get();

      final querySnapshot = await yearlyAttendanceRef;

      // Loop through the entire year’s attendance and calculate total worked hours
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timeIn = (data['timeIn'] as Timestamp?)?.toDate();
        final timeOut = (data['timeOut'] as Timestamp?)?.toDate();

        // Calculate worked hours if both timeIn and timeOut exist
        if (timeIn != null && timeOut != null) {
          final workedDuration = timeOut.difference(timeIn);
          final workedHours = workedDuration.inHours +
              (workedDuration.inMinutes.remainder(60) / 60);
          totalYearlyHours += workedHours;
        }
      }

      // Store the total yearly hours for the user
      yearlyWorkHours[rfid] = totalYearlyHours;
    }

    isLoading = false; // Set loading state to false
  } catch (e) {
    debugPrint('Error fetching yearly attendance data: $e');
  }
}



/*  Future<void> _fetchAttendance() async {
    await fetchAttendanceData();
  } */

/* Future<void> fetchYearlyAttendanceData() async {
    try {
      final currentYear =
          DateTime.now().year; // Dynamically determine the current year

      for (var user in users) {
        final userId = user['rfid'];
        double totalYearlyHours = 0;

        // Iterate over each month of the current year
        for (int month = 1; month <= 12; month++) {
          final monthDate = DateTime(currentYear, month, 1);
          final monthYear =
              DateFormat('MMM_yyyy').format(monthDate); // Example: Dec_2024
          // Determine the total number of days in the month
          final totalDaysInMonth = DateTime(currentYear, month + 1, 0).day;

          for (int day = 1; day <= totalDaysInMonth; day++) {
            final everyday = monthDate.add(Duration(days: day));

            // Reference the specific day within the month's collection
            final days = DateFormat('dd').format(everyday);
            final dayRef = firestore
                .collection('attendances')
                .doc(monthYear)
                .collection(days)
                .doc(userId);

            final attendanceDoc = await dayRef.get();
            if (attendanceDoc.exists) {
              final data = attendanceDoc.data();
              final timeIn = (data?['timeIn'] as Timestamp?)?.toDate();
              final timeOut = (data?['timeOut'] as Timestamp?)?.toDate();

              if (timeIn != null && timeOut != null) {
                final workedDuration = timeOut.difference(timeIn);
                final workedHours = workedDuration.inHours +
                    (workedDuration.inMinutes.remainder(60) / 60);
                totalYearlyHours += workedHours;
              }
            }
          }
        }
        //print(yearlyWorkHours[userId]);
        setState(() {
          yearlyWorkHours[userId] = totalYearlyHours;
        });
      }

      // Set loading state to false
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching yearly attendance data: $e');
    }
  } */