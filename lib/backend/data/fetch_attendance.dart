import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

int loggedUsersCount = 0;
List<Map<String, dynamic>> users = [];
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

    users = fetchedUsers;

    // Fetch attendance data for each user
  } catch (e) {
    debugPrint('Error fetching users: $e');
  }
}

// Fetch logged users count for today
Future<void> fetchLoggedUsers() async {
  try {
    final today = DateTime.now();
    final monthYear = DateFormat('MMM_yyyy').format(today);
    final day = DateFormat('dd').format(today);

    final attendanceRef =
        firestore.collection('attendances').doc(monthYear).collection(day);

    final snapshot = await attendanceRef.get();

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

// Fetch attendance data for each user and calculate hours worked
Future<void> fetchAttendanceData() async {
  try {
    final today = DateTime.now();
    final monthYear = DateFormat('MMM_yyyy').format(today);
    final day = DateFormat('dd').format(today);

    for (var user in users) {
      final userId = user['rfid'];
      final attendanceRef = firestore
          .collection('attendances')
          .doc(monthYear)
          .collection(day)
          .doc(userId);

      final attendanceDoc = await attendanceRef.get();
      if (attendanceDoc.exists) {
        final data = attendanceDoc.data();
        final timeIn = (data?['timeIn'] as Timestamp?)?.toDate();
        final timeOut = (data?['timeOut'] as Timestamp?)?.toDate();

        if (timeIn != null && timeOut != null) {
          final workedDuration = timeOut.difference(timeIn);
          final workedHours = workedDuration.inHours +
              (workedDuration.inMinutes.remainder(60) / 60);

          workHours[userId] = workedHours;
        }
      }
    }
    await _fetchWeeklyAttendanceData();
    await _fetchMonthlyAttendanceData();
    await fetchYearlyAttendanceData();
  } catch (e) {
    debugPrint('Error fetching attendance data: $e');
  }
}

// Fetch attendance data for the week
Future<void> _fetchWeeklyAttendanceData() async {
  try {
    final today = DateTime.now();
    final weekStart = today.subtract(
        Duration(days: today.weekday - 1)); // Start of the week (Monday)

    for (var user in users) {
      final userId = user['rfid'];
      double totalWeeklyHours = 0;

      // Iterate over the last 7 days
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final monthYear = DateFormat('MMM_yyyy').format(day);
        final dayString = DateFormat('dd').format(day);

        final attendanceRef = firestore
            .collection('attendances')
            .doc(monthYear)
            .collection(dayString)
            .doc(userId);

        final attendanceDoc = await attendanceRef.get();
        if (attendanceDoc.exists) {
          final data = attendanceDoc.data();
          final timeIn = (data?['timeIn'] as Timestamp?)?.toDate();
          final timeOut = (data?['timeOut'] as Timestamp?)?.toDate();

          if (timeIn != null && timeOut != null) {
            final workedDuration = timeOut.difference(timeIn);
            final workedHours = workedDuration.inHours +
                (workedDuration.inMinutes.remainder(60) / 60);
            totalWeeklyHours += workedHours;
          }
        }
      }

      weeklyWorkHours[userId] = totalWeeklyHours;
    }
  } catch (e) {
    debugPrint('Error fetching weekly attendance data: $e');
  }
}

// Fetch attendance data for the month
Future<void> _fetchMonthlyAttendanceData() async {
  try {
    final today = DateTime.now();
    final monthYear =
        DateFormat('MMM_yyyy').format(today); // Get current month and year

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
    }
  } catch (e) {
    debugPrint('Error fetching monthly attendance data: $e');
  }
}

Future<void> fetchYearlyAttendanceData() async {
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

        // Reference the user's total hours document for the specific month
        final totalHoursRef = firestore
            .collection('attendances')
            .doc(monthYear) // Collection for the current month/year
            .collection('total_hours') // Separate collection for total hours
            .doc(userId); // Document for the specific user (RFID)

        final totalHoursDoc = await totalHoursRef.get();

        if (totalHoursDoc.exists) {
          final data = totalHoursDoc.data();
          final totalHours = data?['totalHours'] ?? 0.0;

          // Add the total monthly hours to the yearly total
          totalYearlyHours += totalHours;
        } else {
          debugPrint('No total hours data for user $userId in $monthYear');
        }
      }

      // Update yearlyWorkHours for the user

      yearlyWorkHours[userId] = totalYearlyHours;
    }
    isLoading = false;
    // Set loading state to false
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
