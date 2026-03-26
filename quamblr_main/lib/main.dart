import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: QuamblrApp()));
}

class QuamblrApp extends StatelessWidget {
  const QuamblrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quamblr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return _MobileAppFrame(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}

class _MobileAppFrame extends StatelessWidget {
  final Widget child;

  const _MobileAppFrame({
    required this.child,
  });

  static const double _mobileFrameWidth = 430;
  static const double _frameBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useFramedLayout = constraints.maxWidth > _frameBreakpoint;

        if (!useFramedLayout) {
          return child;
        }

        final framedMediaQuery = MediaQuery.of(context).copyWith(
          size: const Size(_mobileFrameWidth, 0),
        );

        return ColoredBox(
          color: const Color(0xFFE6E6E6),
          child: Center(
            child: Container(
              width: _mobileFrameWidth,
              height: constraints.maxHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: Offset(0, 10),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: MediaQuery(
                data: framedMediaQuery,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}