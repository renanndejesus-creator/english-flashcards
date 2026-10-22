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

/// Sincroniza o progresso com o Firestore (users/{uid}) após login com Google.
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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _remoteSub;
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
    FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  Future<void> signIn() async {
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
    }
  }

  Future<void> signOut() async {
    await _flush();
    await FirebaseAuth.instance.signOut();
  }

  DocumentReference<Map<String, dynamic>> _doc(User user) =>
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  void _onUser(User? user) {
    _user = user;
    _remoteSub?.cancel();
    _localSub?.cancel();
    _pushTimer?.cancel();
    if (user == null) {
      _setStatus(SyncStatus.signedOut);
      return;
    }
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
        'data': jsonEncode(_app.snapshot()),
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
