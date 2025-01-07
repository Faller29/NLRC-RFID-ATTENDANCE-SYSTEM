/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
//import 'package:nlrc_rfid_scanner/assets/data/users.dart';
import 'package:nlrc_rfid_scanner/main.dart';
import 'package:nlrc_rfid_scanner/modals/scanned_modal.dart';

class RFIDBackend {
  String rfidData = '';
  Timer? expirationTimer;
  List<String> awayModeNotifications = [];
  bool isModalOpen = false;

  void onKey(KeyEvent event, DateTime lastKeypressTime, Function setState,
      bool isReceiveMode, BuildContext context) {
    if (event is KeyDownEvent) {
      if (event.logicalKey.keyLabel.isEmpty) return;

      final String data = event.logicalKey.keyLabel;
      print(data);

      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(lastKeypressTime);

      setState(() {
        rfidData += data;
      });

      _startExpirationTimer(setState);

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (rfidData.isNotEmpty && rfidData.length >= 9) {
          String filteredData = _filterRFIDData(rfidData);
          filteredData = '$filteredData';

          bool isRFIDExists = _checkRFIDExists(filteredData);

          if (isRFIDExists) {
            if (isReceiveMode) {
              _addToAwayModeNotifications(filteredData, setState);
              _showRFIDModal(filteredData, currentTime, setState, context);
            } else {
              _addToAwayModeNotifications(filteredData, setState);
            }
          } else {
            debugPrint('RFID not found in users list.');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('User not found or registered'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }

          setState(() {
            rfidData = '';
          });
        } else {
          debugPrint('RFID data is empty or insufficient on Enter key event.');
        }
      }
    }
  }

  bool _checkRFIDExists(String rfid) {
    for (var user in localUsers) {
      if (user['rfid'] == rfid) {
        return true;
      }
    }
    return false;
  }

  String _filterRFIDData(String data) {
    return data.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _startExpirationTimer(Function setState) {
    if (expirationTimer != null) {
      expirationTimer!.cancel();
    }

    expirationTimer = Timer(const Duration(milliseconds: 30), () {
      if (rfidData.isNotEmpty) {
        debugPrint('Expiration timer triggered: Clearing RFID data.');
        setState(() {
          rfidData = '';
        });
      }
    });
  }

  void _showRFIDModal(String rfidData, DateTime timestamp, Function setState,
      BuildContext context,
      {VoidCallback? onRemoveNotification}) {
    var matchedUser = _findUserByRFID(rfidData);

    if (matchedUser != null) {
      setState(() {
        isModalOpen = true;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ScannedModal(
            rfidData: rfidData,
            timestamp: timestamp,
            userData: matchedUser,
            onRemoveNotification: onRemoveNotification,
          );
        },
      ).then((_) {
        setState(() {
          isModalOpen = false;
        });
      });
    }
  }

  Map<String, dynamic>? _findUserByRFID(String rfid) {
    return users.firstWhere((user) => user['rfid'] == rfid, orElse: () => {});
  }

  void _addToAwayModeNotifications(String rfidData, Function setState) {
    final DateTime currentTime = DateTime.now();
    setState(() {
      awayModeNotifications.add('$rfidData|$currentTime');
    });
  }
}
 */