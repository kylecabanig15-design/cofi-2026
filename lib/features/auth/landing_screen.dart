// import 'package:cofi/features/auth/login_screen.dart';
// import 'package:cofi/features/auth/signup_screen.dart';
// import 'package:cofi/features/home/home_screen.dart';
// import 'package:cofi/services/google_sign_in_service.dart';
// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cofi/utils/colors.dart';

// import 'package:cofi/widgets/button_widget.dart';
// import 'package:cofi/widgets/text_widget.dart';

// class LandingScreen extends StatefulWidget {
//   const LandingScreen({super.key});

//   @override
//   State<LandingScreen> createState() => _LandingScreenState();
// }

// class _LandingScreenState extends State<LandingScreen> {
//   bool _isSigningIn = false;

//   Future<void> _handleGoogleSignIn() async {
//     setState(() {
//       _isSigningIn = true;
//     });

//     try {
//       final userCredential = await GoogleSignInService.signInWithGoogle();

//       if (userCredential != null && mounted) {
//         // Navigate to home screen
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const HomeScreen(),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Google sign in failed: ${e.toString()}')),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSigningIn = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: background,
//       body: Container(
//         decoration: const BoxDecoration(
//           color: Colors.black,
//         ),
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 const SizedBox(height: 40),
//                 // Logo
//                 Center(
//                   child: Image.asset(
//                     'assets/images/logo.png',
//                     width: 150,
//                     height: 150,
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//                 const SizedBox(height: 30),

//                 // Headline
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     TextWidget(
//                       text: 'Find Cafes',
//                       fontSize: 48,
//                       color: Colors.grey[300]!,
//                       align: TextAlign.center,
//                       isBold: true,
//                     ),
//                     TextWidget(
//                       text: 'you love',
//                       fontSize: 48,
//                       color: Colors.grey[300]!,
//                       align: TextAlign.center,
//                       isBold: true,
//                     ),
//                     const SizedBox(height: 15),
//                     TextWidget(
//                       text: 'Discover and review the best cafes in your area',
//                       fontSize: 16,
//                       color: Colors.grey[500]!,
//                       align: TextAlign.center,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 50),

//                 // Google Login Button
//                 _buildSocialButton(
//                   icon: FontAwesomeIcons.google,
//                   text: _isSigningIn ? 'Signing in...' : 'Continue with Google',
//                   backgroundColor: Colors.white,
//                   textColor: Colors.white,
//                   iconColor: Colors.red,
//                   onPressed: _isSigningIn ? null : _handleGoogleSignIn,
//                 ),
//                 const SizedBox(height: 25),

//                 // Separator
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Container(
//                         height: 1,
//                         color: Colors.grey[700],
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 16),
//                       child: TextWidget(
//                         text: 'or',
//                         fontSize: 16,
//                         color: Colors.grey[500]!,
//                         align: TextAlign.center,
//                       ),
//                     ),
//                     Expanded(
//                       child: Container(
//                         height: 1,
//                         color: Colors.grey[700],
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 25),

//                 // Create Account Button
//                 SizedBox(
//                   width: double.infinity,
//                   height: 56,
//                   child: ButtonWidget(
//                     radius: 100,
//                     label: 'Create a free account',
//                     fontSize: 16,
//                     color: primary,
//                     textColor: Colors.white,
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const SignupScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                 // Login Link
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     TextWidget(
//                       text: 'Already have an account? ',
//                       fontSize: 14,
//                       color: Colors.grey[400]!,
//                       align: TextAlign.center,
//                     ),
//                     GestureDetector(
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const LoginScreen(),
//                           ),
//                         );
//                       },
//                       child: TextWidget(
//                         text: 'Log in',
//                         fontSize: 14,
//                         color: primary,
//                         align: TextAlign.center,
//                         isBold: true,
//                         decoration: TextDecoration.underline,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const Spacer(),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSocialButton({
//     required IconData icon,
//     required String text,
//     required Color backgroundColor,
//     required Color textColor,
//     required Color iconColor,
//     VoidCallback? onPressed,
//   }) {
//     return Container(
//       width: double.infinity,
//       height: 56,
//       decoration: BoxDecoration(
//         color: backgroundColor.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(100),
//         border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(100),
//           onTap: onPressed,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 FaIcon(
//                   icon,
//                   color: iconColor,
//                   size: 20,
//                 ),
//                 const SizedBox(width: 15),
//                 TextWidget(
//                   text: text,
//                   fontSize: 16,
//                   color: Colors.white,
//                   align: TextAlign.center,
//                   isBold: true,
//                 ),
//                 // Show loading indicator if signing in
//                 if (_isSigningIn)
//                   const Padding(
//                     padding: EdgeInsets.only(left: 10),
//                     child: SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                         strokeWidth: 2,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
