import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch.dart';
import 'package:nlrc_rfid_scanner/screens/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

List<Map<String, dynamic>> localUsers = []; // Use dynamic for flexibility
List<Map<String, dynamic>> users = [];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //await fetchUsers();
  await fetchDataAndGenerateDartFile();

  // Use the path where your file is stored
  users = await loadUsers();

  runApp(const MyApp());
}

// Define the readFileContent function to read a file as a string
Future<String> readFileContent(String path) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/users.json');

  // Check if the file exists
  if (await file.exists()) {
    return await file.readAsString();
  } else {
    throw Exception('File does not exist');
  }
}

// Define the function to load and parse users from the Dart file
Future<List<Map<String, dynamic>>> loadUsers() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/users.json');
  final fileContent = await readFileContent(file.toString());

  // You would typically have a JSON string here, so let's decode it
  List<dynamic> jsonData = jsonDecode(fileContent);

  // Convert the JSON data into a list of Maps
  return jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
}

/* Future<void> fetchUsers() async {
  // Simulating fetching users from Firebase Firestore
  final snapshot = await FirebaseFirestore.instance.collection('users').get();
  localUsers = snapshot.docs.map((doc) {
    return {
      'rfid': doc['rfid'],
      'name': doc['name'],
      'position': doc['position'],
    };
  }).toList();
} */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom]);

    return MaterialApp(
      title: 'NLRC Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'readexPro',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}
