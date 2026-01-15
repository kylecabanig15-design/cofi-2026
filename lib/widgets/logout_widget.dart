// import 'package:autour_mobile/screens/auth/login_screen.dart';
// import 'package:flutter/material.dart';

// logout(BuildContext context, Widget navigationRoute) {
//   return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//             title: const Text(
//               'Logout Confirmation',
//               style: TextStyle(fontFamily: 'Bold', fontWeight: FontWeight.bold),
//             ),
//             content: const Text(
//               'Are you sure you want to Logout?',
//               style: TextStyle(fontFamily: 'Regular'),
//             ),
//             actions: <Widget>[
//               MaterialButton(
//                 onPressed: () => Navigator.of(context).pop(true),
//                 child: const Text(
//                   'Close',
//                   style: TextStyle(
//                       fontFamily: 'Regular', fontWeight: FontWeight.bold),
//                 ),
//               ),
//               MaterialButton(
//                 onPressed: () async {
//                   Navigator.of(context).pushReplacement(
//                       MaterialPageRoute(builder: (context) => LoginScreen()));
//                 },
//                 child: const Text(
//                   'Continue',
//                   style: TextStyle(
//                       fontFamily: 'Regular', fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ));
// }
