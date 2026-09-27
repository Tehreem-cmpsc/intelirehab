import 'physiotherapist_selection_state.dart';

class PhysiotherapistSelectionCubit {
  PhysiotherapistSelectionState _state = const PhysiotherapistSelectionInitial();
  PhysiotherapistSelectionState get state => _state;

  void emit(PhysiotherapistSelectionState newState) {
    _state = newState;
  }

  void fetchPhysiotherapists(String clinicId) {}
}
