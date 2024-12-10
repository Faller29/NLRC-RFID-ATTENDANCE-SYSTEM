import 'package:flutter/services.dart';

class RFIDHandler {
  DateTime _lastKeypressTime = DateTime.now();

  /// Filters the RFID data to remove non-numeric characters
  String filterRFIDData(String data) {
    return data.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Determines whether the input is valid RFID input based on time difference and data length
  bool isRFIDInput(String data, Duration timeDifference) {
    return timeDifference.inMilliseconds < 10 && data.length > 3;
  }

  /// Processes key input to update RFID data
  String processKeyInput(KeyEvent event, String currentData) {
    print(currentData);
    if (event is KeyDownEvent) {
      final String data = event.logicalKey.debugName ?? '';
      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(_lastKeypressTime);

      if (data.isNotEmpty && isRFIDInput(data, timeDifference)) {
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          _lastKeypressTime = currentTime; // Reset the keypress time
          return ''; // Reset RFID data
        }
        _lastKeypressTime = currentTime;
        return currentData + data; // Accumulate RFID data
      }
    }
    return currentData; // No change in RFID data
  }
}
