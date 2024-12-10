import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nlrc_rfid_scanner/assets/themeData.dart';
import 'package:google_fonts/google_fonts.dart';

class clockWidget extends StatefulWidget {
  const clockWidget({super.key});

  @override
  State<clockWidget> createState() => _clockWidgetState();
}

class _clockWidgetState extends State<clockWidget> {
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 100,
              //vertical: 200,
            ),
            child: Card(
              elevation: 10,
              shadowColor: Colors.black,
              borderOnForeground: false,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: primaryBlue,
                ),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                height: MediaQuery.sizeOf(context).height / 2.5,
                width: MediaQuery.sizeOf(context).width,
                child: Center(
                    child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  height: MediaQuery.sizeOf(context).height,
                  width: MediaQuery.sizeOf(context).width,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black54,
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('hh:mm:ss a').format(DateTime.now()),
                      style: GoogleFonts.readexPro(
                          fontSize: MediaQuery.sizeOf(context).height / 4,
                          color: primaryWhite),
                    ),
                  ),
                )),
              ),
            ),
          ),
        );
      },
    );
  }
}
/* 
class customClockBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var 

  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return true;
  }
} */
