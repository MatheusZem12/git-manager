// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Git Manager';

  @override
  String get addRepo => 'Add Repository';

  @override
  String get removeRepo => 'Remove Repository';

  @override
  String get repoName => 'Project name';

  @override
  String get absolutePath => 'Absolute path';

  @override
  String get browse => 'Browse';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get refresh => 'Refresh';

  @override
  String get searchRepo => 'Search repository...';

  @override
  String get total => 'TOTAL';

  @override
  String get ok => 'OK';

  @override
  String get alt => 'ALT';

  @override
  String get unavailable => 'UNAVAIL.';

  @override
  String get withChanges => 'CHANGED';

  @override
  String get noRepos => 'No repositories';

  @override
  String get noReposHint => 'Use the button below to register a git directory.';

  @override
  String get selectRepo => 'Select a repository';

  @override
  String get selectRepoHint =>
      'Click an item in the list to view details and run Git operations.';

  @override
  String get errorLoadingProjects => 'Error loading projects';

  @override
  String get overview => 'Overview';

  @override
  String get commit => 'Commit';

  @override
  String get history => 'History';

  @override
  String get tags => 'Tags';

  @override
  String get stash => 'Stash';

  @override
  String get currentBranch => 'Current Branch';

  @override
  String get head => 'HEAD';

  @override
  String get switchBranch => 'Switch Branch';

  @override
  String get selectBranch => 'Select branch';

  @override
  String get checkout => 'Checkout';

  @override
  String get newBranch => 'New Branch';

  @override
  String get branchName => 'Branch name';

  @override
  String get sync => 'Sync';

  @override
  String get output => 'Output';

  @override
  String get clear => 'Clear';

  @override
  String get recentCommits => 'Recent Commits';

  @override
  String get noCommits => 'No commits';

  @override
  String get graphTimeline => 'Graph Timeline';

  @override
  String get newTag => 'New Tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get tagMessage => 'Tag message';

  @override
  String get tagMessageOptional => 'Message (optional)';

  @override
  String get noTags => 'No tags';

  @override
  String get saveStash => 'Save Stash';

  @override
  String get stashMessageOptional => 'Message (optional)';

  @override
  String get apply => 'Apply';

  @override
  String get pop => 'Pop';

  @override
  String get noStashes => 'No stashes';

  @override
  String get credentials => 'Credentials';

  @override
  String get usernameOptional => 'User (optional)';

  @override
  String get passwordOptional => 'Password/Token (optional)';

  @override
  String get execute => 'Execute';

  @override
  String get confirm => 'Confirm';

  @override
  String get errorLoadingData => 'Error loading data';

  @override
  String get executing => 'Executing...';

  @override
  String get error => 'Error';

  @override
  String get commitMessageEmpty => 'Commit message cannot be empty.';

  @override
  String get noFilesSelected => 'No files selected for commit.';

  @override
  String get committing => 'Committing...';

  @override
  String get noPendingChanges => 'No pending changes';

  @override
  String get filterByName => 'Filter by name...';

  @override
  String get all => 'All';

  @override
  String get none => 'None';

  @override
  String get commitMessageHint => 'Commit message...';

  @override
  String get selectFileToView => 'Select a file to view';

  @override
  String get diff => 'Diff';

  @override
  String get file => 'File';

  @override
  String get before => 'BEFORE (HEAD)';

  @override
  String get after => 'AFTER (Current)';

  @override
  String get retry => 'Try again';

  @override
  String get noCommitsToDisplay => 'No commits to display';

  @override
  String get projectPath => 'Project path';

  @override
  String get removeRepoConfirm =>
      'This only removes the project from the list, it does not delete any files.';

  @override
  String get noRepo => 'No repositories';

  @override
  String get noRepoHint => 'Use the button below to register a git directory.';

  @override
  String get userOptional => 'User (optional)';

  @override
  String get graphicTimeline => 'Graph Timeline';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomReset => 'Reset zoom';

  @override
  String get noChanges => 'No pending changes';

  @override
  String get filterFiles => 'Filter files...';

  @override
  String get commitMessage => 'Commit message...';

  @override
  String get selectFile => 'Select a file to view';

  @override
  String get noCommitToShow => 'No commits to display';

  @override
  String get noStash => 'No stashes saved';

  @override
  String get added => 'Added';

  @override
  String get modified => 'Modified';

  @override
  String get deleted => 'Deleted';

  @override
  String get renamed => 'Renamed';

  @override
  String get conflicting => 'Conflict';

  @override
  String get untracked => 'Untracked';

  @override
  String get projectName => 'Project name';

  @override
  String get groupName => 'Group name';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get push => 'Push';

  @override
  String get pull => 'Pull';

  @override
  String get fetch => 'Fetch';

  @override
  String get newItem => 'New';

  @override
  String get creatingCommit => 'Creating commit...';

  @override
  String get reset => 'Reset';

  @override
  String get resetMode => 'Choose reset mode:';

  @override
  String get resetSoft => 'Soft (HEAD)';

  @override
  String get resetMixed => 'Mixed (default)';

  @override
  String get resetHard => 'Hard ⚠️';

  @override
  String get remotes => 'Remotes';

  @override
  String get noRemotes => 'No remotes configured';

  @override
  String get reflog => 'Reflog';

  @override
  String get deleteBranch => 'Delete Branch';

  @override
  String get merge => 'Merge';

  @override
  String get amend => 'Amend';

  @override
  String get amendCommit => 'Amend Commit';

  @override
  String get newMessageOptional => 'New message (optional)';

  @override
  String get cherryPick => 'Cherry-pick';

  @override
  String get commitHash => 'Commit hash';

  @override
  String get rebase => 'Rebase';

  @override
  String get noReflog => 'No reflog entries';

  @override
  String get close => 'Close';

  @override
  String get infoTooltipPush =>
      'Sends your local commits to the remote server (GitHub, GitLab, etc.)';

  @override
  String get infoTooltipPull =>
      'Downloads updates from the server and automatically merges into your current branch';

  @override
  String get infoTooltipFetch =>
      'Downloads information from the server without modifying your local files';

  @override
  String get infoTooltipMerge =>
      'Combines another branch into the current branch, merging both works';

  @override
  String get infoTooltipCheckout =>
      'Switches to the selected branch, changing the project files';

  @override
  String get infoTooltipNewBranch =>
      'Creates a new branch from the current point, ideal for new features';

  @override
  String get infoTooltipNewTag =>
      'Creates a new tag to mark a specific point in history';

  @override
  String get infoTooltipDeleteBranch =>
      'Permanently removes the selected branch';

  @override
  String get infoTooltipReset =>
      'Reverts the repository to a previous state. Caution: may delete changes!';

  @override
  String get infoTooltipStashSave =>
      'Temporarily stores your changes without committing, cleaning the workspace';

  @override
  String get infoTooltipStashApply =>
      'Applies the stored stash changes without removing them';

  @override
  String get infoTooltipStashPop =>
      'Applies and removes the most recent stash changes';

  @override
  String get infoTooltipCherryPick =>
      'Copies a specific commit from another branch into the current branch';

  @override
  String get infoTooltipRebase =>
      'Rewrites history by moving your commits on top of another branch';

  @override
  String get infoTooltipAmend =>
      'Fixes the last commit (message or files) without creating a new one';

  @override
  String get infoTooltipCreateTag =>
      'Creates a marker (version) at a specific point in history';

  @override
  String get infoTooltipDeleteTag => 'Removes an existing tag';

  @override
  String get infoTooltipRemotes =>
      'Shows the remote servers configured for this repository';

  @override
  String get repoStateClean => 'All clean — no pending changes';

  @override
  String get repoStateDirty => 'There are unsaved changes';

  @override
  String get repoStateAhead => 'commits ahead of remote';

  @override
  String get repoStateBehind => 'commits behind remote';

  @override
  String get confirmDeleteBranch => 'Are you sure you want to delete branch';

  @override
  String get confirmDeleteTag => 'Are you sure you want to delete tag';

  @override
  String get cloneRepo => 'Clone Repository';

  @override
  String get cloneUrl => 'Repository URL';

  @override
  String get cloneDestination => 'Destination folder';

  @override
  String get settings => 'Settings';

  @override
  String get copyHash => 'Copy hash';

  @override
  String get viewDiff => 'View diff';

  @override
  String get revertCommit => 'Revert commit';

  @override
  String get searchCommits => 'Search commits...';

  @override
  String get moreActions => 'More actions';

  @override
  String get staged => 'Staged';

  @override
  String get unstaged => 'Unstaged';

  @override
  String get back => 'Back';

  @override
  String get deleteRepoTitle => 'Remove repository';

  @override
  String deleteRepoMessage(Object name) {
    return 'You are removing \'$name\' from the list. Files on disk will NOT be deleted.';
  }

  @override
  String get statusClean => 'Status: clean';

  @override
  String get statusDirty => 'Status: pending changes';

  @override
  String get nothingToCommit => 'Nothing to commit';

  @override
  String get uncommittedChanges => 'uncommitted changes';

  @override
  String get aheadBy => 'ahead';

  @override
  String get behindBy => 'behind';

  @override
  String get diverged => 'diverged';

  @override
  String get syncStatus => 'Sync status';

  @override
  String get lastFetch => 'Last fetch';

  @override
  String get noRemoteConfigured => 'No remote configured';

  @override
  String get openInTerminal => 'Open in terminal';

  @override
  String get exploreChanges => 'Explore changes';

  @override
  String get exploreChangesHint => 'Click a file to see what changed';

  @override
  String get viewBlame => 'View blame';

  @override
  String get cleanUntracked => 'Clean untracked';

  @override
  String get forcePush => 'Force push';

  @override
  String get prune => 'Prune refs';

  @override
  String get submoduleUpdate => 'Update submodules';

  @override
  String get editGitIgnore => 'Edit .gitignore';

  @override
  String get userName => 'Git username';

  @override
  String get userEmail => 'Git email';

  @override
  String get gitConfig => 'Git Settings';

  @override
  String get showGitCommandOutput => 'Show command output';

  @override
  String get confirmDangerousActions => 'Confirm dangerous actions';

  @override
  String get loading => 'Loading...';

  @override
  String get empty => 'Empty';

  @override
  String get operationSuccess => 'Operation completed successfully';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get copied => 'Copied!';

  @override
  String get details => 'Details';

  @override
  String get preview => 'Preview';

  @override
  String get actions => 'Actions';

  @override
  String get commitDetails => 'Commit details';

  @override
  String get parentCommits => 'Parent commits';

  @override
  String get changedFiles => 'Changed files';

  @override
  String get openFolder => 'Open folder';

  @override
  String get repositoryUrl => 'Repository URL';

  @override
  String get openRepositoryUrl => 'Open URL in browser';

  @override
  String get noDescription => 'No description';

  @override
  String get noCommitsToShow => 'No commits to show';

  @override
  String get warning => 'Warning';

  @override
  String get compactMode => 'Compact mode';

  @override
  String get comfortableMode => 'Comfortable mode';

  @override
  String get graphCompactView => 'Compact view';

  @override
  String get graphDetailedView => 'Detailed view';

  @override
  String get commitDate => 'Date';

  @override
  String get commitAuthor => 'Author';

  @override
  String get stage => 'Stage';

  @override
  String get unstage => 'Unstage';

  @override
  String get stageSelected => 'Stage selected';

  @override
  String get unstageSelected => 'Unstage selected';

  @override
  String get stagedFiles => 'Staged files';

  @override
  String get unstagedFiles => 'Unstaged files';

  @override
  String get nothingToStage => 'No files selected to stage';

  @override
  String get nothingToUnstage => 'No files selected to unstage';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String discardChangesConfirm(String file) {
    return 'Are you sure you want to discard changes in \'$file\'?';
  }

  @override
  String get openFile => 'Open file';

  @override
  String get delete => 'Delete';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String deleteTagConfirm(String name) {
    return 'Do you really want to delete the tag \'$name\'?';
  }

  @override
  String get commits => 'commits';

  @override
  String get branchCommits => 'Branch commits';

  @override
  String get allBranches => 'All branches';

  @override
  String get nothingToPush => 'Nothing to push';

  @override
  String get nothingToPull => 'Nothing to pull';

  @override
  String get upToDate => 'Up to date';

  @override
  String get copy => 'Copy';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get notificationSuccess => 'Success';

  @override
  String get notificationError => 'Error';

  @override
  String get notificationWarning => 'Warning';

  @override
  String get notificationInfo => 'Info';

  @override
  String get repoAddedSuccess => 'Repositories added successfully.';

  @override
  String get commitButtonTooltipNoStagedFiles =>
      'Add files to stage to be able to commit';
}
