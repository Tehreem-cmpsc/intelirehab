import 'progress_state.dart';

class ProgressCubit {
  ProgressState _state = const ProgressInitial();
  ProgressState get state => _state;

  void emit(ProgressState newState) {
    _state = newState;
  }

  void fetchProgress() {}
}
