abstract class RehabSessionEvent {
  const RehabSessionEvent();
}

class StartSessionEvent extends RehabSessionEvent {
  const StartSessionEvent();
}

class PauseSessionEvent extends RehabSessionEvent {
  const PauseSessionEvent();
}

class EndSessionEvent extends RehabSessionEvent {
  const EndSessionEvent();
}
