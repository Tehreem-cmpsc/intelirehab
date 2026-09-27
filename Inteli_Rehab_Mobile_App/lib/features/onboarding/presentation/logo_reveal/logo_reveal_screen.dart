// import 'dart:async';
// import 'package:flutter/material.dart';
// import '../../../../core/theme/app_theme.dart';
// import '../../../../main.dart' show AuthGate;
//
// class LogoRevealScreen extends StatefulWidget {
//   const LogoRevealScreen({super.key});
//
//   @override
//   State<LogoRevealScreen> createState() => _LogoRevealScreenState();
// }
//
// class _LogoRevealScreenState extends State<LogoRevealScreen>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;
//   late final Animation<double> _opacity;
//   late final Animation<double> _scale;
//   Timer? _navTimer;
//   bool _navigating = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     );
//     _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
//     _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
//     );
//
//     _controller.forward().whenComplete(() {
//       _navTimer = Timer(const Duration(milliseconds: 700), _goToLogin);
//     });
//   }
//
//   void _goToLogin() {
//     if (_navigating || !mounted) return;
//     _navigating = true;
//     Navigator.of(context).pushReplacement(
//       PageRouteBuilder(
//         transitionDuration: const Duration(milliseconds: 600),
//         pageBuilder: (_, animation, __) => const AuthGate(),
//         transitionsBuilder: (_, animation, __, child) =>
//             FadeTransition(opacity: animation, child: child),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _navTimer?.cancel();
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final double screenWidth = MediaQuery.of(context).size.width;
//     final double logoSize = (screenWidth * 0.55).clamp(150.0, 220.0);
//
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         backgroundColor: AppTheme.backgroundWhite,
//         body: Center(
//           child: FadeTransition(
//             opacity: _opacity,
//             child: ScaleTransition(
//               scale: _scale,
//               child: Image.asset(
//                 'assets/images/full_logo.png',
//                 width: logoSize,
//                 height: logoSize,
//                 fit: BoxFit.contain,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }