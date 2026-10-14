/// Shared helpers for the recoverable notes trash.
class TrashHelpers {
  static bool isDeleted(Map<String, dynamic> note) => note['deleted_at'] != null;
  static Map<String, dynamic> delete(Map<String, dynamic> note) => {
    ...note,
    'deleted_at': DateTime.now().toUtc().toIso8601String(),
  };
  static Map<String, dynamic> restore(Map<String, dynamic> note) => {
    ...note,
    'deleted_at': null,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}
