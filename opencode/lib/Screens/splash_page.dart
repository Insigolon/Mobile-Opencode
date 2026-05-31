import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Center(
        child: Opacity(
          opacity: 0.5,
          child: SvgPicture.asset("assets/opencode.svg", width: 300),
        ),
      ),
    );
  }
}
