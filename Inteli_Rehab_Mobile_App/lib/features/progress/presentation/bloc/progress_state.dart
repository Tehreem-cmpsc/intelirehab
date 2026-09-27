abstract class ProgressState {
  const ProgressState();
}

class ProgressInitial extends ProgressState {
  const ProgressInitial();
}

class ProgressLoading extends ProgressState {
  const ProgressLoading();
}

class ProgressLoaded extends ProgressState {
  final dynamic progressData;
  const ProgressLoaded(this.progressData);
}

class ProgressError extends ProgressState {
  final String message;
  const ProgressError(this.message);
}
