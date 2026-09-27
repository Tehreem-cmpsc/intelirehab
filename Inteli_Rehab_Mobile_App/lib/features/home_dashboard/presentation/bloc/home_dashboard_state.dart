abstract class HomeDashboardState {
  const HomeDashboardState();
}

class HomeDashboardInitial extends HomeDashboardState {
  const HomeDashboardInitial();
}

class HomeDashboardLoading extends HomeDashboardState {
  const HomeDashboardLoading();
}

class HomeDashboardLoaded extends HomeDashboardState {
  final dynamic dashboardData;
  const HomeDashboardLoaded(this.dashboardData);
}

class HomeDashboardError extends HomeDashboardState {
  final String message;
  const HomeDashboardError(this.message);
}
