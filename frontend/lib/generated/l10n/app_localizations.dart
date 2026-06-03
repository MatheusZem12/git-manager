import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt, this message translates to:
  /// **'Git Manager'**
  String get appTitle;

  /// No description provided for @addRepo.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Repositório'**
  String get addRepo;

  /// No description provided for @removeRepo.
  ///
  /// In pt, this message translates to:
  /// **'Remover Repositório'**
  String get removeRepo;

  /// No description provided for @repoName.
  ///
  /// In pt, this message translates to:
  /// **'Nome do projeto'**
  String get repoName;

  /// No description provided for @absolutePath.
  ///
  /// In pt, this message translates to:
  /// **'Caminho absoluto'**
  String get absolutePath;

  /// No description provided for @browse.
  ///
  /// In pt, this message translates to:
  /// **'Procurar'**
  String get browse;

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get remove;

  /// No description provided for @refresh.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get refresh;

  /// No description provided for @searchRepo.
  ///
  /// In pt, this message translates to:
  /// **'Buscar repositório...'**
  String get searchRepo;

  /// No description provided for @total.
  ///
  /// In pt, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @ok.
  ///
  /// In pt, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @alt.
  ///
  /// In pt, this message translates to:
  /// **'ALT'**
  String get alt;

  /// No description provided for @unavailable.
  ///
  /// In pt, this message translates to:
  /// **'INDISP.'**
  String get unavailable;

  /// No description provided for @withChanges.
  ///
  /// In pt, this message translates to:
  /// **'ALTERAÇÕES'**
  String get withChanges;

  /// No description provided for @noRepos.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum repositório'**
  String get noRepos;

  /// No description provided for @noReposHint.
  ///
  /// In pt, this message translates to:
  /// **'Use o botão abaixo para cadastrar um diretório git.'**
  String get noReposHint;

  /// No description provided for @selectRepo.
  ///
  /// In pt, this message translates to:
  /// **'Selecione um repositório'**
  String get selectRepo;

  /// No description provided for @selectRepoHint.
  ///
  /// In pt, this message translates to:
  /// **'Clique em um item da lista para ver detalhes e executar operações Git.'**
  String get selectRepoHint;

  /// No description provided for @errorLoadingProjects.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar projetos'**
  String get errorLoadingProjects;

  /// No description provided for @overview.
  ///
  /// In pt, this message translates to:
  /// **'Visão Geral'**
  String get overview;

  /// No description provided for @commit.
  ///
  /// In pt, this message translates to:
  /// **'Commit'**
  String get commit;

  /// No description provided for @history.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get history;

  /// No description provided for @tags.
  ///
  /// In pt, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @stash.
  ///
  /// In pt, this message translates to:
  /// **'Stash'**
  String get stash;

  /// No description provided for @currentBranch.
  ///
  /// In pt, this message translates to:
  /// **'Branch Atual'**
  String get currentBranch;

  /// No description provided for @head.
  ///
  /// In pt, this message translates to:
  /// **'HEAD'**
  String get head;

  /// No description provided for @switchBranch.
  ///
  /// In pt, this message translates to:
  /// **'Trocar Branch'**
  String get switchBranch;

  /// No description provided for @selectBranch.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar branch'**
  String get selectBranch;

  /// No description provided for @checkout.
  ///
  /// In pt, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @newBranch.
  ///
  /// In pt, this message translates to:
  /// **'Nova Branch'**
  String get newBranch;

  /// No description provided for @branchName.
  ///
  /// In pt, this message translates to:
  /// **'Nome da branch'**
  String get branchName;

  /// No description provided for @sync.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização'**
  String get sync;

  /// No description provided for @output.
  ///
  /// In pt, this message translates to:
  /// **'Saída'**
  String get output;

  /// No description provided for @clear.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get clear;

  /// No description provided for @recentCommits.
  ///
  /// In pt, this message translates to:
  /// **'Commits Recentes'**
  String get recentCommits;

  /// No description provided for @noCommits.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum commit'**
  String get noCommits;

  /// No description provided for @graphTimeline.
  ///
  /// In pt, this message translates to:
  /// **'Timeline Gráfica'**
  String get graphTimeline;

  /// No description provided for @newTag.
  ///
  /// In pt, this message translates to:
  /// **'Nova Tag'**
  String get newTag;

  /// No description provided for @tagName.
  ///
  /// In pt, this message translates to:
  /// **'Nome da tag'**
  String get tagName;

  /// No description provided for @tagMessage.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem da Tag'**
  String get tagMessage;

  /// No description provided for @tagMessageOptional.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem (opcional)'**
  String get tagMessageOptional;

  /// No description provided for @noTags.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma tag'**
  String get noTags;

  /// No description provided for @saveStash.
  ///
  /// In pt, this message translates to:
  /// **'Salvar Stash'**
  String get saveStash;

  /// No description provided for @stashMessageOptional.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem (opcional)'**
  String get stashMessageOptional;

  /// No description provided for @apply.
  ///
  /// In pt, this message translates to:
  /// **'Aplicar'**
  String get apply;

  /// No description provided for @pop.
  ///
  /// In pt, this message translates to:
  /// **'Pop'**
  String get pop;

  /// No description provided for @noStashes.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum stash'**
  String get noStashes;

  /// No description provided for @credentials.
  ///
  /// In pt, this message translates to:
  /// **'Credenciais'**
  String get credentials;

  /// No description provided for @usernameOptional.
  ///
  /// In pt, this message translates to:
  /// **'Usuário (opcional)'**
  String get usernameOptional;

  /// No description provided for @passwordOptional.
  ///
  /// In pt, this message translates to:
  /// **'Senha/Token (opcional)'**
  String get passwordOptional;

  /// No description provided for @execute.
  ///
  /// In pt, this message translates to:
  /// **'Executar'**
  String get execute;

  /// No description provided for @confirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @errorLoadingData.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar dados'**
  String get errorLoadingData;

  /// No description provided for @executing.
  ///
  /// In pt, this message translates to:
  /// **'Executando...'**
  String get executing;

  /// No description provided for @error.
  ///
  /// In pt, this message translates to:
  /// **'Erro'**
  String get error;

  /// No description provided for @commitMessageEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem do commit não pode ser vazia.'**
  String get commitMessageEmpty;

  /// No description provided for @noFilesSelected.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum arquivo selecionado para commit.'**
  String get noFilesSelected;

  /// No description provided for @committing.
  ///
  /// In pt, this message translates to:
  /// **'Fazendo commit...'**
  String get committing;

  /// No description provided for @noPendingChanges.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma alteração pendente'**
  String get noPendingChanges;

  /// No description provided for @filterByName.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar por nome...'**
  String get filterByName;

  /// No description provided for @all.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get all;

  /// No description provided for @none.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum'**
  String get none;

  /// No description provided for @commitMessageHint.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem do commit...'**
  String get commitMessageHint;

  /// No description provided for @selectFileToView.
  ///
  /// In pt, this message translates to:
  /// **'Selecione um arquivo para visualizar'**
  String get selectFileToView;

  /// No description provided for @diff.
  ///
  /// In pt, this message translates to:
  /// **'Diff'**
  String get diff;

  /// No description provided for @file.
  ///
  /// In pt, this message translates to:
  /// **'Arquivo'**
  String get file;

  /// No description provided for @before.
  ///
  /// In pt, this message translates to:
  /// **'ANTES (HEAD)'**
  String get before;

  /// No description provided for @after.
  ///
  /// In pt, this message translates to:
  /// **'DEPOIS (Atual)'**
  String get after;

  /// No description provided for @retry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get retry;

  /// No description provided for @noCommitsToDisplay.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum commit para exibir'**
  String get noCommitsToDisplay;

  /// No description provided for @projectPath.
  ///
  /// In pt, this message translates to:
  /// **'Caminho do projeto'**
  String get projectPath;

  /// No description provided for @removeRepoConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Isso apenas remove o projeto da lista, não exclui os arquivos.'**
  String get removeRepoConfirm;

  /// No description provided for @noRepo.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum repositório'**
  String get noRepo;

  /// No description provided for @noRepoHint.
  ///
  /// In pt, this message translates to:
  /// **'Use o botão abaixo para cadastrar um diretório git.'**
  String get noRepoHint;

  /// No description provided for @userOptional.
  ///
  /// In pt, this message translates to:
  /// **'Usuário (opcional)'**
  String get userOptional;

  /// No description provided for @graphicTimeline.
  ///
  /// In pt, this message translates to:
  /// **'Timeline Gráfica'**
  String get graphicTimeline;

  /// No description provided for @zoomIn.
  ///
  /// In pt, this message translates to:
  /// **'Aumentar zoom'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir zoom'**
  String get zoomOut;

  /// No description provided for @zoomReset.
  ///
  /// In pt, this message translates to:
  /// **'Resetar zoom'**
  String get zoomReset;

  /// No description provided for @noChanges.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma alteração pendente'**
  String get noChanges;

  /// No description provided for @filterFiles.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar arquivos...'**
  String get filterFiles;

  /// No description provided for @commitMessage.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem do commit...'**
  String get commitMessage;

  /// No description provided for @selectFile.
  ///
  /// In pt, this message translates to:
  /// **'Selecione um arquivo para visualizar'**
  String get selectFile;

  /// No description provided for @noCommitToShow.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum commit para exibir'**
  String get noCommitToShow;

  /// No description provided for @noStash.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum stash salvo'**
  String get noStash;

  /// No description provided for @added.
  ///
  /// In pt, this message translates to:
  /// **'Novo'**
  String get added;

  /// No description provided for @modified.
  ///
  /// In pt, this message translates to:
  /// **'Modificado'**
  String get modified;

  /// No description provided for @deleted.
  ///
  /// In pt, this message translates to:
  /// **'Deletado'**
  String get deleted;

  /// No description provided for @renamed.
  ///
  /// In pt, this message translates to:
  /// **'Renomeado'**
  String get renamed;

  /// No description provided for @conflicting.
  ///
  /// In pt, this message translates to:
  /// **'Conflito'**
  String get conflicting;

  /// No description provided for @untracked.
  ///
  /// In pt, this message translates to:
  /// **'Sem rastreamento'**
  String get untracked;

  /// No description provided for @projectName.
  ///
  /// In pt, this message translates to:
  /// **'Nome do projeto'**
  String get projectName;

  /// No description provided for @groupName.
  ///
  /// In pt, this message translates to:
  /// **'Nome do grupo'**
  String get groupName;

  /// No description provided for @ungrouped.
  ///
  /// In pt, this message translates to:
  /// **'Sem grupo'**
  String get ungrouped;

  /// No description provided for @push.
  ///
  /// In pt, this message translates to:
  /// **'Push'**
  String get push;

  /// No description provided for @pull.
  ///
  /// In pt, this message translates to:
  /// **'Pull'**
  String get pull;

  /// No description provided for @fetch.
  ///
  /// In pt, this message translates to:
  /// **'Fetch'**
  String get fetch;

  /// No description provided for @newItem.
  ///
  /// In pt, this message translates to:
  /// **'Novo'**
  String get newItem;

  /// No description provided for @creatingCommit.
  ///
  /// In pt, this message translates to:
  /// **'Fazendo commit...'**
  String get creatingCommit;

  /// No description provided for @reset.
  ///
  /// In pt, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetMode.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o modo de reset:'**
  String get resetMode;

  /// No description provided for @resetSoft.
  ///
  /// In pt, this message translates to:
  /// **'Soft (HEAD)'**
  String get resetSoft;

  /// No description provided for @resetMixed.
  ///
  /// In pt, this message translates to:
  /// **'Mixed (padrão)'**
  String get resetMixed;

  /// No description provided for @resetHard.
  ///
  /// In pt, this message translates to:
  /// **'Hard ⚠️'**
  String get resetHard;

  /// No description provided for @remotes.
  ///
  /// In pt, this message translates to:
  /// **'Remotes'**
  String get remotes;

  /// No description provided for @noRemotes.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum remote configurado'**
  String get noRemotes;

  /// No description provided for @reflog.
  ///
  /// In pt, this message translates to:
  /// **'Reflog'**
  String get reflog;

  /// No description provided for @deleteBranch.
  ///
  /// In pt, this message translates to:
  /// **'Delete Branch'**
  String get deleteBranch;

  /// No description provided for @merge.
  ///
  /// In pt, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @amend.
  ///
  /// In pt, this message translates to:
  /// **'Amend'**
  String get amend;

  /// No description provided for @amendCommit.
  ///
  /// In pt, this message translates to:
  /// **'Amend Commit'**
  String get amendCommit;

  /// No description provided for @newMessageOptional.
  ///
  /// In pt, this message translates to:
  /// **'Nova mensagem (opcional)'**
  String get newMessageOptional;

  /// No description provided for @cherryPick.
  ///
  /// In pt, this message translates to:
  /// **'Cherry-pick'**
  String get cherryPick;

  /// No description provided for @commitHash.
  ///
  /// In pt, this message translates to:
  /// **'Commit hash'**
  String get commitHash;

  /// No description provided for @rebase.
  ///
  /// In pt, this message translates to:
  /// **'Rebase'**
  String get rebase;

  /// No description provided for @noReflog.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum reflog'**
  String get noReflog;

  /// No description provided for @close.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get close;

  /// No description provided for @infoTooltipPush.
  ///
  /// In pt, this message translates to:
  /// **'Envia seus commits locais para o servidor remoto (GitHub, GitLab, etc.)'**
  String get infoTooltipPush;

  /// No description provided for @infoTooltipPull.
  ///
  /// In pt, this message translates to:
  /// **'Baixa as atualizações do servidor e mescla automaticamente na sua branch atual'**
  String get infoTooltipPull;

  /// No description provided for @infoTooltipFetch.
  ///
  /// In pt, this message translates to:
  /// **'Baixa informações do servidor sem alterar seus arquivos locais'**
  String get infoTooltipFetch;

  /// No description provided for @infoTooltipMerge.
  ///
  /// In pt, this message translates to:
  /// **'Combina outra branch na branch atual, unindo o trabalho de ambas'**
  String get infoTooltipMerge;

  /// No description provided for @infoTooltipCheckout.
  ///
  /// In pt, this message translates to:
  /// **'Troca para a branch selecionada, alterando os arquivos do projeto'**
  String get infoTooltipCheckout;

  /// No description provided for @infoTooltipNewBranch.
  ///
  /// In pt, this message translates to:
  /// **'Cria uma nova ramificação a partir do ponto atual, ideal para novas funcionalidades'**
  String get infoTooltipNewBranch;

  /// No description provided for @infoTooltipNewTag.
  ///
  /// In pt, this message translates to:
  /// **'Cria uma nova tag para marcar um ponto específico no histórico'**
  String get infoTooltipNewTag;

  /// No description provided for @infoTooltipDeleteBranch.
  ///
  /// In pt, this message translates to:
  /// **'Remove permanentemente a branch selecionada'**
  String get infoTooltipDeleteBranch;

  /// No description provided for @infoTooltipReset.
  ///
  /// In pt, this message translates to:
  /// **'Volta o repositório para um estado anterior. Cuidado: pode apagar alterações!'**
  String get infoTooltipReset;

  /// No description provided for @infoTooltipStashSave.
  ///
  /// In pt, this message translates to:
  /// **'Guarda temporariamente suas alterações sem fazer commit, limpando a área de trabalho'**
  String get infoTooltipStashSave;

  /// No description provided for @infoTooltipStashApply.
  ///
  /// In pt, this message translates to:
  /// **'Aplica as alterações guardadas no stash sem removê-las'**
  String get infoTooltipStashApply;

  /// No description provided for @infoTooltipStashPop.
  ///
  /// In pt, this message translates to:
  /// **'Aplica e remove as alterações mais recentes do stash'**
  String get infoTooltipStashPop;

  /// No description provided for @infoTooltipCherryPick.
  ///
  /// In pt, this message translates to:
  /// **'Copia um commit específico de outra branch para a branch atual'**
  String get infoTooltipCherryPick;

  /// No description provided for @infoTooltipRebase.
  ///
  /// In pt, this message translates to:
  /// **'Reescreve o histórico movendo seus commits para o topo de outra branch'**
  String get infoTooltipRebase;

  /// No description provided for @infoTooltipAmend.
  ///
  /// In pt, this message translates to:
  /// **'Corrige o último commit (mensagem ou arquivos) sem criar um novo'**
  String get infoTooltipAmend;

  /// No description provided for @infoTooltipCreateTag.
  ///
  /// In pt, this message translates to:
  /// **'Cria uma marcação (versão) em um ponto específico do histórico'**
  String get infoTooltipCreateTag;

  /// No description provided for @infoTooltipDeleteTag.
  ///
  /// In pt, this message translates to:
  /// **'Remove uma tag existente'**
  String get infoTooltipDeleteTag;

  /// No description provided for @infoTooltipRemotes.
  ///
  /// In pt, this message translates to:
  /// **'Mostra os servidores remotos configurados para este repositório'**
  String get infoTooltipRemotes;

  /// No description provided for @repoStateClean.
  ///
  /// In pt, this message translates to:
  /// **'Tudo limpo — nenhuma alteração pendente'**
  String get repoStateClean;

  /// No description provided for @repoStateDirty.
  ///
  /// In pt, this message translates to:
  /// **'Há alterações não salvas'**
  String get repoStateDirty;

  /// No description provided for @repoStateAhead.
  ///
  /// In pt, this message translates to:
  /// **'commits à frente do remoto'**
  String get repoStateAhead;

  /// No description provided for @repoStateBehind.
  ///
  /// In pt, this message translates to:
  /// **'commits atrás do remoto'**
  String get repoStateBehind;

  /// No description provided for @confirmDeleteBranch.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja excluir a branch'**
  String get confirmDeleteBranch;

  /// No description provided for @confirmDeleteTag.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja excluir a tag'**
  String get confirmDeleteTag;

  /// No description provided for @cloneRepo.
  ///
  /// In pt, this message translates to:
  /// **'Clonar Repositório'**
  String get cloneRepo;

  /// No description provided for @cloneUrl.
  ///
  /// In pt, this message translates to:
  /// **'URL do repositório'**
  String get cloneUrl;

  /// No description provided for @cloneDestination.
  ///
  /// In pt, this message translates to:
  /// **'Pasta de destino'**
  String get cloneDestination;

  /// No description provided for @settings.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get settings;

  /// No description provided for @copyHash.
  ///
  /// In pt, this message translates to:
  /// **'Copiar hash'**
  String get copyHash;

  /// No description provided for @viewDiff.
  ///
  /// In pt, this message translates to:
  /// **'Ver diff'**
  String get viewDiff;

  /// No description provided for @revertCommit.
  ///
  /// In pt, this message translates to:
  /// **'Reverter commit'**
  String get revertCommit;

  /// No description provided for @searchCommits.
  ///
  /// In pt, this message translates to:
  /// **'Buscar commits...'**
  String get searchCommits;

  /// No description provided for @moreActions.
  ///
  /// In pt, this message translates to:
  /// **'Mais ações'**
  String get moreActions;

  /// No description provided for @staged.
  ///
  /// In pt, this message translates to:
  /// **'Preparados'**
  String get staged;

  /// No description provided for @unstaged.
  ///
  /// In pt, this message translates to:
  /// **'Não preparados'**
  String get unstaged;

  /// No description provided for @back.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get back;

  /// No description provided for @deleteRepoTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover repositório'**
  String get deleteRepoTitle;

  /// No description provided for @deleteRepoMessage.
  ///
  /// In pt, this message translates to:
  /// **'Você está removendo \'{name}\' da lista. Os arquivos no disco NÃO serão apagados.'**
  String deleteRepoMessage(Object name);

  /// No description provided for @statusClean.
  ///
  /// In pt, this message translates to:
  /// **'Status: limpo'**
  String get statusClean;

  /// No description provided for @statusDirty.
  ///
  /// In pt, this message translates to:
  /// **'Status: alterações pendentes'**
  String get statusDirty;

  /// No description provided for @nothingToCommit.
  ///
  /// In pt, this message translates to:
  /// **'Nada para commitar'**
  String get nothingToCommit;

  /// No description provided for @uncommittedChanges.
  ///
  /// In pt, this message translates to:
  /// **'alterações não commitadas'**
  String get uncommittedChanges;

  /// No description provided for @aheadBy.
  ///
  /// In pt, this message translates to:
  /// **'à frente'**
  String get aheadBy;

  /// No description provided for @behindBy.
  ///
  /// In pt, this message translates to:
  /// **'atrás'**
  String get behindBy;

  /// No description provided for @diverged.
  ///
  /// In pt, this message translates to:
  /// **'divergido'**
  String get diverged;

  /// No description provided for @syncStatus.
  ///
  /// In pt, this message translates to:
  /// **'Status de sincronização'**
  String get syncStatus;

  /// No description provided for @lastFetch.
  ///
  /// In pt, this message translates to:
  /// **'Último fetch'**
  String get lastFetch;

  /// No description provided for @noRemoteConfigured.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum remoto configurado'**
  String get noRemoteConfigured;

  /// No description provided for @openInTerminal.
  ///
  /// In pt, this message translates to:
  /// **'Abrir no terminal'**
  String get openInTerminal;

  /// No description provided for @exploreChanges.
  ///
  /// In pt, this message translates to:
  /// **'Explorar alterações'**
  String get exploreChanges;

  /// No description provided for @exploreChangesHint.
  ///
  /// In pt, this message translates to:
  /// **'Clique em um arquivo para ver o que mudou'**
  String get exploreChangesHint;

  /// No description provided for @viewBlame.
  ///
  /// In pt, this message translates to:
  /// **'Ver blame'**
  String get viewBlame;

  /// No description provided for @cleanUntracked.
  ///
  /// In pt, this message translates to:
  /// **'Limpar não rastreados'**
  String get cleanUntracked;

  /// No description provided for @forcePush.
  ///
  /// In pt, this message translates to:
  /// **'Push forçado'**
  String get forcePush;

  /// No description provided for @prune.
  ///
  /// In pt, this message translates to:
  /// **'Limpar referências'**
  String get prune;

  /// No description provided for @submoduleUpdate.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar submódulos'**
  String get submoduleUpdate;

  /// No description provided for @editGitIgnore.
  ///
  /// In pt, this message translates to:
  /// **'Editar .gitignore'**
  String get editGitIgnore;

  /// No description provided for @userName.
  ///
  /// In pt, this message translates to:
  /// **'Nome de usuário Git'**
  String get userName;

  /// No description provided for @userEmail.
  ///
  /// In pt, this message translates to:
  /// **'E-mail Git'**
  String get userEmail;

  /// No description provided for @gitConfig.
  ///
  /// In pt, this message translates to:
  /// **'Configurações Git'**
  String get gitConfig;

  /// No description provided for @showGitCommandOutput.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar saída dos comandos'**
  String get showGitCommandOutput;

  /// No description provided for @confirmDangerousActions.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar ações perigosas'**
  String get confirmDangerousActions;

  /// No description provided for @loading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando...'**
  String get loading;

  /// No description provided for @empty.
  ///
  /// In pt, this message translates to:
  /// **'Vazio'**
  String get empty;

  /// No description provided for @operationSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Operação concluída com sucesso'**
  String get operationSuccess;

  /// No description provided for @operationFailed.
  ///
  /// In pt, this message translates to:
  /// **'Operação falhou'**
  String get operationFailed;

  /// No description provided for @copied.
  ///
  /// In pt, this message translates to:
  /// **'Copiado!'**
  String get copied;

  /// No description provided for @details.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes'**
  String get details;

  /// No description provided for @preview.
  ///
  /// In pt, this message translates to:
  /// **'Visualizar'**
  String get preview;

  /// No description provided for @actions.
  ///
  /// In pt, this message translates to:
  /// **'Ações'**
  String get actions;

  /// No description provided for @commitDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do commit'**
  String get commitDetails;

  /// No description provided for @parentCommits.
  ///
  /// In pt, this message translates to:
  /// **'Commits pai'**
  String get parentCommits;

  /// No description provided for @changedFiles.
  ///
  /// In pt, this message translates to:
  /// **'Arquivos alterados'**
  String get changedFiles;

  /// No description provided for @openFolder.
  ///
  /// In pt, this message translates to:
  /// **'Abrir pasta'**
  String get openFolder;

  /// No description provided for @repositoryUrl.
  ///
  /// In pt, this message translates to:
  /// **'URL do repositório'**
  String get repositoryUrl;

  /// No description provided for @openRepositoryUrl.
  ///
  /// In pt, this message translates to:
  /// **'Abrir URL no navegador'**
  String get openRepositoryUrl;

  /// No description provided for @noDescription.
  ///
  /// In pt, this message translates to:
  /// **'Sem descrição'**
  String get noDescription;

  /// No description provided for @noCommitsToShow.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum commit para exibir'**
  String get noCommitsToShow;

  /// No description provided for @warning.
  ///
  /// In pt, this message translates to:
  /// **'Atenção'**
  String get warning;

  /// No description provided for @compactMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo compacto'**
  String get compactMode;

  /// No description provided for @comfortableMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo confortável'**
  String get comfortableMode;

  /// No description provided for @graphCompactView.
  ///
  /// In pt, this message translates to:
  /// **'Vista compacta'**
  String get graphCompactView;

  /// No description provided for @graphDetailedView.
  ///
  /// In pt, this message translates to:
  /// **'Vista detalhada'**
  String get graphDetailedView;

  /// No description provided for @commitDate.
  ///
  /// In pt, this message translates to:
  /// **'Data'**
  String get commitDate;

  /// No description provided for @commitAuthor.
  ///
  /// In pt, this message translates to:
  /// **'Autor'**
  String get commitAuthor;

  /// No description provided for @stage.
  ///
  /// In pt, this message translates to:
  /// **'Stage'**
  String get stage;

  /// No description provided for @unstage.
  ///
  /// In pt, this message translates to:
  /// **'Unstage'**
  String get unstage;

  /// No description provided for @stageSelected.
  ///
  /// In pt, this message translates to:
  /// **'Stage selecionados'**
  String get stageSelected;

  /// No description provided for @unstageSelected.
  ///
  /// In pt, this message translates to:
  /// **'Unstage selecionados'**
  String get unstageSelected;

  /// No description provided for @stagedFiles.
  ///
  /// In pt, this message translates to:
  /// **'Arquivos em stage'**
  String get stagedFiles;

  /// No description provided for @unstagedFiles.
  ///
  /// In pt, this message translates to:
  /// **'Arquivos não staged'**
  String get unstagedFiles;

  /// No description provided for @nothingToStage.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum arquivo selecionado para stage'**
  String get nothingToStage;

  /// No description provided for @nothingToUnstage.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum arquivo selecionado para unstage'**
  String get nothingToUnstage;

  /// No description provided for @language.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In pt, this message translates to:
  /// **'Aparência'**
  String get appearance;

  /// No description provided for @discardChanges.
  ///
  /// In pt, this message translates to:
  /// **'Desfazer alterações'**
  String get discardChanges;

  /// No description provided for @discardChangesConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja desfazer as alterações em \'{file}\'?'**
  String discardChangesConfirm(String file);

  /// No description provided for @openFile.
  ///
  /// In pt, this message translates to:
  /// **'Abrir arquivo'**
  String get openFile;

  /// No description provided for @delete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get delete;

  /// No description provided for @deleteTag.
  ///
  /// In pt, this message translates to:
  /// **'Excluir tag'**
  String get deleteTag;

  /// No description provided for @deleteTagConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Deseja realmente excluir a tag \'{name}\'?'**
  String deleteTagConfirm(String name);

  /// No description provided for @commits.
  ///
  /// In pt, this message translates to:
  /// **'commits'**
  String get commits;

  /// No description provided for @branchCommits.
  ///
  /// In pt, this message translates to:
  /// **'Commits da branch'**
  String get branchCommits;

  /// No description provided for @allBranches.
  ///
  /// In pt, this message translates to:
  /// **'Todas as branches'**
  String get allBranches;

  /// No description provided for @nothingToPush.
  ///
  /// In pt, this message translates to:
  /// **'Nada para enviar'**
  String get nothingToPush;

  /// No description provided for @nothingToPull.
  ///
  /// In pt, this message translates to:
  /// **'Nada para baixar'**
  String get nothingToPull;

  /// No description provided for @upToDate.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado'**
  String get upToDate;

  /// No description provided for @copy.
  ///
  /// In pt, this message translates to:
  /// **'Copiar'**
  String get copy;

  /// No description provided for @comingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em breve'**
  String get comingSoon;

  /// No description provided for @notificationSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Sucesso'**
  String get notificationSuccess;

  /// No description provided for @notificationError.
  ///
  /// In pt, this message translates to:
  /// **'Erro'**
  String get notificationError;

  /// No description provided for @notificationWarning.
  ///
  /// In pt, this message translates to:
  /// **'Atenção'**
  String get notificationWarning;

  /// No description provided for @notificationInfo.
  ///
  /// In pt, this message translates to:
  /// **'Info'**
  String get notificationInfo;

  /// No description provided for @repoAddedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Repositórios adicionados com sucesso.'**
  String get repoAddedSuccess;

  /// No description provided for @commitButtonTooltipNoStagedFiles.
  ///
  /// In pt, this message translates to:
  /// **'Adicione arquivos ao stage para poder commitar'**
  String get commitButtonTooltipNoStagedFiles;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
