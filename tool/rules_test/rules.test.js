// Testa firestore.rules no emulador. Uso (na pasta tool/rules_test):
//   npm install && npm test        (requer Java e o Firebase CLI)
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;
const OWNER = 'renanndejesus@gmail.com';

function as(uid, email, verified = true) {
  return env
    .authenticatedContext(uid, { email, email_verified: verified })
    .firestore();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-flashcards',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'allowedUsers/ana@gmail.com'), { email: 'ana@gmail.com', role: 'user' });
    await setDoc(doc(db, 'allowedUsers/bia@gmail.com'), { email: 'bia@gmail.com', role: 'admin' });
    await setDoc(doc(db, 'users/ana'), { data: '{}' });
    await setDoc(doc(db, 'users/carlos'), { data: '{}' });
  });
});

after(() => env.cleanup());

test('dono libera e remove pessoas e lê o progresso de todos', async () => {
  const db = as('owner', OWNER);
  await assertSucceeds(setDoc(doc(db, 'allowedUsers/novo@gmail.com'), { email: 'novo@gmail.com', role: 'user' }));
  await assertSucceeds(deleteDoc(doc(db, 'allowedUsers/novo@gmail.com')));
  await assertSucceeds(getDoc(doc(db, 'users/ana')));
});

test('e-mail não cadastrado não lê nem grava progresso', async () => {
  const db = as('carlos', 'carlos@gmail.com');
  await assertFails(getDoc(doc(db, 'users/carlos')));
  await assertFails(setDoc(doc(db, 'users/carlos'), { data: '{}' }));
  await assertFails(getDoc(doc(db, 'allowedUsers/ana@gmail.com')));
  // Pode consultar o próprio cadastro (para o app saber que não tem acesso).
  await assertSucceeds(getDoc(doc(db, 'allowedUsers/carlos@gmail.com')));
  // E não consegue se cadastrar sozinho.
  await assertFails(setDoc(doc(db, 'allowedUsers/carlos@gmail.com'), { role: 'admin' }));
});

test('pessoa cadastrada usa só o próprio progresso', async () => {
  const db = as('ana', 'Ana@Gmail.com');
  await assertSucceeds(getDoc(doc(db, 'users/ana')));
  await assertSucceeds(setDoc(doc(db, 'users/ana'), { data: '{"x":1}' }));
  await assertFails(getDoc(doc(db, 'users/carlos')));
  await assertFails(setDoc(doc(db, 'users/carlos'), { data: '{}' }));
});

test('pessoa cadastrada registra o login mas não muda o próprio papel', async () => {
  const db = as('ana', 'ana@gmail.com');
  await assertSucceeds(updateDoc(doc(db, 'allowedUsers/ana@gmail.com'), { uid: 'ana', lastLoginAt: 1 }));
  await assertFails(updateDoc(doc(db, 'allowedUsers/ana@gmail.com'), { role: 'admin' }));
  await assertFails(setDoc(doc(db, 'allowedUsers/novo@gmail.com'), { role: 'user' }));
  await assertFails(deleteDoc(doc(db, 'allowedUsers/bia@gmail.com')));
});

test('administrador cadastrado gerencia acessos e vê o progresso', async () => {
  const db = as('bia', 'bia@gmail.com');
  await assertSucceeds(setDoc(doc(db, 'allowedUsers/novo@gmail.com'), { email: 'novo@gmail.com', role: 'user' }));
  await assertSucceeds(updateDoc(doc(db, 'allowedUsers/ana@gmail.com'), { role: 'admin' }));
  await assertSucceeds(getDoc(doc(db, 'users/ana')));
  await assertFails(setDoc(doc(db, 'users/ana'), { data: '{}' }));
});

test('e-mail não verificado é recusado', async () => {
  const db = as('ana', 'ana@gmail.com', false);
  await assertFails(getDoc(doc(db, 'users/ana')));
});

test('sem login, nada é acessível', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'users/ana')));
  await assertFails(getDoc(doc(db, 'allowedUsers/ana@gmail.com')));
});
