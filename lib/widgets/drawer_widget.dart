// import 'package:algecit/screens/tabs/equipments_tab.dart';
// import 'package:algecit/screens/tabs/students_tab.dart';
// import 'package:algecit/widgets/logout_widget.dart';
// import 'package:algecit/widgets/text_widget.dart';
// import 'package:flutter/material.dart';

// import '../screens/home_screen.dart';
// import '../utils/colors.dart';

// class DrawerWidget extends StatelessWidget {
//   const DrawerWidget({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: double.infinity,
//       width: 250,
//       color: primary,
//       child: SafeArea(
//           child: Padding(
//         padding: const EdgeInsets.only(top: 20),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.start,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Container(
//                   height: 50,
//                   width: 50,
//                   decoration: BoxDecoration(
//                       image: DecorationImage(
//                           image: AssetImage(
//                             'assets/images/logo.png',
//                           ),
//                           fit: BoxFit.cover),
//                       border: Border.all(color: primary!),
//                       shape: BoxShape.circle,
//                       color: Colors.white),
//                 ),
//                 TextWidget(
//                   text: 'INVENTRACK',
//                   fontFamily: 'Bold',
//                   fontSize: 16,
//                 ),
//                 Builder(builder: (context) {
//                   return IconButton(
//                     onPressed: () {
//                       Scaffold.of(context).closeDrawer();
//                     },
//                     icon: Icon(
//                       Icons.menu,
//                       color: primary!,
//                       size: 32,
//                     ),
//                   );
//                 }),
//               ],
//             ),
//             const SizedBox(
//               height: 50,
//             ),
//             ListTile(
//               leading: Icon(
//                 Icons.dashboard_outlined,
//                 color: Colors.white,
//               ),
//               onTap: () {
//                 Navigator.of(context).pushReplacement(MaterialPageRoute(
//                     builder: (context) => const HomeScreen()));
//               },
//               title: TextWidget(
//                 text: 'Dashboard',
//                 fontSize: 18,
//                 fontFamily: 'Bold',
//               ),
//             ),
//             ListTile(
//               leading: Icon(
//                 Icons.construction_outlined,
//                 color: Colors.white,
//               ),
//               onTap: () {
//                 Navigator.of(context).pushReplacement(MaterialPageRoute(
//                     builder: (context) => const EquipmentsTab()));
//               },
//               title: TextWidget(
//                 text: 'Tools',
//                 fontSize: 18,
//                 fontFamily: 'Bold',
//               ),
//             ),
//             ListTile(
//               leading: Icon(
//                 Icons.groups_3_outlined,
//                 color: Colors.white,
//               ),
//               onTap: () {
//                 Navigator.of(context).pushReplacement(MaterialPageRoute(
//                     builder: (context) => const StudentsTab()));
//               },
//               title: TextWidget(
//                 text: 'Students',
//                 fontSize: 18,
//                 fontFamily: 'Bold',
//               ),
//             ),
//             ListTile(
//               leading: Icon(
//                 Icons.logout,
//                 color: Colors.white,
//               ),
//               onTap: () {
//                 logout(context, HomeScreen());
//               },
//               title: TextWidget(
//                 text: 'Logout',
//                 fontSize: 18,
//                 fontFamily: 'Bold',
//               ),
//             ),
//           ],
//         ),
//       )),
//     );
//   }
// }
