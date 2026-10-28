
import 'package:firebase_database/firebase_database.dart';

class FirebaseSensorService {
  final DatabaseReference _sensorRef =
      FirebaseDatabase.instance.ref('sensors/ESP32-001');

  Stream<DatabaseEvent> get sensorStream => _sensorRef.onValue;
}
