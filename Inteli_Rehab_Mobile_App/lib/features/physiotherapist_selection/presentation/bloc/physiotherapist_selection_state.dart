abstract class PhysiotherapistSelectionState {
  const PhysiotherapistSelectionState();
}

class PhysiotherapistSelectionInitial extends PhysiotherapistSelectionState {
  const PhysiotherapistSelectionInitial();
}

class PhysiotherapistSelectionLoading extends PhysiotherapistSelectionState {
  const PhysiotherapistSelectionLoading();
}

class PhysiotherapistSelectionLoaded extends PhysiotherapistSelectionState {
  final List<dynamic> physiotherapists;
  const PhysiotherapistSelectionLoaded(this.physiotherapists);
}

class PhysiotherapistSelectionError extends PhysiotherapistSelectionState {
  final String message;
  const PhysiotherapistSelectionError(this.message);
}
