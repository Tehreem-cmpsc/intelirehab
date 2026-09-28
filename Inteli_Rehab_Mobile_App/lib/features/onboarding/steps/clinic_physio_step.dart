import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../onboarding_data.dart';
import '../onboarding_repository.dart';
import '../widgets/form_widgets.dart';

class ClinicPhysioStep extends StatefulWidget {
  final OnboardingData data;
  final bool showErrors;
  final OnboardingRepository repository;

  const ClinicPhysioStep({super.key, required this.data, required this.showErrors, required this.repository});

  @override
  State<ClinicPhysioStep> createState() => _ClinicPhysioStepState();
}

class _ClinicPhysioStepState extends State<ClinicPhysioStep> {
  String _query = '';
  late Future<List<Clinic>> _clinics = widget.repository.listClinics();
  final _physios = <String, Future<List<Physiotherapist>>>{};

  OnboardingData get data => widget.data;

  Future<List<Physiotherapist>> _physiosAt(String clinicId) =>
      _physios.putIfAbsent(clinicId, () => widget.repository.listPhysiotherapists(clinicId));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Loaded<List<Clinic>>(
          future: _clinics,
          onRetry: () => setState(() => _clinics = widget.repository.listClinics()),
          builder: _clinicSection,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: data.clinic == null
              ? const InfoBanner(
                  icon: Icons.touch_app_outlined,
                  text: 'Pick a clinic to see its physiotherapists.',
                )
              : _Loaded<List<Physiotherapist>>(
                  key: ValueKey(data.clinic!.id),
                  future: _physiosAt(data.clinic!.id),
                  onRetry: () => setState(() => _physios.remove(data.clinic!.id)),
                  builder: _physioSection,
                ),
        ),
      ],
    );
  }

  Widget _clinicSection(BuildContext context, List<Clinic> all) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final clinics = all
        .where((cl) => q.isEmpty || cl.name.toLowerCase().contains(q) || cl.address.toLowerCase().contains(q))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionBlock(
          title: 'Choose your clinic',
          error: widget.showErrors && data.clinic == null ? 'Choose a clinic' : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by name or city',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              if (clinics.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(all.isEmpty ? 'No clinics are available yet.' : 'No clinics match "$_query".',
                      textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
                ),
              for (final clinic in clinics) ...[
                SelectableCard(
                  selected: data.clinic?.id == clinic.id,
                  onTap: () => data.update(() {
                    if (data.clinic?.id != clinic.id) data.physio = null;
                    data.clinic = clinic;
                  }),
                  child: Row(
                    children: [
                      _IconTile(icon: Icons.local_hospital_outlined, active: data.clinic?.id == clinic.id),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Text(clinic.name,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.place_outlined, size: 13, color: c.muted),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(clinic.address,
                                      style: TextStyle(fontSize: 12, color: c.muted), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _physioSection(BuildContext context, List<Physiotherapist> physios) {
    return QuestionBlock(
      title: 'Choose your physiotherapist',
      helper: 'At ${data.clinic!.name}',
      error: widget.showErrors && data.physio == null ? 'Choose a physiotherapist' : null,
      child: physios.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const InfoBanner(
                  icon: Icons.event_busy_outlined,
                  tone: BannerTone.warning,
                  text: 'This clinic has no physiotherapists taking new patients right now. '
                      'Try another clinic, or check again later.',
                ),
                const SizedBox(height: 8),
                // Lists are cached per clinic while this step is open; a
                // physio approved in the portal meanwhile shows up on refetch.
                OutlinedButton.icon(
                  onPressed: () => setState(() => _physios.remove(data.clinic!.id)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Check again'),
                ),
              ],
            )
          : Column(
              children: [
                for (final p in physios) ...[
                  _PhysioCard(
                    physio: p,
                    selected: data.physio?.id == p.id,
                    onTap: () => data.update(() => data.physio = p),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _IconTile({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: active ? c.primary : c.primaryTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 21, color: active ? c.onPrimary : c.primary),
    );
  }
}

class _PhysioCard extends StatelessWidget {
  final Physiotherapist physio;
  final bool selected;
  final VoidCallback onTap;

  const _PhysioCard({required this.physio, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: selected ? c.primary : c.primaryTint,
            child: Text(physio.initials,
                style: TextStyle(fontWeight: FontWeight.w700, color: selected ? c.onPrimary : c.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(physio.fullName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                if (physio.specialization != null && physio.specialization!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(physio.specialization!, style: TextStyle(fontSize: 12, color: c.muted)),
                ],
                if (physio.yearsExperience != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      physio.yearsExperience == 1 ? '1 yr experience' : '${physio.yearsExperience} yrs experience',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.ink),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spinner while [future] loads, an inline error with Retry if it fails,
/// otherwise [builder].
class _Loaded<T> extends StatelessWidget {
  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, T) builder;

  const _Loaded({super.key, required this.future, required this.onRetry, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoBanner(icon: Icons.cloud_off_outlined, tone: BannerTone.warning, text: '${snap.error}'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(context, snap.data as T);
      },
    );
  }
}
