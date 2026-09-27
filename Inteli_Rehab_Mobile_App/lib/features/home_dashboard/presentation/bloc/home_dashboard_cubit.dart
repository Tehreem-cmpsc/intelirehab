import 'home_dashboard_state.dart';

class HomeDashboardCubit {
  HomeDashboardState _state = const HomeDashboardInitial();
  HomeDashboardState get state => _state;

  void emit(HomeDashboardState newState) {
    _state = newState;
  }

  void loadDashboard() {}
}
