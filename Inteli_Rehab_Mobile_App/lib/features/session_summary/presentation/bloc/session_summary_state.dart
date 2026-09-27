abstract class SessionSummaryState {
  const SessionSummaryState();
}

class SessionSummaryInitial extends SessionSummaryState {
  const SessionSummaryInitial();
}

class SessionSummaryLoading extends SessionSummaryState {
  const SessionSummaryLoading();
}

class SessionSummaryLoaded extends SessionSummaryState {
  final dynamic summary;
  const SessionSummaryLoaded(this.summary);
}

class SessionSummaryError extends SessionSummaryState {
  final String message;
  const SessionSummaryError(this.message);
}
