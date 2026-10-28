import 'package:firebase_database/firebase_database.dart';

Future<void> testFirebaseConnection() async {
  final ref = FirebaseDatabase.instance.ref('connection_test');

  await ref.set({
    'status': 'connected',
    'message': 'Flutter berhasil terhubung ke Firebase',
    'timestamp': ServerValue.timestamp,
  });

  print('Berhasil menulis data ke Firebase!');
}