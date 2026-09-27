// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import '../../../../core/theme/app_theme.dart';
// import '../logo_reveal/logo_reveal_screen.dart';
//
// class VideoIntroScreen extends StatefulWidget {
//   const VideoIntroScreen({super.key});
//
//   @override
//   State<VideoIntroScreen> createState() => _VideoIntroScreenState();
// }
//
// class _VideoIntroScreenState extends State<VideoIntroScreen> {
//   late VideoPlayerController _controller;
//   bool _navigating = false;
//   bool _hasError = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.asset(
//       'assets/videos/feedback_wall.mp4',
//     );
//     _initializeVideo();
//   }
//
//   Future<void> _initializeVideo() async {
//     try {
//       await _controller.initialize();
//       if (!mounted) return;
//       setState(() {});
//       _controller.addListener(_checkVideoCompletion);
//       await _controller.play();
//     } catch (_) {
//       if (mounted) {
//         setState(() => _hasError = true);
//         _goToLogoReveal();
//       }
//     }
//   }
//
//   void _checkVideoCompletion() {
//     final value = _controller.value;
//     if (value.isInitialized &&
//         !value.isPlaying &&
//         value.duration > Duration.zero &&
//         value.position >= value.duration) {
//       _goToLogoReveal();
//     }
//   }
//
//   void _goToLogoReveal() {
//     if (_navigating || !mounted) return;
//     _navigating = true;
//     Navigator.of(context).pushReplacement(
//       PageRouteBuilder(
//         transitionDuration: const Duration(milliseconds: 500),
//         pageBuilder: (_, animation, __) => const LogoRevealScreen(),
//         transitionsBuilder: (_, animation, __, child) =>
//             FadeTransition(opacity: animation, child: child),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller.removeListener(_checkVideoCompletion);
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(
//           child: _hasError
//               ? const SizedBox.shrink()
//               : _controller.value.isInitialized
//                   ? AspectRatio(
//                       aspectRatio: _controller.value.aspectRatio,
//                       child: VideoPlayer(_controller),
//                     )
//                   : const CircularProgressIndicator(
//                       color: AppTheme.tealLight,
//                     ),
//         ),
//       ),
//     );
//   }
// }