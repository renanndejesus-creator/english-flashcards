import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../state/app_state.dart';
import 'sync_merge.dart';

enum SyncStatus { unavailable, signedOut, syncing, synced, error }

/// Situação do acesso da conta conectada à lista de e-mails liberados.
enum Access { checking, allowed, denied }

/// Dono do app: sempre tem acesso e é administrador (igual a firestore.rules).
const ownerEmail = 'renanndejesus@gmail.com';

/// Controla o login com Google, o acesso pela lista de e-mails liberados
/// (allowedUsers/{email}) e sincroniza o progresso com o Firestore (users/{uid}).
///
/// O navegador continua sendo a cópia de trabalho; a nuvem recebe cada
/// alteração (com um pequeno atraso) e as mudanças de outros aparelhos são
/// mescladas aqui assim que chegam.
class CloudSync extends ChangeNotifier {
  CloudSync(this._app);

  final AppState _app;

  SyncStatus _status = SyncStatus.unavailable;
  SyncStatus get status => _status;

  User? _user;
  User? get user => _user;

  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;

  String? _error;
  String? get error => _error;

  bool get available => _status != SyncStatus.unavailable;

  Access _access = Access.checking;
  Access get access => _access;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  /// Nome digitado no cadastro do console (tem prioridade sobre o do Google).
  String? _memberName;

  /// Primeiro nome para cumprimentar a pessoa, ou null se não houver.
  String? get firstName {
    final name = (_memberName ?? _user?.displayName ?? '').trim();
    return name.isEmpty ? null : name.split(RegExp(r'\s+')).first;
  }

  /// Janela de login do Google aberta, aguardando o usuário.
  bool _signingIn = false;
  bool get signingIn => _signingIn;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _remoteSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;
  StreamSubscription<void>? _localSub;
  Timer? _pushTimer;

  static const _pushDelay = Duration(seconds: 2);

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: firebaseWebOptions);
    } catch (e) {
      debugPrint('Firebase indisponível: $e');
      return;
    }
    _setStatus(SyncStatus.signedOut);
    // Espera a sessão salva ser restaurada, para não mostrar a tela de login
    // por um instante a quem já entrou.
    final firstUser = Completer<void>();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _onUser(user);
      if (!firstUser.isCompleted) firstUser.complete();
    });
    await firstUser.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  Future<void> signIn() async {
    _error = null;
    _signingIn = true;
    notifyListeners();
    try {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      _fail(switch (e.code) {
        'unauthorized-domain' => 'Este endereço não está autorizado no Firebase (Authentication → Domínios autorizados).',
        'operation-not-allowed' || 'configuration-not-found' => 'O login com Google ainda não foi ativado no Firebase (Authentication → Método de login).',
        'popup-blocked' => 'O navegador bloqueou a janela de login. Permita pop-ups para este site e tente de novo.',
        _ => 'Não foi possível entrar: ${e.message ?? e.code}',
      });
    } finally {
      _signingIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_access == Access.allowed) await _flush();
    await FirebaseAuth.instance.signOut();
  }

  DocumentReference<Map<String, dynamic>> _doc(User user) =>
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  static DocumentReference<Map<String, dynamic>> memberDoc(String email) =>
      FirebaseFirestore.instance
          .collection('allowedUsers')
          .doc(email.trim().toLowerCase());

  void _onUser(User? user) {
    _user = user;
    _stopSync();
    _memberSub?.cancel();
    _isAdmin = false;
    _memberName = null;
    if (user == null) {
      _app.useAccount(null);
      _setStatus(SyncStatus.signedOut);
      return;
    }
    _access = Access.checking;
    _setStatus(SyncStatus.syncing);
    final email = (user.email ?? '').toLowerCase();
    if (email == ownerEmail) {
      _isAdmin = true;
      _registerLogin(user, owner: true);
      _grantAccess(user);
      // O dono não depende do cadastro para entrar; só acompanha o nome.
      _memberSub = memberDoc(email).snapshots().listen((doc) {
        _memberName = doc.data()?['name'] as String?;
        notifyListeners();
      }, onError: (Object _) {});
      return;
    }
    // Acompanha o cadastro: se o administrador remover o e-mail, o acesso cai na hora.
    _memberSub = memberDoc(email).snapshots().listen((doc) {
      if (!doc.exists) {
        _denyAccess();
        return;
      }
      _isAdmin = doc.data()?['role'] == 'admin';
      _memberName = doc.data()?['name'] as String?;
      if (_access != Access.allowed) {
        _registerLogin(user);
        _grantAccess(user);
      } else {
        notifyListeners();
      }
    }, onError: (Object _) => _denyAccess());
  }

  /// Guarda no cadastro quando e com qual conta a pessoa entrou (visto no console).
  Future<void> _registerLogin(User user, {bool owner = false}) async {
    final email = (user.email ?? '').toLowerCase();
    try {
      await memberDoc(email).set({
        if (owner) ...{'email': email, 'role': 'admin'},
        'uid': user.uid,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Não foi possível registrar o login: $e');
    }
  }

  void _denyAccess() {
    _stopSync();
    _access = Access.denied;
    _isAdmin = false;
    _setStatus(SyncStatus.signedOut);
  }

  void _stopSync() {
    _remoteSub?.cancel();
    _localSub?.cancel();
    _pushTimer?.cancel();
  }

  void _grantAccess(User user) {
    _access = Access.allowed;
    _app.useAccount(user.uid);
    _setStatus(SyncStatus.syncing);
    _remoteSub = _doc(user).snapshots().listen(
      _onRemote,
      onError: (Object e) {
        _fail('Erro ao ler da nuvem: $e');
      },
    );
    _localSub = _app.changes.listen((_) => _schedulePush());
  }

  /// Chega na primeira leitura e a cada alteração feita em outro aparelho.
  void _onRemote(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (doc.metadata.hasPendingWrites) return; // eco da nossa própria escrita
    final raw = doc.data()?['data'] as String?;
    final remote = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final merged = mergeSnapshots(_app.snapshot(), remote);
    const eq = DeepCollectionEquality();
    if (!eq.equals(merged, _app.snapshot())) _app.applySnapshot(merged);
    if (eq.equals(merged, remote)) {
      _markSynced();
    } else {
      _push();
    }
  }

  void _schedulePush() {
    _setStatus(SyncStatus.syncing);
    _pushTimer?.cancel();
    _pushTimer = Timer(_pushDelay, _push);
  }

  Future<void> _flush() async {
    if (_pushTimer?.isActive ?? false) {
      _pushTimer!.cancel();
      await _push();
    }
  }

  Future<void> _push() async {
    final user = _user;
    if (user == null) return;
    _setStatus(SyncStatus.syncing);
    try {
      await _doc(user).set({
        'email': user.email?.toLowerCase(),
        'data': jsonEncode(_app.snapshot()),
        'summary': _app.summary(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _markSynced();
    } catch (e) {
      _fail('Erro ao salvar na nuvem: $e');
    }
  }

  void _markSynced() {
    _lastSync = DateTime.now();
    _error = null;
    _setStatus(SyncStatus.synced);
  }

  void _fail(String message) {
    _error = message;
    _setStatus(SyncStatus.error);
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    notifyListeners();
  }
}
