import 'dart:math';

final _random = Random.secure();

/// RFC 4122 v4 UUID. Client-generated ids let a queued session be retried
/// safely: re-uploading the same rows is a no-op instead of a duplicate.
String uuidV4() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => [for (var i = from; i < to; i++) b[i].toRadixString(16).padLeft(2, '0')].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
