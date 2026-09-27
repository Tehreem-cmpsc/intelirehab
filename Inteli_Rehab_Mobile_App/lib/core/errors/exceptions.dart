class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server Exception']);
}

class BleException implements Exception {
  final String message;
  const BleException([this.message = 'BLE Exception']);
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache Exception']);
}
