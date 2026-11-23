import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('N-01: temporada passada não oculta partidas futuras de nenhuma liga', () async {
    final app = await Firebase.initializeApp(
      name: 'partidas-emulador',
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:000000000000:android:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-betfriends',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('10.0.2.2', 9099);
    final db = FirebaseFirestore.instanceFor(app: app)
      ..settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator('10.0.2.2', 8080);
    await auth.signInWithEmailAndPassword(
      email: 'ana@example.com', password: 'senha-emulador-123',
    );
    try {
      final repo = FirestorePartidasRepository(firestore: db);
      final partidas = await repo.getPartidas();
      // BSA: 5 futuras; PL, SA e PD: 3 futuras cada.
      expect(partidas.where((p) => p.podeCriarDesafio).length, 14);
      expect(
        partidas.map((p) => p.competitionCode).toSet(),
        {'BSA', 'PL', 'SA', 'PD'},
      );
      // Ordenadas por horário: a mais antiga é a mais distante das 3 recentes do BSA.
      expect(partidas.first.id, 'temporada_57');
      final horarios = [for (final p in partidas) p.startsAtUtc!];
      expect([...horarios]..sort(), horarios);
      // O mesmo conjunto deve continuar disponível sem rede.
      await db.disableNetwork();
      final cache = await repo.getPartidas();
      expect(cache.map((p) => p.id), partidas.map((p) => p.id));
    } finally {
      await db.enableNetwork();
      await auth.signOut();
      await app.delete();
    }
  });
}
