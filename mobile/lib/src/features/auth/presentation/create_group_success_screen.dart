import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../data/user_repository.dart';
import 'widgets/fade_slide_in.dart';
import 'widgets/group_info_card.dart';
import 'widgets/success_illustration.dart';

class CreateGroupSuccessData {
  final String groupName;
  final String contributionAmount;
  final String contributionFrequency;
  final String inviteCode;

  const CreateGroupSuccessData({
    required this.groupName,
    required this.contributionAmount,
    required this.contributionFrequency,
    required this.inviteCode,
  });
}

class CreateGroupSuccessScreen extends ConsumerStatefulWidget {
  final CreateGroupSuccessData data;

  const CreateGroupSuccessScreen({super.key, required this.data});

  @override
  ConsumerState<CreateGroupSuccessScreen> createState() => _CreateGroupSuccessScreenState();
}

class _CreateGroupSuccessScreenState extends ConsumerState<CreateGroupSuccessScreen> with SingleTickerProviderStateMixin {
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

  // Onboarding hasn't happened yet the first time through (no PIN set), but
  // this screen is also reached later when creating an *additional* group —
  // in that case the user already has a PIN and shouldn't be sent through
  // PIN setup again.
  void _handleContinue(BuildContext context) {
    final hasPin = ref.read(currentUserProvider)?.hasPin ?? false;
    if (hasPin) {
      context.goNamed(AppRoute.home.name);
    } else {
      context.goNamed(AppRoute.pinSetup.name);
    }
  }

  void _handleInviteMembers(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.data.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code ${widget.data.inviteCode} copied to clipboard'),
        backgroundColor: const Color(0xFF1D3108),
      ),
    );
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
                      SuccessIllustration(assetPath: 'assets/images/create-group.png'),
                      const SizedBox(height: 32),
                      FadeSlideIn(
                        controller: _controller,
                        start: 0.15,
                        end: 0.55,
                        child: Text(
                          'Group Created 🎉',
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
                          'Your savings group is ready. Invite members and start collecting contributions securely.',
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
                            GroupInfoRow('Contribution Amount', data.contributionAmount),
                            GroupInfoRow('Contribution Frequency', data.contributionFrequency),
                            GroupInfoRow('Invite Code', data.inviteCode),
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
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        controller: _controller,
                        start: 0.65,
                        end: 1.0,
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TextButton(
                            onPressed: () => _handleInviteMembers(context),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(
                              'Invite Members (optional)',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4B5563),
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
