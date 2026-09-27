abstract class WearableConnectionState {
  const WearableConnectionState();
}

class WearableConnectionInitial extends WearableConnectionState {
  const WearableConnectionInitial();
}

class WearableScanning extends WearableConnectionState {
  const WearableScanning();
}

class WearableConnecting extends WearableConnectionState {
  final String deviceId;
  const WearableConnecting(this.deviceId);
}

class WearableConnected extends WearableConnectionState {
  final String deviceId;
  const WearableConnected(this.deviceId);
}

class WearableConnectionError extends WearableConnectionState {
  final String message;
  const WearableConnectionError(this.message);
}
