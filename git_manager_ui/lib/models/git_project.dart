class GitProject {
  final String name;
  final String path;
  final String? notes;
  final bool existsOnDisk;
  final bool hasGit;
  final String currentBranch;
  final String statusSummary;

  GitProject({
    required this.name,
    required this.path,
    this.notes,
    this.existsOnDisk = false,
    this.hasGit = false,
    this.currentBranch = '',
    this.statusSummary = '',
  });

  factory GitProject.fromJson(Map<String, dynamic> json) {
    return GitProject(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      notes: json['notes'],
      existsOnDisk: json['existsOnDisk'] ?? false,
      hasGit: json['hasGit'] ?? false,
      currentBranch: json['currentBranch'] ?? '',
      statusSummary: json['statusSummary'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'notes': notes,
        'existsOnDisk': existsOnDisk,
        'hasGit': hasGit,
        'currentBranch': currentBranch,
        'statusSummary': statusSummary,
      };

  bool get isAvailable => existsOnDisk && hasGit;
}
