import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloud_sync.dart';

/// Uma pessoa com acesso ao app (documento allowedUsers/{email}).
class Member {
  const Member({
    required this.email,
    required this.isAdmin,
    this.name,
    this.displayName,
    this.photoURL,
    this.uid,
    this.addedAt,
    this.lastLoginAt,
  });

  final String email;
  final bool isAdmin;

  /// Nome digitado no cadastro.
  final String? name;

  /// Nome e foto da conta Google (preenchidos no primeiro login).
  final String? displayName;
  final String? photoURL;
  final String? uid;
  final DateTime? addedAt;
  final DateTime? lastLoginAt;

  bool get isOwner => email == ownerEmail;
  String get label => name ?? displayName ?? email;

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final name = (d['name'] as String?)?.trim();
    return Member(
      email: doc.id,
      isAdmin: d['role'] == 'admin' || doc.id == ownerEmail,
      name: name == null || name.isEmpty ? null : name,
      displayName: d['displayName'] as String?,
      photoURL: d['photoURL'] as String?,
      uid: d['uid'] as String?,
      addedAt: (d['addedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (d['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Resumo do progresso de uma pessoa (campo `summary` de users/{uid}).
class ProgressSummary {
  const ProgressSummary({
    required this.seen,
    required this.mastered,
    required this.due,
    required this.streak,
    this.lastReviewAt,
  });

  final int seen;
  final int mastered;
  final int due;
  final int streak;
  final DateTime? lastReviewAt;

  factory ProgressSummary.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    final last = n('lastReviewAt');
    return ProgressSummary(
      seen: n('seen'),
      mastered: n('mastered'),
      due: n('due'),
      streak: n('streak'),
      lastReviewAt: last == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(last),
    );
  }
}

/// Operações do console de administração. As regras do Firestore garantem
/// que só administradores conseguem executá-las.
class AdminService {
  static final _members = FirebaseFirestore.instance.collection('allowedUsers');

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String email) =>
      _emailPattern.hasMatch(email.trim());

  static Stream<List<Member>> members() => _members.snapshots().map((q) {
    final list = q.docs.map(Member.fromDoc).toList();
    list.sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.email.compareTo(b.email);
    });
    return list;
  });

  /// Libera o acesso para [email]. Retorna false se ele já estava cadastrado.
  static Future<bool> add(
    String email, {
    String? name,
    bool admin = false,
  }) async {
    final doc = CloudSync.memberDoc(email);
    if ((await doc.get()).exists) return false;
    await doc.set({
      'email': doc.id,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'role': admin ? 'admin' : 'user',
      'addedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  static Future<void> setAdmin(String email, bool admin) =>
      CloudSync.memberDoc(email).update({'role': admin ? 'admin' : 'user'});

  /// Remove o acesso. O progresso da pessoa continua guardado.
  static Future<void> remove(String email) =>
      CloudSync.memberDoc(email).delete();

  static Stream<ProgressSummary?> summary(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
        final s = doc.data()?['summary'] as Map<String, dynamic>?;
        return s == null ? null : ProgressSummary.fromJson(s);
      });
}
