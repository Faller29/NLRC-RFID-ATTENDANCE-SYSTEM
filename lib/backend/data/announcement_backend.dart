import 'package:cloud_firestore/cloud_firestore.dart';

void deleteExpiredAnnouncements() async {
  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month,
      now.day); // Reset time to midnight to compare only the date.

  try {
    final snapshot =
        await FirebaseFirestore.instance.collection('announcements').get();

    for (var doc in snapshot.docs) {
      var endDate = doc['endDate'].toDate();
      if (endDate.isBefore(todayMidnight)) {
        // Only delete announcements where the end date is strictly before today at midnight
        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(doc.id)
            .delete();
      }
    }
  } catch (e) {
    print('$e');
  }
}
