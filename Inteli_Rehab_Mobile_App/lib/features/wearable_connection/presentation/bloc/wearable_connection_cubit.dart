import 'wearable_connection_state.dart';

class WearableConnectionCubit {
  WearableConnectionState _state = const WearableConnectionInitial();
  WearableConnectionState get state => _state;

  void emit(WearableConnectionState newState) {
    _state = newState;
  }

  void startScan() {}
  void connectDevice(String deviceId) {}
}
