class GitCommit {
  final String id;
  final String shortId;
  final String message;
  final String authorName;
  final String authorEmail;
  final DateTime commitTime;
  final List<String> parentIds;
  final List<String> branchNames;
  final bool head;

  GitCommit({
    required this.id,
    required this.shortId,
    required this.message,
    required this.authorName,
    required this.authorEmail,
    required this.commitTime,
    required this.parentIds,
    required this.branchNames,
    this.head = false,
  });

  factory GitCommit.fromJson(Map<String, dynamic> json) {
    DateTime commitTime;
    final ct = json['commitTime'];
    if (ct is String) {
      commitTime = DateTime.parse(ct);
    } else if (ct is num) {
      // Jackson/Javalin serializa Instant como segundos (com possível fração)
      final seconds = ct.toInt();
      commitTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } else {
      commitTime = DateTime.now();
    }

    // Helper para garantir String e converter listas de forma segura
    String _str(dynamic v) => v?.toString() ?? '';
    List<String> _strList(dynamic v) {
      if (v is List) {
        return v.map((e) => e?.toString() ?? '').toList();
      }
      return [];
    }
    bool _bool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      return false;
    }

    return GitCommit(
      id: _str(json['id']),
      shortId: _str(json['shortId']),
      message: _str(json['message']),
      authorName: _str(json['authorName']),
      authorEmail: _str(json['authorEmail']),
      commitTime: commitTime,
      parentIds: _strList(json['parentIds']),
      branchNames: _strList(json['branchNames']),
      head: _bool(json['head']),
    );
  }
}
