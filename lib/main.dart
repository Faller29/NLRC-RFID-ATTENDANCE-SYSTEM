import 'dart:convert';
import 'dart:io';
import 'package:nlrc_rfid_scanner/backend/data/file_reader.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_users.dart';
import 'package:nlrc_rfid_scanner/screens/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

List<Map<String, dynamic>> localUsers = []; // Use dynamic for flexibility
List<Map<String, dynamic>> users = [];
List<Map<String, dynamic>> attendance = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //await fetchUsers();
  await fetchDataAndGenerateDartFile();
  await fetchAttendance();
  // Use the path where your file is stored
  users = await loadUsers();
  attendance = await loadAttendance();
  print(attendance);
  runApp(const MyApp());
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
