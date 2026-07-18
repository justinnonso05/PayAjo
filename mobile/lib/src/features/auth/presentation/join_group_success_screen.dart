import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../data/user_repository.dart';
import 'widgets/fade_slide_in.dart';
import 'widgets/group_info_card.dart';
import 'widgets/success_illustration.dart';

class JoinGroupSuccessData {
  final String groupName;
  final int memberCount;
  final String contributionAmount;
  final String contributionFrequency;

  const JoinGroupSuccessData({
    required this.groupName,
    required this.memberCount,
    required this.contributionAmount,
    required this.contributionFrequency,
  });
}

class JoinGroupSuccessScreen extends ConsumerStatefulWidget {
  final JoinGroupSuccessData data;

  const JoinGroupSuccessScreen({super.key, required this.data});

  @override
  ConsumerState<JoinGroupSuccessScreen> createState() => _JoinGroupSuccessScreenState();
}

class _JoinGroupSuccessScreenState extends ConsumerState<JoinGroupSuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // See CreateGroupSuccessScreen._handleContinue — same reasoning: this
  // screen is also reached when joining an *additional* group after
  // onboarding, where the user already has a PIN.
  void _handleContinue(BuildContext context) {
    final hasPin = ref.read(currentUserProvider)?.hasPin ?? false;
    if (hasPin) {
      context.goNamed(AppRoute.home.name);
    } else {
      context.goNamed(AppRoute.pinSetup.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      SuccessIllustration(assetPath: 'assets/images/join-group.png'),
                      const SizedBox(height: 32),
                      FadeSlideIn(
                        controller: _controller,
                        start: 0.15,
                        end: 0.55,
                        child: Text(
                          'Welcome to the Group 🎉',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeSlideIn(
                        controller: _controller,
                        start: 0.25,
                        end: 0.65,
                        child: Text(
                          "You've successfully joined your savings group. You're all set to start contributing.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeSlideIn(
                        controller: _controller,
                        start: 0.35,
                        end: 0.75,
                        distance: 24,
                        child: GroupInfoCard(
                          rows: [
                            GroupInfoRow('Group Name', data.groupName),
                            GroupInfoRow('Number of Members', '${data.memberCount}'),
                            GroupInfoRow('Contribution Amount', data.contributionAmount),
                            GroupInfoRow('Contribution Frequency', data.contributionFrequency),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 32),
                      FadeSlideIn(
                        controller: _controller,
                        start: 0.55,
                        end: 0.9,
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _handleContinue(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFACEC87),
                              foregroundColor: const Color(0xFF1D3108),
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
