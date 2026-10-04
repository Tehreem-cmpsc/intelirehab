import 'package:flutter/material.dart';

import '../../core/network/load_guard.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import 'progress_models.dart';
import 'progress_repository.dart';
import 'session_history_screen.dart';
import 'widgets/badge_tile.dart';
import 'widgets/physio_warning_card.dart';
import 'widgets/rom_trend_chart.dart';

/// UC-11 View Progress: ROM trend, adherence, session-history entry point,
/// achievements. Recovery data first, badges second (Rule 8).
class ProgressScreen extends StatefulWidget {
  final String patientId;

  /// See HomeScreen.refreshSignal.
  final Listenable? refreshSignal;
  const ProgressScreen({super.key, required this.patientId, this.refreshSignal});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _repo = ProgressRepository();
  late Future<ProgressData> _future = _track(_load());

  ProgressData? _last;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_quietReload);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_quietReload);
    super.dispose();
  }

  Future<ProgressData> _load() => _repo.load(widget.patientId).guarded();

  Future<ProgressData> _track(Future<ProgressData> load, {bool quiet = false}) => load.then(
        (d) {
          _last = d;
          _loadedAt = DateTime.now();
          return d;
        },
        onError: (Object e, StackTrace st) {
          if (quiet && _last != null) return _last!;
          throw e;
        },
      );

  void _reload() => setState(() => _future = _track(_load()));

  void _quietReload() {
    if (!mounted) return;
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at) < const Duration(seconds: 5)) return;
    setState(() => _future = _track(_load(), quiet: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: FutureBuilder<ProgressData>(
        future: _future,
        initialData: _last,
        builder: (context, snap) {
          if (snap.hasError) {
            return MessageState(
              icon: Icons.cloud_off_outlined,
              isError: true,
              title: "Couldn't load your progress",
              text: friendlyError(snap.error!),
              actionLabel: 'Try again',
              onAction: _reload,
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          if (data.isEmpty) {
            final empty = MessageState(
              icon: Icons.insights_outlined,
              title: 'Complete your first session to see your progress here.',
              text: 'Your ROM trend, sessions and achievements will build up as you go.',
              actionLabel: 'Refresh',
              onAction: _reload,
            );
            // A physiotherapist's message matters even before the first session.
            if (data.warning == null) return empty;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: PhysioWarningCard(message: data.warning!),
                ),
                Expanded(child: empty),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (data.warning != null) ...[
                  PhysioWarningCard(message: data.warning!),
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.favorite_outline,
                        value: '${data.summary.recoveryPercent}%',
                        label: 'Recovery',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: Icons.check_circle_outline,
                        value: '${data.summary.sessionsCompleted}',
                        label: 'Sessions',
                        color: c.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: Icons.event_available_outlined,
                        value: '${data.summary.adherencePercent}%',
                        label: 'Adherence',
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionLabel('ROM trend'),
                AppCard(child: RomTrendChart(points: data.romTrend)),
                if (data.badges.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const SectionLabel('Achievements'),
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.badges.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) => BadgeTile(badge: data.badges[i]),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                AppCard(
                  semanticLabel: 'Session history, ${data.history.length} sessions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SessionHistoryScreen(history: data.history)),
                  ),
                  child: Row(
                    children: [
                      const IconBadge(Icons.history),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Session History',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
                            Text(
                              '${data.history.length} session${data.history.length == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 12.5, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.muted),
                    ],
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
