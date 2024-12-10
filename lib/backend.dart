

/* import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const RFIDApp());
}

class RFIDApp extends StatelessWidget {
  const RFIDApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFID Listener',
      home: const RFIDListenerPage(),
    );
  }
}

class RFIDListenerPage extends StatefulWidget {
  const RFIDListenerPage({Key? key}) : super(key: key);

  @override
  State<RFIDListenerPage> createState() => _RFIDListenerPageState();
}

class _RFIDListenerPageState extends State<RFIDListenerPage> {
  String _rfidData = '';
  final FocusNode _focusNode = FocusNode();
  bool _isRFIDScanning = false;
  DateTime _lastKeypressTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Handle key press event
  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final String data = event.logicalKey.debugName ?? '';
      final DateTime currentTime = DateTime.now();
      final Duration timeDifference = currentTime.difference(_lastKeypressTime);

      if (data.isNotEmpty && _isRFIDInput(data, timeDifference)) {
        setState(() {
          _rfidData += data; // Accumulate scanned data
        });

        if (event.logicalKey == LogicalKeyboardKey.enter) {
          // RFID scan is complete when the Enter key is pressed as it is also in the type of stroke sa RFID
          String filteredData = _filterRFIDData(_rfidData);
          _showRFIDModal(filteredData);
          setState(() {
            _rfidData = '';
          });
        }
      }

      _lastKeypressTime = currentTime;
    }
  }

  bool _isRFIDInput(String data, Duration timeDifference) {
    //making other approach
    return timeDifference.inMilliseconds < 10 && data.length > 3;
  }

  // Use a regular expression para idelete yung non numeric characters o letters
  String _filterRFIDData(String data) {
    final filteredData = data.replaceAll(RegExp(r'[^0-9]'), '');
    return filteredData;
  }

  void _showRFIDModal(String rfidData) {
    print(rfidData);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RFID Detected'),
        content: Text('Scanned RFID: $rfidData'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing backend'),
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Listening for RFID'),
              const SizedBox(height: 20),
              Text('RFID: $_rfidData'),
            ],
          ),
        ),
      ),
    );
  }
}
 */