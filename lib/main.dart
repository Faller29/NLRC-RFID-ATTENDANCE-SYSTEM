import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nlrc_rfid_scanner/backend/data/file_reader.dart';
import 'package:window_manager/window_manager.dart';
import 'firebase_options.dart';

import 'package:nlrc_rfid_scanner/backend/auto_timeout.dart';
import 'package:nlrc_rfid_scanner/backend/data/announcement_backend.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_attendance.dart';
import 'package:nlrc_rfid_scanner/backend/data/fetch_data.dart';
import 'package:nlrc_rfid_scanner/screens/homepage.dart';

List<Map<String, dynamic>> users = [];
List<Map<String, dynamic>> attendance = [];
Map<String, dynamic>? adminData = {};
List<Map<String, dynamic>> adminAnnouncement = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAspectRatio(16 / 9);
    await windowManager.setAlignment(Alignment.center);
    await windowManager.setMinimumSize(Size(1421, 799.31));
    await windowManager.show();
  });

  runApp(const MyApp());
}

WindowOptions windowOptions = WindowOptions(
  minimumSize: Size(1421, 799.31),
  size: Size(1430, 804.38),
  title: 'NLRC Attendance System',
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NLRC Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'readexPro',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoadingScreen(),
    );
  }
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await checkConnectivity();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage()),
        );
      }
    } on TimeoutException {
      setState(() {
        _errorMessage = "Connection timed out. Please check your internet.";
      });
    } on SocketException {
      setState(() {
        _errorMessage = "No internet connection. Please check your network.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _retry() {
    _initializeApp();
  }

  void _exit() {
    exit(0); // Exits the app
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'Fetching data, please wait...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _exit,
                    child: const Text('Exit'),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> checkConnectivity() async {
  final result = await InternetAddress.lookup('example.com')
      .timeout(const Duration(seconds: 5), onTimeout: () {
    throw TimeoutException("Internet check timed out");
  });
  if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
    await updateNullTimeOut();
    await deleteExpiredAnnouncements();

    await fetchDataAndGenerateDartFile();
    await fetchAttendance();
    await fetchAdminLogin();
    await fetchAnnouncements();

    await fetchUsers();
    await fetchLoggedUsers();
    await fetchAttendanceData();
  }

  adminAnnouncement = await loadAnnouncements();
  users = await loadUsers();
  attendance = await loadAttendance();
  adminData = await loadAdmin();
}
