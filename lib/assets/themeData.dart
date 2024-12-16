import 'package:flutter/material.dart';

Color primaryRed = Color.fromARGB(255, 214, 30, 17);
Color primaryBlue = Color.fromARGB(255, 60, 17, 214);
Color primaryWhite = Color.fromARGB(255, 247, 236, 236);
Color primaryBlack = Color.fromARGB(255, 0, 0, 0);

SnackBar snackBarFailed(String text, BuildContext context) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width / 3, vertical: 10),
    backgroundColor: Colors.redAccent,
    content: Text(
      text,
      textAlign: TextAlign.center,
    ),
  );
}

SnackBar snackBarSuccess(String text, BuildContext context) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width / 3, vertical: 10),
    backgroundColor: Colors.greenAccent,
    content: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
  );
}
