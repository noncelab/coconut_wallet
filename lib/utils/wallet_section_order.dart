/// Reorders only the slots belonging to a section, preserving the other section's order.
List<int> reorderWalletSection(List<int> order, List<int> sectionIds, int oldIndex, int newIndex) {
  final reordered = List<int>.from(sectionIds);
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
  final sectionSet = sectionIds.toSet();
  var index = 0;
  return [for (final id in order) sectionSet.contains(id) ? reordered[index++] : id];
}
