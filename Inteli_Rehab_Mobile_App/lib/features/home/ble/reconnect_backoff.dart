/// Delays between automatic reconnect attempts after the band drops
/// unexpectedly: quick at first (a brief signal glitch usually clears in
/// seconds), then easing off so a band that's switched off or out of range
/// doesn't keep the radio busy and drain the battery. After the last delay
/// it gives up until [reset]; the patient can always retry by hand.
class ReconnectBackoff {
  static const delays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 30),
  ];

  int _attempt = 0;

  /// The wait before the next attempt, or null once it has given up.
  Duration? next() => _attempt < delays.length ? delays[_attempt++] : null;

  /// Call on a successful connection (or a manual retry) to start over.
  void reset() => _attempt = 0;

  /// Stop trying without waiting for the delays to run out (patient cancelled).
  void stop() => _attempt = delays.length;
}
