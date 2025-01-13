import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// Define your User class with the correct fields
class User {
  final String imagePath;
  final String rfid;
  final String name;
  final String position;
  final String office;

  User({
    required this.imagePath,
    required this.rfid,
    required this.name,
    required this.position,
    required this.office,
  });

  // Factory method to create a User from a map (like the one retrieved from Firestore)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      imagePath: map['imagePath'] ?? '',
      rfid: map['rfid'] ?? '',
      name: map['name'] ?? '',
      position: map['position'] ?? '',
      office: map['office'] ?? '',
    );
  }

  // Convert User object to map (useful if you need to save or send data)
  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'rfid': rfid,
      'name': name,
      'position': position,
      'office': office,
    };
  }

  // Convert User to JSON
  String toJson() => json.encode(toMap());
}

// Function to fetch data from Firebase and save it in a Dart file
Future<void> fetchDataAndGenerateDartFile() async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  try {
    // Fetch user data from Firebase Firestore
    QuerySnapshot snapshot = await _firestore.collection('users').get();
    final List<User> userList = snapshot.docs.map((doc) {
      return User.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
// This file was generated automatically. Do not modify.
/* import 'package:nlrc_rfid_scanner/backend/data/fetch.dart';

List<Map<String, dynamic>> users =  */
    // Create a Dart file content from the fetched data
    String dartFileContent = '''

${jsonEncode(userList.map((e) => e.toMap()).toList())}
''';

    // Specify the file path where the Dart file will be stored
    final directory = await getApplicationCacheDirectory();
    final file = File('${directory.path}/users.json');

    // Write the Dart file content to the file
    await file.writeAsString(dartFileContent);

    print('Dart file generated successfully at: ${file.path}');
  } catch (e) {
    print('Error fetching data from Firebase: $e');
  }
}

// Define your User class with the correct fields
class Attendance {
  final name;
  final officeType;
  final timeIn;
  final timeOut;

  Attendance({
    required this.name,
    required this.officeType,
    required this.timeIn,
    required this.timeOut,
  });

  // Factory method to create a User from a map (like the one retrieved from Firestore)
  factory Attendance.fromMap(Map<String, dynamic> map) {
    // Convert Timestamp to DateTime and format it as "hh:mm:ss"
    String formatTime(Timestamp timestamp) {
      DateTime dateTime = timestamp.toDate();
      return DateFormat('hh:mm a')
          .format(dateTime); // Format as HH:mm:ss (24-hour format)
    }

    return Attendance(
      name: map['name']?.toString() ?? '',
      officeType: map['officeType']?.toString() ?? '',
      timeIn: map['timeIn'] != null ? formatTime(map['timeIn']) : '',
      timeOut: map['timeOut'] != null ? formatTime(map['timeOut']) : '',
    );
  }

  // Convert User object to map (useful if you need to save or send data)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'officeType': officeType,
      'timeIn': timeIn,
      'timeOut': timeOut,
    };
  }

  // Convert User to JSON
  String toJson() => json.encode(toMap());
}

// Function to fetch data from Firebase and save it in a Dart file
Future<void> fetchAttendance() async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //DateTime now = DateTime.now();
  //String formattedDate = DateFormat('MMM_yyyy').format(now);
  final todayDate = DateFormat('MM_dd_yyyy').format(DateTime.now());

  try {
    // Fetch user attendance data for today from the user_attendance collection
    QuerySnapshot snapshot = await _firestore
        .collection('user_attendance')
        .where('date', isEqualTo: todayDate) // Filter by today's date
        .get();

    final List<Attendance> attendanceList = snapshot.docs.map((doc) {
      return Attendance.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();

    // Create a Dart file content from the fetched data
    String dartFileContent = '''
${jsonEncode(attendanceList.map((e) => e.toMap()).toList())}
''';

    // Specify the file path where the Dart file will be stored
    final directory = await getApplicationCacheDirectory();
    final file = File('${directory.path}/attendance.json');

    // Write the Dart file content to the file
    await file.writeAsString(dartFileContent);

    print('Dart file generated successfully at: ${file.path}');
  } catch (e) {
    print('Error fetching data from Firebase: $e');
  }
}

Future<void> fetchAdminLogin() async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  try {
    // Fetch admin data from Firestore
    DocumentSnapshot snapshot =
        await _firestore.collection('admin').doc('account').get();

    if (snapshot.exists) {
      Map<String, dynamic> adminData = snapshot.data() as Map<String, dynamic>;

      // Create a JSON string from the admin data
      String jsonContent = jsonEncode(adminData);

      // Specify the file path for local storage
      final directory = await getApplicationCacheDirectory();
      final file = File('${directory.path}/admin_account.json');

      // Write the JSON content to the file
      await file.writeAsString(jsonContent);

      print('Admin data saved locally at: ${file.path}');
    } else {
      print('Admin document does not exist in Firestore.');
    }
  } catch (e) {
    print('Error fetching admin data from Firebase: $e');
  }
}

// Define your Announcement class with the correct fields
class Announcement {
  final String title;
  final String announcement;
  final String startDate;
  final String endDate;

  Announcement({
    required this.title,
    required this.announcement,
    required this.startDate,
    required this.endDate,
  });

  // Factory method to create an Announcement from a map (like the one retrieved from Firestore)
  factory Announcement.fromMap(Map<String, dynamic> map) {
    // Function to format Timestamp into desired string format
    String formatTime(Timestamp timestamp) {
      DateTime dateTime = timestamp.toDate();
      return DateFormat('MMM dd yyyy hh:mm a')
          .format(dateTime); // Format as "MMM dd yyyy hh:mm a"
    }

    return Announcement(
      title: map['title']?.toString() ?? '',
      announcement: map['announcement']?.toString() ?? '',
      startDate: formatTime(map['startDate']) ?? '',
      endDate: formatTime(map['endDate']) ?? '',
    );
  }

  // Convert Announcement object to map (useful if you need to save or send data)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'announcement': announcement,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  // Convert Announcement to JSON
  String toJson() => json.encode(toMap());
}

// Function to fetch data from Firebase and save it in a Dart file
Future<void> fetchAnnouncements() async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  try {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    // Fetch announcements data from Firebase Firestore
    QuerySnapshot snapshot = await _firestore
        .collection('announcements')
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    // Map the fetched data to a list of announcement maps
    final List<Announcement> announcementList = snapshot.docs.map((doc) {
      return Announcement.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();

    // Create a JSON file content from the fetched data
    String jsonFileContent = '''

${jsonEncode(announcementList.map((e) => e.toMap()).toList())}
''';
    // Specify the file path where the JSON file will be stored
    final directory = await getApplicationCacheDirectory();
    final file = File('${directory.path}/announcements.json');

    // Write the JSON file content to the file
    await file.writeAsString(jsonFileContent);

    print('Announcements saved successfully at: ${file.path}');
  } catch (e) {
    print('Error fetching announcements from Firebase: $e');
  }
}
