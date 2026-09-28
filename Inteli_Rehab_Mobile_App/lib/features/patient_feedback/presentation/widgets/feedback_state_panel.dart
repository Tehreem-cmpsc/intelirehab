import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

enum FeedbackPanelState { loading, empty, error }

/// Unified presentational container for feedback Loading, Empty, and Error states.
/// Replaces duplicated nested Containers and Columns with a consistent layout.
class FeedbackStatePanel extends StatelessWidget {
  final FeedbackPanelState state;
  final VoidCallback? onRetry;

  const FeedbackStatePanel({
    super.key,
    required this.state,
    this.onRetry,
  });

  const FeedbackStatePanel.loading({super.key})
      : state = FeedbackPanelState.loading,
        onRetry = null;

  const FeedbackStatePanel.empty({super.key})
      : state = FeedbackPanelState.empty,
        onRetry = null;

  const FeedbackStatePanel.error({super.key, required this.onRetry})
      : state = FeedbackPanelState.error;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIconOrSpinner(colors),
          const SizedBox(height: 16),
          Text(
            _headingText,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _subtitleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: colors.secondaryText,
            ),
          ),
          if (state == FeedbackPanelState.error && onRetry != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Try again',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primaryButton,
                side: BorderSide(color: colors.primaryButton, width: 1.2),
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconOrSpinner(AppThemeColors colors) {
    switch (state) {
      case FeedbackPanelState.loading:
        return SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            color: colors.primaryButton,
          ),
        );
      case FeedbackPanelState.empty:
        return Icon(
          Icons.chat_bubble_outline_rounded,
          size: 28,
          color: colors.secondaryText,
        );
      case FeedbackPanelState.error:
        return Icon(
          Icons.info_outline_rounded,
          size: 28,
          color: colors.errorText,
        );
    }
  }

  String get _headingText {
    switch (state) {
      case FeedbackPanelState.loading:
        return 'Loading patient stories…';
      case FeedbackPanelState.empty:
        return 'Patient stories will appear here';
      case FeedbackPanelState.error:
        return "Patient stories couldn't load";
    }
  }

  String get _subtitleText {
    switch (state) {
      case FeedbackPanelState.loading:
        return 'Retrieving shared experiences.';
      case FeedbackPanelState.empty:
        return 'You can continue to sign in.';
      case FeedbackPanelState.error:
        return 'Please try again, or continue to sign in.';
    }
  }
}
