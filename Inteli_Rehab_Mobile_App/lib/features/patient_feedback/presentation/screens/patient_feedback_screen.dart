import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../data/repositories/patient_feedback_repository_fake.dart';
import '../../domain/entities/patient_feedback_entity.dart';
import '../../domain/repositories/patient_feedback_repository.dart';
import '../widgets/feedback_state_panel.dart';
import '../widgets/patient_feedback_card.dart';
import '../widgets/patient_stories_header.dart';

/// Patient Stories (feedback) screen designed for Inteli-Rehab.
/// 
/// Key characteristics:
/// - Light mode only, calm healthcare aesthetic (off-white #F5F8F7, teal #0D6E76, white cards).
/// - Manual scrolling only — zero videos, carousels, or automated transitions.
/// - Clearly labeled sample stories for preview without inflated medical claims.
/// - Pinned bottom "Continue to sign in" action accessible across all states.
/// - Fully responsive across 320dp phones, tablets, and 200% text scale.
class PatientFeedbackScreen extends StatefulWidget {
  final PatientFeedbackRepository? repository;
  final AuthRepository? authRepository;
  final bool isPreviewSample;

  const PatientFeedbackScreen({
    super.key,
    this.repository,
    this.authRepository,
    this.isPreviewSample = true,
  });

  @override
  State<PatientFeedbackScreen> createState() => _PatientFeedbackScreenState();
}

class _PatientFeedbackScreenState extends State<PatientFeedbackScreen> {
  late final PatientFeedbackRepository _repo;
  late Future<List<PatientFeedbackEntity>> _future;
  bool _navigatingToLogin = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        (sl.isRegistered<PatientFeedbackRepository>()
            ? sl<PatientFeedbackRepository>()
            : PatientFeedbackRepositoryFake());
    _future = _repo.getFeaturedFeedback();
  }

  void _retry() {
    setState(() {
      _future = _repo.getFeaturedFeedback();
    });
  }

  Future<void> _handleRefresh() async {
    try {
      final updated = await _repo.getFeaturedFeedback();
      if (mounted) {
        setState(() {
          _future = Future.value(updated);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Couldn't refresh patient stories. Showing previously loaded stories.",
              style: GoogleFonts.manrope(fontSize: 14),
            ),
            backgroundColor: AppTheme.colors(context).heading,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _continueToSignIn() {
    if (_navigatingToLogin || !mounted) return;
    setState(() => _navigatingToLogin = true);

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(repository: widget.authRepository),
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() => _navigatingToLogin = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: const PatientStoriesHeader(),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: FutureBuilder<List<PatientFeedbackEntity>>(
              future: _future,
              builder: (context, snapshot) {
                return RefreshIndicator(
                  color: colors.primaryButton,
                  backgroundColor: colors.cardSurface,
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Persistent Introduction — visible across all states
                        _buildStoriesIntro(colors),
                        const SizedBox(height: 24),

                        // Content based on snapshot state
                        _buildStateContent(colors, snapshot),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAction(colors),
    );
  }

  /// Persistent introduction section that anchors screen identity across all states.
  Widget _buildStoriesIntro(AppThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Patient stories',
          style: GoogleFonts.sora(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: colors.heading,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Experiences shared by people using Inteli-Rehab.',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: colors.secondaryText,
          ),
        ),
      ],
    );
  }

  /// State switcher: Loading, Error, Empty, or Stacked Feedback Cards.
  Widget _buildStateContent(
    AppThemeColors colors,
    AsyncSnapshot<List<PatientFeedbackEntity>> snapshot,
  ) {
    // 1. Loading state
    if (snapshot.connectionState != ConnectionState.done) {
      return const FeedbackStatePanel.loading();
    }

    // 2. Error state
    if (snapshot.hasError) {
      return FeedbackStatePanel.error(onRetry: _retry);
    }

    final items = snapshot.data ?? const <PatientFeedbackEntity>[];

    // 3. Empty state
    if (items.isEmpty) {
      return const FeedbackStatePanel.empty();
    }

    // 4. Success state with honest sample-data notice and stacked cards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isPreviewSample) ...[
          Text(
            'Sample stories for this preview.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return PatientFeedbackCard(item: items[index]);
          },
        ),
      ],
    );
  }

  /// Pinned bottom bar with full-width primary action.
  Widget _buildBottomAction(AppThemeColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border(
          top: BorderSide(color: colors.border, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: ElevatedButton(
                key: const Key('patient_stories_continue_button'),
                onPressed: _navigatingToLogin ? null : _continueToSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryButton,
                  foregroundColor: colors.primaryButtonText,
                  disabledBackgroundColor: colors.primaryButton.withValues(alpha: 0.6),
                  disabledForegroundColor: colors.primaryButtonText.withValues(alpha: 0.8),
                  elevation: 0,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: Text(
                  'Continue to sign in',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.primaryButtonText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
