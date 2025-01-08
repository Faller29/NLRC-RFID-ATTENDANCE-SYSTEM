// Define the readFileContent function to read a file as a string
import 'dart:convert';
import 'dart:io';
import 'package:nlrc_rfid_scanner/backend/data/fetch_data.dart';
import 'package:nlrc_rfid_scanner/main.dart';
import 'package:path_provider/path_provider.dart';

Future<String> readFileContent(File file) async {
  // Check if the file exists
  if (await file.exists()) {
    return await file.readAsString();
  } else {
    throw Exception('File does not exist');
  }
}

// Define the function to load and parse users from the Dart file
Future<List<Map<String, dynamic>>> loadUsers() async {
  final directory = await getApplicationCacheDirectory();
  final file = File('${directory.path}/users.json');
  final fileContent = await readFileContent(file);

  // You would typically have a JSON string here, so let's decode it
  List<dynamic> jsonData = jsonDecode(fileContent);

  // Convert the JSON data into a list of Maps
  return jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
}

// Define the function to load and parse users from the Dart file
Future<List<Map<String, dynamic>>> loadAttendance() async {
  final directory = await getApplicationCacheDirectory();
  final file = File('${directory.path}/attendance.json');
  final fileContent = await readFileContent(file);

  // You would typically have a JSON string here, so let's decode it
  List<dynamic> jsonData = jsonDecode(fileContent);

  // Convert the JSON data into a list of Maps
  return jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
}

/// Define the function to load and parse admin data from the local JSON file
Future<Map<String, dynamic>?> loadAdmin() async {
  try {
    // Get the application's local documents directory
    final directory = await getApplicationCacheDirectory();
    final file = File('${directory.path}/admin_account.json');

    // Check if the file exists
    if (await file.exists()) {
      // Read the file content as a string
      final fileContent = await file.readAsString();

      // Decode the JSON content into a Map
      Map<String, dynamic> adminData = jsonDecode(fileContent);
      return adminData;
    } else {
      print('Admin file does not exist at: ${file.path}');
      return null;
    }
  } catch (e) {
    print('Error reading admin file: $e');
    return null;
  }
}

/// Define the function to load and parse announcement data from the local JSON file
Future<List<Map<String, dynamic>>> loadAnnouncements() async {
  // Get the application's local documents directory
  final directory = await getApplicationCacheDirectory();
  print(directory.path);
  final file = File('${directory.path}/announcements.json');
  final fileContent = await readFileContent(file);
  // You would typically have a JSON string here, so let's decode it
  List<dynamic> attendanceData = jsonDecode(fileContent);
  // Convert the JSON data into a list of Maps
  return attendanceData.map((item) => Map<String, dynamic>.from(item)).toList();
}


  /* 
  try {
    // Get the application's local documents directory
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/announcements.json');

    // Check if the file exists
    if (await file.exists()) {
      // Read the file content as a string
      final fileContent = await file.readAsString();

      // Decode the JSON content into a list of maps
      final List<dynamic> jsonData = jsonDecode(fileContent);

      // Map each item to an Announcement object
      final List<Announcement> announcements = jsonData.map((data) {
        return Announcement.fromMap(data as Map<String, dynamic>);
      }).toList();

      return announcements;
    } else {
      print('Announcements file does not exist at: ${file.path}');
      return null;
    }
  } catch (e) {
    print('Error reading announcements file: $e');
    return null;
  } */

