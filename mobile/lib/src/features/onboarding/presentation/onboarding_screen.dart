import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'Save together without worrying.',
      description:
          'No more "I sent it" disputes or missing treasurers. Every contribution is tracked automatically.',
      imagePath: 'assets/images/image-removebg-preview (1).png',
    ),
    OnboardingStep(
      title: 'Everyone gets their own account.',
      description:
          'Each member receives a dedicated virtual account. Every payment is instantly reconciled and visible to the group.',
      imagePath: 'assets/images/image-removebg-preview (2).png',
    ),
    OnboardingStep(
      title: 'Never miss a payout.',
      description:
          "When it's your turn, PayAjo automatically sends your payout and keeps everyone updated.",
      imagePath: 'assets/images/image-removebg-preview (3).png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToHome();
    }
  }

  void _onSkip() {
    _navigateToHome();
  }

  void _navigateToHome() {
    context.goNamed(AppRoute.login.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Page Content (Illustrations & Text)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration Area with a premium floating background circle
                        SizedBox(
                          width: double.infinity,
                          height: 380,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative soft gradient circle background
                              Container(
                                width: 300,
                                height: 300,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFC8E6A0).withOpacity(0.5),
                                      const Color(0xFFACEC87).withOpacity(0.1),
                                    ],
                                  ),
                                ),
                              ),
                              // Floating transparent illustration
                              Image.asset(
                                step.imagePath,
                                fit: BoxFit.contain,
                                height: 340,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Title (Space Grotesk)
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'SpaceGrotesk', 
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Description (Inter)
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 15,
                            color: Colors.grey[600],
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Area (Indicators, Skip, Next)
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(
                                  0xFF5BA72D,
                                ) // active dot (darker green)
                              : const Color(
                                  0xFFE5E7EB,
                                ), // inactive dot (light gray)
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  // Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip Button (Pill shape)
                      TextButton(
                        onPressed: _onSkip,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F4F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            color: const Color(0xFF4B5563),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Circular Next Button with Outer Ring
                      GestureDetector(
                        onTap: _onNext,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFC8E6A0),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(
                            4,
                          ), // spacing for ring effect
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFACEC87), // brand light green
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF1D3108),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final String imagePath;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}
