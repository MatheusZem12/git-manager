import 'dart:convert';
import 'dart:io';
import '../models/git_project.dart';
import '../models/git_commit.dart';
import '../models/git_file_change.dart';
import '../models/branch_info.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:18765/api';
  final HttpClient _client = HttpClient();

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);
    final request = await _client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(body);
    }
    throw HttpException('${response.statusCode}: $body');
  }

  Future<String> _getText(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);
    final request = await _client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw HttpException('${response.statusCode}: $body');
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(baseUrl + path);
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final respBody = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(respBody);
    }
    throw HttpException('${response.statusCode}: $respBody');
  }

  Future<dynamic> _delete(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);
    final request = await _client.deleteUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(body);
    }
    throw HttpException('${response.statusCode}: $body');
  }

  // Health
  Future<bool> healthCheck() async {
    try {
      final r = await _get('/health');
      return r['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // Projects
  Future<List<GitProject>> getProjects() async {
    final data = await _get('/projects') as List;
    return data.map((e) => GitProject.fromJson(e)).toList();
  }

  Future<GitProject> addProject(String name, String path, {String notes = ''}) async {
    final data = await _post('/projects', {'name': name, 'path': path, 'notes': notes});
    return GitProject.fromJson(data);
  }

  Future<GitProject> updateProject(GitProject project) async {
    final data = await _post('/projects', project.toJson());
    return GitProject.fromJson(data);
  }

  Future<void> deleteProject(String path) async {
    await _delete('/projects', query: {'path': path});
  }

  // Git Status
  Future<Map<String, dynamic>> getStatus(String path) async {
    return await _get('/git/status', query: {'path': path});
  }

  Future<Map<String, dynamic>> getSyncStatus(String path) async {
    return await _get('/git/sync-status', query: {'path': path});
  }

  Future<List<BranchInfo>> getBranches(String path) async {
    final data = await _get('/git/branches', query: {'path': path}) as List;
    return data.map((e) => BranchInfo.fromJson(e)).toList();
  }

  Future<List<String>> getCommits(String path, {int limit = 20}) async {
    final data = await _get('/git/commits', query: {'path': path, 'limit': limit.toString()}) as List;
    return data.cast<String>();
  }

  Future<List<GitCommit>> getCommitGraph(String path, {int limit = 60}) async {
    final data = await _get('/git/graph', query: {'path': path, 'limit': limit.toString()}) as List;
    return data.map((e) => GitCommit.fromJson(e)).toList();
  }

  Future<List<GitFileChange>> getFileChanges(String path) async {
    final data = await _get('/git/changes', query: {'path': path}) as List;
    return data.map((e) => GitFileChange.fromJson(e)).toList();
  }

  Future<List<String>> getTags(String path) async {
    final data = await _get('/git/tags', query: {'path': path}) as List;
    return data.cast<String>();
  }

  Future<List<String>> getStashes(String path) async {
    final data = await _get('/git/stashes', query: {'path': path}) as List;
    return data.cast<String>();
  }

  Future<List<String>> getReflog(String path) async {
    final data = await _get('/git/reflog', query: {'path': path}) as List;
    return data.cast<String>();
  }

  Future<String> getFileContent(String path, String file) async {
    return await _getText('/git/file-content', query: {'path': path, 'file': file});
  }

  Future<String> getFileContentHead(String path, String file) async {
    return await _getText('/git/file-content-head', query: {'path': path, 'file': file});
  }

  Future<String> getFileDiff(String path, String file, {bool staged = false}) async {
    return await _getText('/git/file-diff', query: {'path': path, 'file': file, 'staged': staged.toString()});
  }

  // Git Actions
  Future<String> commit(String path, String message, List<String> files, {String author = '', String email = ''}) async {
    final data = await _post('/git/commit', {
      'path': path,
      'message': message,
      'files': files,
      'authorName': author,
      'authorEmail': email,
    });
    return data['result'];
  }

  Future<String> commitStaged(String path, String message, {String author = '', String email = ''}) async {
    final data = await _post('/git/commit-staged', {
      'path': path,
      'message': message,
      'authorName': author,
      'authorEmail': email,
    });
    return data['result'];
  }

  Future<String> stageFiles(String path, List<String> files) async {
    final data = await _post('/git/stage', {'path': path, 'files': files});
    return data['result'];
  }

  Future<String> unstageFiles(String path, List<String> files) async {
    final data = await _post('/git/unstage', {'path': path, 'files': files});
    return data['result'];
  }

  Future<String> push(String path, {String? username, String? password}) async {
    final data = await _post('/git/push', {'path': path, 'username': username ?? '', 'password': password ?? ''});
    return data['result'];
  }

  Future<String> pull(String path, {String? username, String? password}) async {
    final data = await _post('/git/pull', {'path': path, 'username': username ?? '', 'password': password ?? ''});
    return data['result'];
  }

  Future<String> fetch(String path, {String? username, String? password}) async {
    final data = await _post('/git/fetch', {'path': path, 'username': username ?? '', 'password': password ?? ''});
    return data['result'];
  }

  Future<String> checkout(String path, String branch) async {
    final data = await _post('/git/checkout', {'path': path, 'branch': branch});
    return data['result'];
  }

  Future<String> createBranch(String path, String branch) async {
    final data = await _post('/git/create-branch', {'path': path, 'branch': branch});
    return data['result'];
  }

  Future<String> createTag(String path, String name, String message) async {
    final data = await _post('/git/create-tag', {'path': path, 'name': name, 'message': message});
    return data['result'];
  }

  Future<String> stashSave(String path, String message) async {
    final data = await _post('/git/stash-save', {'path': path, 'message': message});
    return data['result'];
  }

  Future<String> stashPop(String path, int index) async {
    final data = await _post('/git/stash-pop', {'path': path, 'index': index});
    return data['result'];
  }

  Future<String> stashApply(String path, int index) async {
    final data = await _post('/git/stash-apply', {'path': path, 'index': index});
    return data['result'];
  }

  Future<String> reset(String path, String commitId, String mode) async {
    final data = await _post('/git/reset', {'path': path, 'commitId': commitId, 'mode': mode});
    return data['result'];
  }

  Future<String> deleteBranch(String path, String branch) async {
    final data = await _delete('/git/branch', query: {'path': path, 'branch': branch});
    return data['result'];
  }

  Future<String> deleteTag(String path, String name) async {
    final data = await _delete('/git/tag', query: {'path': path, 'name': name});
    return data['result'];
  }

  Future<String> amendCommit(String path, String message, {String author = '', String email = ''}) async {
    final data = await _post('/git/amend', {'path': path, 'message': message, 'authorName': author, 'authorEmail': email});
    return data['result'];
  }

  Future<String> stashDrop(String path, int index) async {
    final data = await _post('/git/stash-drop', {'path': path, 'index': index});
    return data['result'];
  }

  Future<String> merge(String path, String branch) async {
    final data = await _post('/git/merge', {'path': path, 'branch': branch});
    return data['result'];
  }

  Future<String> cherryPick(String path, String commitId) async {
    final data = await _post('/git/cherry-pick', {'path': path, 'commitId': commitId});
    return data['result'];
  }

  Future<String> rebase(String path, String branch) async {
    final data = await _post('/git/rebase', {'path': path, 'branch': branch});
    return data['result'];
  }

  Future<List<Map<String, dynamic>>> getRemotes(String path) async {
    final data = await _get('/git/remotes', query: {'path': path}) as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<String> cloneRepo(String remoteUrl, String localPath, {String? username, String? password}) async {
    final data = await _post('/git/clone', {'remoteUrl': remoteUrl, 'localPath': localPath, 'username': username ?? '', 'password': password ?? ''});
    return data['result'];
  }
}
