import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import 'widgets/create_group_sheet.dart';
import 'widgets/join_group_sheet.dart';

class JoinOrCreateScreen extends StatefulWidget {
  const JoinOrCreateScreen({super.key});

  @override
  State<JoinOrCreateScreen> createState() => _JoinOrCreateScreenState();
}

class _JoinOrCreateScreenState extends State<JoinOrCreateScreen> {
  int? _selectedIndex; // null = none, 0 = Create, 1 = Join

  void _showCreateGroupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const CreateGroupSheet(),
    );
  }

  void _showJoinGroupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const JoinGroupSheet(),
    );
  }

  Widget _buildCreativeCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color iconColor,
    required Color bgColor,
    required List<Color> patternColors,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: AnimatedScale(
          scale: isSelected ? 1.04 : 0.96,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF5BA72D) : const Color(0xFFE0E0E0),
                width: isSelected ? 2.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF5BA72D).withOpacity(0.1)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Illustration Container
                    Expanded(
                      flex: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Decorative backdrop circle 1
                            Positioned(
                              right: -10,
                              top: -10,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: patternColors[0],
                                ),
                              ),
                            ),
                            // Decorative backdrop circle 2
                            Positioned(
                              left: -20,
                              bottom: -20,
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: patternColors[1],
                                ),
                              ),
                            ),
                            // Stylized big icon representing action
                            Icon(
                              iconData,
                              color: iconColor,
                              size: 42,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom Info Container
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1D3108),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Checked badge overlay
                if (isSelected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF5BA72D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, bottomPadding + 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (32.0 + bottomPadding),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Title & Subtitle
                      Text(
                        'Join or Create',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D3108),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AjoPay is built around saving together. Choose how you would like to get started.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Side-by-Side Creative Cards
                      Row(
                        children: [
                          _buildCreativeCard(
                            index: 0,
                            title: 'Create Group',
                            subtitle: 'Start a new pool',
                            iconData: Icons.group_add_rounded,
                            iconColor: const Color(0xFF5BA72D),
                            bgColor: const Color(0xFFE8F6E0),
                            patternColors: [
                              const Color(0xFF5BA72D).withOpacity(0.12),
                              const Color(0xFF5BA72D).withOpacity(0.04),
                            ],
                          ),
                          const SizedBox(width: 16),
                          _buildCreativeCard(
                            index: 1,
                            title: 'Join Group',
                            subtitle: 'Use invite code',
                            iconData: Icons.link_rounded,
                            iconColor: const Color(0xFF4A90E2),
                            bgColor: const Color(0xFFEAF2FF),
                            patternColors: [
                              const Color(0xFF4A90E2).withOpacity(0.15),
                              const Color(0xFF4A90E2).withOpacity(0.04),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Centered visual illustration to fill empty space
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFC8E6A0).withOpacity(0.4),
                                      const Color(0xFFACEC87).withOpacity(0.08),
                                    ],
                                  ),
                                ),
                              ),
                              Image.asset(
                                'assets/images/joinorcreate.png',
                                fit: BoxFit.contain,
                                height: 220,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Selection helper indicator
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Select an option above to continue.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Button Row (CashApp Style)
                      Row(
                        children: [
                          // Left button: "Back" when there's somewhere to return to
                          // (in-app entry point), "Skip" for true onboarding (no back stack).
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: TextButton(
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.goNamed(AppRoute.home.name);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: Text(
                                  context.canPop() ? 'Back' : 'Skip',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Continue Button (Right, Pill shape, brand solid green)
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _selectedIndex != null
                                    ? () {
                                        if (_selectedIndex == 0) {
                                          _showCreateGroupSheet(context);
                                        } else {
                                          _showJoinGroupSheet(context);
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFACEC87),
                                  foregroundColor: const Color(0xFF1D3108),
                                  disabledBackgroundColor: const Color(0xFFF3F4F6),
                                  disabledForegroundColor: const Color(0xFF9CA3AF),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: Text(
                                  'Continue',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
