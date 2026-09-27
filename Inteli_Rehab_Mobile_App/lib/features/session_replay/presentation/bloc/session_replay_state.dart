abstract class SessionReplayState {
  const SessionReplayState();
}

class SessionReplayInitial extends SessionReplayState {
  const SessionReplayInitial();
}

class SessionReplayLoading extends SessionReplayState {
  const SessionReplayLoading();
}

class SessionReplayPlaying extends SessionReplayState {
  final int currentFrame;
  const SessionReplayPlaying(this.currentFrame);
}

class SessionReplayPaused extends SessionReplayState {
  final int currentFrame;
  const SessionReplayPaused(this.currentFrame);
}

class SessionReplayError extends SessionReplayState {
  final String message;
  const SessionReplayError(this.message);
}
