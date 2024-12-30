import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

// Define your User class with the correct fields
class User {
  final String rfid;
  final String name;
  final String position;
  final String office;

  User({
    required this.rfid,
    required this.name,
    required this.position,
    required this.office,
  });

  // Factory method to create a User from a map (like the one retrieved from Firestore)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      rfid: map['rfid'] ?? '',
      name: map['name'] ?? '',
      position: map['position'] ?? '',
      office: map['office'] ?? '',
    );
  }

  // Convert User object to map (useful if you need to save or send data)
  Map<String, dynamic> toMap() {
    return {
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
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/users.json');

    // Write the Dart file content to the file
    await file.writeAsString(dartFileContent);

    print('Dart file generated successfully at: ${file.path}');
  } catch (e) {
    print('Error fetching data from Firebase: $e');
  }
}
