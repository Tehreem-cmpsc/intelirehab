import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/patient_feedback_entity.dart';
import '../utils/patient_initials_helper.dart';

/// Refined presentational card displaying a single patient feedback story.
/// 
/// Follows healthcare UI guidelines:
/// - Flexible height based on quote length.
/// - Privacy-preserving decorative avatar with Unicode initials.
/// - Clear typography hierarchy without exaggerated badges or medical claims.
class PatientFeedbackCard extends StatelessWidget {
  final PatientFeedbackEntity item;

  const PatientFeedbackCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final initials = PatientInitialsHelper.extract(item.patientDisplayName);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A. Patient quote
          Text(
            '“${item.message}”',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: colors.bodyText,
            ),
          ),
          const SizedBox(height: 20),

          // B. Patient details
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Initials avatar (decorative for screen readers since full name is spoken)
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.infoSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initials,
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.infoText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Patient name and experience tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.patientDisplayName,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.heading,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patient experience',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
