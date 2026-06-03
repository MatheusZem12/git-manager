import 'package:git_manager_ui/generated/l10n/app_localizations.dart';

class GitFileChange {
  final String path;
  final String? oldPath;
  final String type;
  bool staged;

  GitFileChange({
    required this.path,
    this.oldPath,
    required this.type,
    this.staged = false,
  });

  factory GitFileChange.fromJson(Map<String, dynamic> json) {
    return GitFileChange(
      path: json['path'] ?? '',
      oldPath: json['oldPath'],
      type: json['type'] ?? 'UNTRACKED',
      staged: json['staged'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'oldPath': oldPath,
        'type': type,
        'staged': staged,
      };

  String labelText(AppLocalizations l10n) {
    switch (type) {
      case 'ADDED':
        return l10n.added;
      case 'MODIFIED':
        return l10n.modified;
      case 'DELETED':
        return l10n.deleted;
      case 'RENOMEADO':
        return l10n.renamed;
      case 'CONFLICTING':
        return l10n.conflicting;
      case 'UNTRACKED':
      default:
        return l10n.untracked;
    }
  }

  String get label {
    switch (type) {
      case 'ADDED':
        return 'Novo';
      case 'MODIFIED':
        return 'Modificado';
      case 'DELETED':
        return 'Deletado';
      case 'RENOMEADO':
        return 'Renomeado';
      case 'CONFLICTING':
        return 'Conflito';
      case 'UNTRACKED':
      default:
        return 'Não rastreado';
    }
  }

  int get colorValue {
    switch (type) {
      case 'ADDED':
        return 0xFF2EA043;
      case 'MODIFIED':
        return 0xFFD7BA7D;
      case 'DELETED':
        return 0xFFF85149;
      case 'RENOMEADO':
        return 0xFF79C0FF;
      case 'CONFLICTING':
        return 0xFFF85149;
      case 'UNTRACKED':
      default:
        return 0xFFA0A0A0;
    }
  }
}
