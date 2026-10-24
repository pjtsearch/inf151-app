import 'goal.dart';

enum GoalSortBy {
  endDate('End date'),
  creationDate('Creation date'),
  progress('Progress');

  const GoalSortBy(this.label);
  final String label;
}

class GoalSort {
  const GoalSort({this.by = GoalSortBy.endDate, this.descending = false});

  final GoalSortBy by;
  final bool descending;

  String get ascendingDescription => switch (by) {
    GoalSortBy.endDate => 'Earliest first',
    GoalSortBy.creationDate => 'Oldest first',
    GoalSortBy.progress => 'Lowest progress first',
  };

  String get descendingDescription => switch (by) {
    GoalSortBy.endDate => 'Latest first',
    GoalSortBy.creationDate => 'Newest first',
    GoalSortBy.progress => 'Highest progress first',
  };

  int compare(Goal a, Goal b) {
    var result = switch (by) {
      GoalSortBy.endDate => a.endDate.compareTo(b.endDate),
      GoalSortBy.creationDate => a.createdAt.compareTo(b.createdAt),
      GoalSortBy.progress => a.progress.compareTo(b.progress),
    };
    if (result == 0) result = a.createdAt.compareTo(b.createdAt);
    if (result == 0) result = a.id.compareTo(b.id);
    return descending ? -result : result;
  }

  Map<String, Object> toJson() => {'by': by.name, 'descending': descending};

  factory GoalSort.fromJson(Map<String, dynamic> json) => GoalSort(
    by:
        GoalSortBy.values.where((by) => by.name == json['by']).firstOrNull ??
        GoalSortBy.endDate,
    descending: json['descending'] == true,
  );
}
