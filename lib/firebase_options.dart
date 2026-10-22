import 'package:firebase_core/firebase_core.dart';

/// Configuração do projeto Firebase (Console → Configurações do projeto → Seus apps).
///
/// Esses valores não são secretos: só identificam o projeto. Quem protege os
/// dados são as regras do Firestore (firestore.rules).
/// Enquanto for null, o app funciona só com o armazenamento do navegador.
const FirebaseOptions? firebaseWebOptions = null;
