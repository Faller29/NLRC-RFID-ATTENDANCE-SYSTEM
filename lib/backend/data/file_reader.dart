// Define the readFileContent function to read a file as a string
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

Future<String> readAttendanceContent(String path) async {
  final directory = await getApplicationDocumentsDirectory();
  final attendance = File('${directory.path}/attendance.json');
  if (await attendance.exists()) {
    return await attendance.readAsString();
  } else {
    throw Exception('File does not exist');
  }
}

// Define the function to load and parse users from the Dart file
Future<List<Map<String, dynamic>>> loadAttendance() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/attendance.json');
  final fileContent = await readAttendanceContent(file.toString());

  // You would typically have a JSON string here, so let's decode it
  List<dynamic> jsonData = jsonDecode(fileContent);

  // Convert the JSON data into a list of Maps
  return jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
}
