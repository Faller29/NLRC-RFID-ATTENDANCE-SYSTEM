import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

//updates null values on time out as auto time out as well as other usefull functions to migrate and reset time out
Future<void> updateNullTimeOut() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // user_attendances collection for records with null timeOut
    final attendanceRef = firestore.collection('user_attendances');
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

      // Ensure that timeOut is null and recordDate is before today
      if (data['timeOut'] == null && recordDate.isBefore(today)) {
        // Ensure timeIn exists
        if (data['timeIn'] != null) {
          // Parse timeIn to DateTime
          final Timestamp timeInTimestamp = data['timeIn'];
          final DateTime timeIn = timeInTimestamp.toDate();

          // Calculate the timeOut on the same date as timeIn
          final DateTime timeOut = DateTime(
            recordDate.year,
            recordDate.month,
            recordDate.day,
            timeIn.hour,
            timeIn.minute,
            timeIn.second,
          ).add(const Duration(hours: 9));

          final Timestamp firebaseTimeOut = Timestamp.fromDate(timeOut);

          // Update Firestore document with the calculated timeOut
          await doc.reference.update({'timeOut': firebaseTimeOut});
        } else {
          debugPrint('Record ${doc.id} is missing timeIn.');
        }
      }
    }
  } catch (e) {
    debugPrint('Error updating timeOut: $e');
  }
}

Future<void> resetAllTimeOuts() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    // Access the user_attendances collection
    final attendanceRef = firestore.collection('user_attendances');

    // Fetch all documents from the collection
    final querySnapshot = await attendanceRef.get();

    for (var doc in querySnapshot.docs) {
      // Update each document's timeOut field to null
      await doc.reference.update({'timeOut': null});
    }

    debugPrint('All timeOut fields have been reset to null.');
  } catch (e) {
    debugPrint('Error resetting timeOut fields: $e');
  }
}

Future<void> moveAttendanceData() async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // References to the collections
  CollectionReference oldCollection = firestore.collection('user_attendance');
  CollectionReference newCollection = firestore.collection('user_attendances');

  try {
    // Fetch all documents from the old collection
    QuerySnapshot snapshot = await oldCollection.get();

    // Iterate through each document
    for (QueryDocumentSnapshot doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Add the document to the new collection
      await newCollection.doc(doc.id).set(data);

      // Optionally delete the document from the old collection
      await oldCollection.doc(doc.id).delete();
    }

    print('Data migration completed successfully.');
  } catch (e) {
    print('Error during data migration: $e');
  }
}
