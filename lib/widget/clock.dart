import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/painting.dart'; // Correct import for TextDirection

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final formattedDate =
            DateFormat('EEEE: MMMM, d, y').format(now); // Date format
        final dayName = DateFormat('EEEE').format(now);

        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                //color: primaryBlue,
              ),
              width: MediaQuery.sizeOf(context).width / 1.5,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Analog Clock
                  SizedBox(
                    height: 300,
                    width: 300,
                    child: CustomPaint(
                      painter: AnalogClockPainter(now),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date
                  Text(
                    '$formattedDate',
                    style: GoogleFonts.readexPro(
                      fontSize: MediaQuery.sizeOf(context).width / 50,
                      color: primaryWhite,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Digital Clock
                  Text(
                    DateFormat('hh:mm:ss a').format(now),
                    style: GoogleFonts.readexPro(
                      fontSize: MediaQuery.sizeOf(context).width / 10,
                      color: primaryWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnalogClockPainter extends CustomPainter {
  final DateTime now;

  AnalogClockPainter(this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw clock face
    canvas.drawCircle(center, radius, paint);

    // Draw hour marks
    for (int i = 0; i < 12; i++) {
      final angle = i * 30 * (3.14159 / 180);
      final outerPoint = Offset(
        center.dx + radius * 0.93 * cos(angle - pi / 2),
        center.dy + radius * 0.93 * sin(angle - pi / 2),
      );
      final innerPoint = Offset(
        center.dx + radius * 0.75 * cos(angle - pi / 2),
        center.dy + radius * 0.75 * sin(angle - pi / 2),
      );
      canvas.drawLine(innerPoint, outerPoint, paint);
    }

    // Draw clock numbers
    TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );

    TextStyle largeTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );
    TextStyle smallTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
    );

    // Numbers for 12, 3, 6, and 9 (big numbers)
    List<int> bigNumbers = [12, 3, 6, 9];
    for (int number in bigNumbers) {
      final angle = (number % 12) * 30 * (3.14159 / 180);
      final offset = Offset(
        center.dx + radius * 0.65 * cos(angle - pi / 2),
        center.dy + radius * 0.65 * sin(angle - pi / 2),
      );
      textPainter.text = TextSpan(
        text: '$number',
        style: largeTextStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas,
          offset - Offset(textPainter.width / 2, textPainter.height / 2));
    }

    // Numbers for other hours (small numbers)
    for (int i = 1; i < 12; i++) {
      if (bigNumbers.contains(i)) continue; // Skip 12, 3, 6, 9
      final angle = i * 30 * (3.14159 / 180);
      final offset = Offset(
        center.dx + radius * 0.65 * cos(angle - pi / 2),
        center.dy + radius * 0.65 * sin(angle - pi / 2),
      );
      textPainter.text = TextSpan(
        text: '$i',
        style: smallTextStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas,
          offset - Offset(textPainter.width / 2, textPainter.height / 2));
    }

    // Draw clock hands
    final hourHandPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final minuteHandPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final secondHandPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final hour = now.hour % 12;
    final minute = now.minute;
    final second = now.second;

    final hourAngle = (hour + minute / 60) * 30 * (3.14159 / 180);
    final minuteAngle = (minute + second / 60) * 6 * (3.14159 / 180);
    final secondAngle = second * 6 * (3.14159 / 180);

    final hourHand = Offset(
      center.dx + radius * 0.5 * cos(hourAngle - pi / 2),
      center.dy + radius * 0.5 * sin(hourAngle - pi / 2),
    );
    final minuteHand = Offset(
      center.dx + radius * 0.7 * cos(minuteAngle - pi / 2),
      center.dy + radius * 0.7 * sin(minuteAngle - pi / 2),
    );
    final secondHand = Offset(
      center.dx + radius * 0.9 * cos(secondAngle - pi / 2),
      center.dy + radius * 0.9 * sin(secondAngle - pi / 2),
    );

    canvas.drawLine(center, hourHand, hourHandPaint);
    canvas.drawLine(center, minuteHand, minuteHandPaint);
    canvas.drawLine(center, secondHand, secondHandPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Continuously repaint to update the clock
  }
}
