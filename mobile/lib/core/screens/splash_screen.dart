import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Premium splash screen featuring a sleek "writing" wipe animation 
/// for the app name, soft glowing effects, and elegant composition.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _writeCtrl;
  late final AnimationController _subCtrl;

  // ── Animations ──────────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _writeReveal;
  late final Animation<double> _subOpacity;
  late final Animation<Offset> _subSlide;

  @override
  void initState() {
    super.initState();

    // 1. Logo: Subtle zoom and fade in
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInQuad),
    );

    // 2. Writing effect: Reveals text right-to-left
    _writeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _writeReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _writeCtrl, curve: Curves.easeInOutSine),
    );

    // 3. Subtitle: Fade and slide up
    _subCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _subOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subCtrl, curve: Curves.easeIn),
    );
    _subSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _subCtrl, curve: Curves.easeOutCubic),
    );

    // ── Sequence ─────────────────────────────────────────────────────────────
    _logoCtrl.forward().then((_) {
      _writeCtrl.forward().then((_) {
        _subCtrl.forward();
      });
    });

    // Navigate to home after 3.2 seconds
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _writeCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0075C4),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient circles
          Positioned(
            top: -100,
            right: -50,
            child: _glowCircle(300, Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: _glowCircle(400, Colors.white.withValues(alpha: 0.03)),
          ),

          // Main vertical content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              AnimatedBuilder(
                animation: _logoCtrl,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Title with "Writing" Reveal Effect (Right to Left for Arabic)
              AnimatedBuilder(
                animation: _writeCtrl,
                builder: (context, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: _writeReveal.value,
                      child: const Text(
                        'برق واضح',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Tagline Fade and Slide
              FadeTransition(
                opacity: _subOpacity,
                child: SlideTransition(
                  position: _subSlide,
                  child: const Text(
                    'سوقك الإلكتروني الأول',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom Loading spinner indicator
          Positioned(
            bottom: 60,
            child: FadeTransition(
              opacity: _subOpacity,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
