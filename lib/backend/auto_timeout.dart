import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<void> updateNullTimeOut() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    //user_attendance collection for records with null timeOut
    final attendanceRef = firestore.collection('user_attendance');
    final querySnapshot =
        await attendanceRef.where('timeOut', isNull: true).get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final dateString = data['date'];
      // Parse the date field (string) into a DateTime object
      final dateParts = dateString.split('_');
      final recordDate = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
      );

      // Ensure that the timeOut is null and the recordDate is before today
      if (data['timeOut'] == null && recordDate.isBefore(today)) {
        // Set timeOut to 4:00 PM of the record date
        final newTimeOut = DateTime(
            recordDate.year, recordDate.month, recordDate.day, 16, 0, 0);

        final firebaseTimeOut = Timestamp.fromDate(newTimeOut);

        await doc.reference.update({'timeOut': firebaseTimeOut});
      }
    }
  } catch (e) {
    debugPrint('Error updating timeOut: $e');
  }
}
