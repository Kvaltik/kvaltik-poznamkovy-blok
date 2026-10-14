class NoteFolder {
  final String id;
  final String name;
  final String? parentId;
  const NoteFolder({required this.id, required this.name, this.parentId});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'parentId': parentId};
  factory NoteFolder.fromJson(Map<String, dynamic> json) => NoteFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    parentId: json['parentId'] as String?,
  );
}

class NoteFlags {
  final String noteId;
  final String? folderId;
  final bool pinned;
  final bool archived;
  final DateTime? deletedAt;
  const NoteFlags({required this.noteId, this.folderId, this.pinned = false, this.archived = false, this.deletedAt});
  bool get isDeleted => deletedAt != null;
  Map<String, dynamic> toJson() => {
    'noteId': noteId,
    'folderId': folderId,
    'pinned': pinned,
    'archived': archived,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory NoteFlags.fromJson(Map<String, dynamic> json) => NoteFlags(
    noteId: json['noteId'] as String,
    folderId: json['folderId'] as String?,
    pinned: json['pinned'] == true,
    archived: json['archived'] == true,
    deletedAt: json['deletedAt'] == null ? null : DateTime.parse(json['deletedAt'] as String),
  );
}
