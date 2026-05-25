class GitProject {
  final String name;
  final String path;
  final String? notes;
  final bool existsOnDisk;
  final bool hasGit;
  final String currentBranch;
  final String statusSummary;
  final int ahead;
  final int behind;

  GitProject({
    required this.name,
    required this.path,
    this.notes,
    this.existsOnDisk = false,
    this.hasGit = false,
    this.currentBranch = '',
    this.statusSummary = '',
    this.ahead = 0,
    this.behind = 0,
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
      ahead: json['ahead'] ?? 0,
      behind: json['behind'] ?? 0,
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
        'ahead': ahead,
        'behind': behind,
      };

  bool get isAvailable => existsOnDisk && hasGit;
}
