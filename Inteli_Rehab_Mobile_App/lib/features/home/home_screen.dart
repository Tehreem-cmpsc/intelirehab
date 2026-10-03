import 'package:flutter/material.dart';

import '../../core/models/patient_profile.dart';
import '../../core/network/load_guard.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/radial_progress.dart';
import '../../core/widgets/ui_kit.dart';
import '../exercises/exercises_repository.dart';
import '../exercises/session_journal.dart';
import 'bluetooth_rationale.dart';
import 'home_models.dart';
import 'home_repository.dart';
import 'wearable_connection_controller.dart';
import 'widgets/digital_twin_card.dart';
import 'widgets/rom_target_bar.dart';
import 'widgets/wearable_status_chip.dart';

/// Daily entry point (Rule 1): orientation plus a single clear next
/// action, not a live monitoring surface — that's the exercise session
/// screen's job, not this one's.
class HomeScreen extends StatefulWidget {
  final PatientProfile profile;
  final WearableConnectionController connection;
  final VoidCallback onGoToExercises;

  /// Fires when the tab is shown again, the app returns to the foreground or a
  /// session finishes: the dashboard reloads quietly, keeping what's on screen.
  final Listenable? refreshSignal;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.connection,
    required this.onGoToExercises,
    this.refreshSignal,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = HomeRepository();
  late Future<HomeSnapshot> _snapshot = _track(_load());
  int _pendingUploads = 0;

  HomeSnapshot? _last; // what's on screen, kept while a quiet reload runs
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

  /// Remembers the latest good snapshot. A quiet reload that fails keeps
  /// showing it instead of swapping a working dashboard for an error screen.
  Future<HomeSnapshot> _track(Future<HomeSnapshot> load, {bool quiet = false}) => load.then(
        (s) {
          _last = s;
          _loadedAt = DateTime.now();
          return s;
        },
        onError: (Object e, StackTrace st) {
          if (quiet && _last != null) return _last!;
          throw e;
        },
      );

  void _quietReload() {
    if (!mounted) return;
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at) < const Duration(seconds: 5)) return; // just loaded
    setState(() => _snapshot = _track(_load(), quiet: true));
  }

  /// Uploads anything saved offline first (Rule 26), so the dashboard
  /// reflects it; a failed sync never blocks the dashboard itself.
  Future<HomeSnapshot> _load() async {
    try {
      await SessionJournal.syncPending(widget.profile.id, ExercisesRepository()).timeout(loadTimeout);
    } catch (_) {
      // Still offline — the count below says so.
    }
    final pending = await SessionJournal.pendingCount(widget.profile.id);
    if (mounted) setState(() => _pendingUploads = pending);
    return _repo.load(widget.profile.id).guarded();
  }

  void _reload() => setState(() => _snapshot = _track(_load()));

  String get _firstName {
    final parts = widget.profile.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? widget.profile.name : parts.first;
  }

  String get _greeting {
    final hour = TimeOfDay.now().hour;
    final part = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : 'evening');
    return 'Good $part, $_firstName';
  }

  static String _today() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<HomeSnapshot>(
        future: _snapshot,
        initialData: _last,
        builder: (context, snap) {
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _snapshot;
              } catch (_) {
                // The error state below already shows it.
              }
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(
                  greeting: _greeting,
                  date: _today(),
                  motivation: snap.data?.motivation,
                  connection: widget.connection,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: _body(context, snap),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, AsyncSnapshot<HomeSnapshot> snap) {
    if (snap.hasError) {
      return SizedBox(
        height: 320,
        child: MessageState(
          icon: Icons.cloud_off_outlined,
          isError: true,
          title: "Couldn't load your dashboard",
          text: friendlyError(snap.error!),
          actionLabel: 'Try again',
          onAction: _reload,
        ),
      );
    }
    if (!snap.hasData) {
      return const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()));
    }
    final data = snap.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pendingUploads > 0) ...[
          _PendingUploadsCard(count: _pendingUploads, onRetry: _reload),
          const SizedBox(height: 14),
        ],
        _TodaysPlanCard(plan: data.plan, onGoToExercises: widget.onGoToExercises),
        const SizedBox(height: 14),
        DigitalTwinCard(
          lastSession: data.lastSession,
          baseline: data.baseline,
          sessionsThisWeek: data.sessionsThisWeek,
          currentStreak: data.currentStreak,
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: widget.connection,
          builder: (context, _) => widget.connection.isConnected
              ? _LastSessionCard(session: data.lastSession)
              : _DisconnectedCard(connection: widget.connection),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final String date;
  final String? motivation;
  final WearableConnectionController connection;

  const _Header({required this.greeting, required this.date, required this.motivation, required this.connection});

  @override
  Widget build(BuildContext context) {
    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(date, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75))),
              ),
              AnimatedBuilder(
                animation: connection,
                builder: (context, _) => WearableStatusChip(
                  state: connection.state,
                  batteryPercent: connection.batteryPercent,
                  onDark: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              greeting,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15, letterSpacing: -0.4),
            ),
          ),
          if (motivation != null) ...[
            const SizedBox(height: 8),
            Text(motivation!, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85), height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _PendingUploadsCard extends StatelessWidget {
  final int count;
  final VoidCallback onRetry;
  const _PendingUploadsCard({required this.count, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      color: c.accent.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count session${count == 1 ? '' : 's'} saved on this phone — '
              "${count == 1 ? 'it' : 'they'}'ll upload when you're online.",
              style: TextStyle(fontSize: 13, color: c.ink, height: 1.35),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TodaysPlanCard extends StatelessWidget {
  final TodaysPlan? plan;
  final VoidCallback onGoToExercises;
  const _TodaysPlanCard({required this.plan, required this.onGoToExercises});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (plan == null) {
      return AppCard(
        child: Row(
          children: [
            IconBadge(Icons.event_note_outlined, color: c.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                "Your physiotherapist hasn't assigned a plan yet. You'll see it here as soon as they do.",
                style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final total = plan!.exercises.length;
    final remaining = plan!.remaining;
    final done = total - remaining;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                label: '$done of $total exercises done today',
                excludeSemantics: true,
                child: RadialProgress(
                  value: total == 0 ? 0 : done / total,
                  size: 68,
                  stroke: 7,
                  color: remaining == 0 ? c.success : c.primary,
                  center:
                      Text('$done/$total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY’S PLAN',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(plan!.planName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      remaining == 0
                          ? 'All done for today — nice work.'
                          : '$remaining exercise${remaining == 1 ? '' : 's'} remaining',
                      style: TextStyle(fontSize: 13, color: remaining == 0 ? c.success : c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onGoToExercises,
            icon: const Icon(Icons.fitness_center, size: 18),
            label: const Text('Go to Exercises'),
          ),
        ],
      ),
    );
  }
}

class _LastSessionCard extends StatelessWidget {
  final LastSessionSnapshot? session;
  const _LastSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (session == null) {
      return AppCard(
        child: Row(
          children: [
            IconBadge(Icons.history, color: c.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Complete your first exercise session to see it here.',
                style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final s = session!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.history, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last session', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                    Text(s.exerciseName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
                  ],
                ),
              ),
              PillTag(_formatDate(s.performedAt), color: c.muted),
            ],
          ),
          const SizedBox(height: 16),
          RomTargetBar(achieved: s.rom, target: s.romTarget),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.repeat, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Text('${s.reps} reps completed', style: TextStyle(fontSize: 12.5, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}

/// Ambient, not a popup (Rule 17) — sits in the Last Session card's spot
/// so it's informative rather than intrusive, with a visible Reconnect
/// (Rule 33) that explains Bluetooth first (Rule 23).
class _DisconnectedCard extends StatelessWidget {
  final WearableConnectionController connection;
  const _DisconnectedCard({required this.connection});

  Future<void> _reconnect(BuildContext context) async {
    if (!await BluetoothRationale.ensure(context)) return;
    await connection.reconnect();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final searching =
        connection.state == WearableConnState.searching || connection.state == WearableConnState.calibrating;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(Icons.bluetooth_disabled_rounded, color: c.alert),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wearable not connected',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
                    const SizedBox(height: 2),
                    Text(
                      searching ? 'Looking for your band…' : 'Switch your band on and keep it nearby.',
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: searching ? null : () => _reconnect(context),
            icon: searching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bluetooth_searching, size: 18),
            label: Text(searching ? 'Searching…' : 'Reconnect'),
          ),
        ],
      ),
    );
  }
}
