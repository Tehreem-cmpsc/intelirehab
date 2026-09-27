import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/patient_feedback_entity.dart';
import '../../domain/repositories/patient_feedback_repository.dart';
import '../../data/repositories/patient_feedback_repository_fake.dart';

class PatientFeedbackScreen extends StatefulWidget {
  final PatientFeedbackRepository? repository;
  const PatientFeedbackScreen({super.key, this.repository});

  @override
  State<PatientFeedbackScreen> createState() => _PatientFeedbackScreenState();
}

class _PatientFeedbackScreenState extends State<PatientFeedbackScreen> {
  late final PatientFeedbackRepository _repo;
  late Future<List<PatientFeedbackEntity>> _future;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PatientFeedbackRepositoryFake();
    _future = _repo.getFeaturedFeedback();
  }

  void _retry() => setState(() => _future = _repo.getFeaturedFeedback());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Patient Feedback'),
      ),
      body: FutureBuilder<List<PatientFeedbackEntity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.red),
                  const SizedBox(height: 12),
                  const Text('Failed to load patient experiences.', style: TextStyle(fontSize: 15, color: AppTheme.slate600)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }
          final items = snapshot.data ?? const <PatientFeedbackEntity>[];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No featured feedback is available yet.',
                style: TextStyle(fontSize: 16, color: AppTheme.slate500),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.primaryTeal,
            onRefresh: () async => _retry(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                const Text(
                  'Real progress, shared by patients',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.slate800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Encouraging experiences from people using guided rehabilitation.',
                  style: TextStyle(fontSize: 15, height: 1.4, color: AppTheme.slate500),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.tealSoftBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.primaryTeal),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Feedback shown here is reviewed by clinical therapists before it is featured.',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.primaryTealDark, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FeedbackCard(item: item),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final PatientFeedbackEntity item;
  const _FeedbackCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryTeal,
                child: Text(
                  item.patientDisplayName.isNotEmpty ? item.patientDisplayName.substring(0, 1) : 'P',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.patientDisplayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.slate800),
                    ),
                    Text(
                      item.exerciseName,
                      style: const TextStyle(fontSize: 13, color: AppTheme.slate500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.format_quote_rounded, color: AppTheme.tealBright, size: 28),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '“${item.message}”',
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppTheme.slate800,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < item.rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppTheme.amber,
                  size: 20,
                ),
              const Spacer(),
              Text(
                '${item.submittedAt.day}/${item.submittedAt.month}/${item.submittedAt.year}',
                style: const TextStyle(fontSize: 12, color: AppTheme.slate400, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (item.therapistResponse != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.tealSoftBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.tealLight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_services_outlined, size: 16, color: AppTheme.primaryTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Therapist Response',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTealDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.therapistResponse!,
                          style: const TextStyle(fontSize: 13, height: 1.35, color: AppTheme.slate800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
