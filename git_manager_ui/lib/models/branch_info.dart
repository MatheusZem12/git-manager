class BranchInfo {
  final String name;
  final String commitId;
  final bool remote;
  final bool head;

  BranchInfo({
    required this.name,
    required this.commitId,
    this.remote = false,
    this.head = false,
  });

  factory BranchInfo.fromJson(Map<String, dynamic> json) {
    return BranchInfo(
      name: json['name'] ?? '',
      commitId: json['commitId'] ?? '',
      remote: json['remote'] ?? false,
      head: json['head'] ?? false,
    );
  }
}
