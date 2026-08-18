import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup fade-in animation for UI elements
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Automatically navigate after 2 seconds
    Timer(const Duration(seconds: 2), _navigateToHome);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Deep Slate Navy
              Color(0xFF020617), // Rich Midnight Black
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo container with a subtle glow/shadow
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // App Title
                      const Text(
                        'CLOUD SCANNER',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Muted Subtitle
                      Text(
                        'Enterprise QR Scanner & Logger',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.0,
                          color: const Color(0xFF94A3B8).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom loading indicator
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF0EA5E9).withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Initializing...',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.0,
                            color: const Color(0xFF94A3B8).withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
