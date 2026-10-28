import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_sensor_service.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';

/// Pusat state aplikasi (memakai `provider`).
///
/// Semua layar membaca data dari sini. Saat backend nyata siap, cukup ganti
/// isi method yang bertanda `// TODO(api)` dengan pemanggilan HTTP.
class AppState extends ChangeNotifier {
  AppState({bool enableFirebase = true}) {
  _farms = MockData.farms();
  _selectedFarmId = _farms.first.id;
  _schedules = MockData.schedules();
  _tasks = MockData.tasks();
  _alerts = MockData.initialAlerts();
  _irrigationLogs = MockData.irrigationLogs();

  if (enableFirebase) {
    listenToFirebaseSensors();
  }

  _seedChat();
}


  void setUserForTesting({
  required String email,
  required String name,
}) {
  _user = AppUser(
    id: 'test-user',
    name: name.isEmpty ? 'Petani Hebat' : name,
    email: email,
    role: UserRole.owner,
  );

  notifyListeners();
}

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  AppUser? _user;
  late List<Farm> _farms;
  late String _selectedFarmId;
  late List<IrrigationSchedule> _schedules;
  late List<PlantTask> _tasks;
  late List<AlertItem> _alerts;
  late List<IrrigationLog> _irrigationLogs;
  final List<ChatMessage> _chat = <ChatMessage>[];

  final AiAssistantService ai = AiAssistantService();

  int _idCounter = 0;
  Timer? _timer;
  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  bool _busy = false;
  bool _liveData = false;
  ThemeMode _themeMode = ThemeMode.dark;

  // ---------------------------------------------------------------------------
  // Getter
  // ---------------------------------------------------------------------------

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get busy => _busy;
  bool get liveData => _liveData;
  ThemeMode get themeMode => _themeMode;

  List<Farm> get farms => List<Farm>.unmodifiable(_farms);
  Farm get selectedFarm =>
      _farms.firstWhere((f) => f.id == _selectedFarmId, orElse: () => _farms.first);

  List<IrrigationSchedule> get schedules =>
      _schedules.where((s) => s.farmId == selectedFarm.id).toList()
        ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

  List<PlantTask> get tasks {
    final list = _tasks.where((t) => t.farmId == selectedFarm.id).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.due.compareTo(b.due);
    });
    return list;
  }

  List<AlertItem> get alerts =>
      _alerts.where((a) => a.farmId == selectedFarm.id).toList()
        ..sort((a, b) => b.time.compareTo(a.time));

  List<AlertItem> get allAlerts =>
      List<AlertItem>.unmodifiable(_alerts..sort((a, b) => b.time.compareTo(a.time)));

  int get unreadAlertCount => _alerts.where((a) => !a.read).length;

  List<IrrigationLog> get irrigationLogs =>
      _irrigationLogs.where((l) => l.farmId == selectedFarm.id).toList()
        ..sort((a, b) => b.time.compareTo(a.time));

  List<ChatMessage> get chat => List<ChatMessage>.unmodifiable(_chat);

  int get pendingTaskCount => _tasks.where((t) => !t.done).length;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------



    Future<void> login({
      required String email,
      required String password,
      required String name,
    }) async {
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        final firebaseUser = credential.user;

        if (firebaseUser == null) {
          throw Exception('Pengguna tidak ditemukan.');
        }

        _user = AppUser(
          id: firebaseUser.uid,
          name: name.isEmpty
              ? (firebaseUser.displayName ?? 'Petani Hebat')
              : name,
          email: firebaseUser.email ?? email,
          role: UserRole.owner,
        );

        if (_liveData) startLive();

        notifyListeners();
      } on FirebaseAuthException {
        rethrow;
      }
    }

  void loginDemo() {
  _user = AppUser(
    id: 'demo-user',
    name: 'Pengguna Demo',
    email: 'demo@mikiko.com',
    role: UserRole.owner,
  );

  notifyListeners();
}


  void logout() {
    _user = null;
    stopLive();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Navigasi / tema
  // ---------------------------------------------------------------------------

  void selectFarm(String farmId) {
    if (_selectedFarmId == farmId) return;
    _selectedFarmId = farmId;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setLiveData(bool value) {
    _liveData = value;
    if (value) {
      startLive();
    } else {
      stopLive();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Data live (simulasi sensor masuk tiap beberapa detik)
  // ---------------------------------------------------------------------------

  void startLive() {
    _timer ??= Timer.periodic(const Duration(seconds: 6), (_) => simulateTick());
  }

  void stopLive() {
    _timer?.cancel();
    _timer = null;
  }

  void listenToFirebaseSensors() {
  _sensorSubscription?.cancel();

  final sensorService = FirebaseSensorService();

  _sensorSubscription = sensorService.sensorStream.listen(
    (event) {
      final rawData = event.snapshot.value;

      if (rawData is! Map) {
        debugPrint('Data Firebase kosong atau format tidak sesuai.');
        return;
      }

      final data = Map<String, dynamic>.from(rawData);
      final now = DateTime.now();
      final farm = selectedFarm;

      final sensorValues = <SensorType, double>{
        SensorType.temperature:
            (data['temperature'] as num?)?.toDouble() ?? farm.temperature,
        SensorType.humidity:
            (data['humidity'] as num?)?.toDouble() ?? farm.humidity,
        SensorType.soilMoisture:
            (data['soilMoisture'] as num?)?.toDouble() ?? farm.soilMoisture,
        SensorType.pressure:
            (data['pressure'] as num?)?.toDouble() ?? farm.pressure,
        SensorType.rain:
            (data['rain'] as num?)?.toDouble() ?? farm.rain,
      };

      final metrics = <SensorType, SensorMetric>{
        for (final type in kSensorOrder)
          type: farm.metric(type).copyWith(
            value: sensorValues[type]!,
            updatedAt: now,
            history: [
              ...farm.metric(type).history,
              TimePoint(now, sensorValues[type]!),
            ],
          ),
      };

      _updateFarm(
        farm.copyWith(
          metrics: metrics,
          lastSync: now,
        ),
      );

      debugPrint('Data Firebase berhasil memperbarui Dashboard: $data');
    },
    onError: (error) {
      debugPrint('Gagal membaca Firebase: $error');
    },
  );
}

  /// Menghasilkan satu siklus pembacaan sensor baru.
  ///
  /// Dipanggil otomatis oleh timer di [startLive], dan dipakai oleh test
  /// untuk memverifikasi logika irigasi tanpa menunggu waktu nyata.
  void simulateTick() {
    final rnd = Random();
    final now = DateTime.now();

    _farms = _farms.map((farm) {
      final metrics = <SensorType, SensorMetric>{};
      for (final type in kSensorOrder) {
        final current = farm.metric(type);
        final span = switch (type) {
          SensorType.soilMoisture => 1.4,
          SensorType.temperature => 0.4,
          SensorType.humidity => 0.8,
          SensorType.pressure => 0.3,
          SensorType.rain => 0.4,
        };
        var next = current.value + (rnd.nextDouble() - 0.45) * span;
        next = next.clamp(_floorOf(type), _ceilOf(type));
        next = double.parse(next.toStringAsFixed(1));

        final history = <TimePoint>[...current.history, TimePoint(now, next)];
        while (history.length > 24) {
          history.removeAt(0);
        }
        metrics[type] = current.copyWith(value: next, history: history, updatedAt: now);
      }
      var updated = farm.copyWith(metrics: metrics, lastSync: now);
      updated = _applyAutoIrrigation(updated);
      _checkLowMoisture(updated);
      return updated;
    }).toList();

    notifyListeners();
  }

  double _floorOf(SensorType type) => switch (type) {
        SensorType.soilMoisture => 5,
        SensorType.temperature => 12,
        SensorType.humidity => 25,
        SensorType.pressure => 995,
        SensorType.rain => 0,
      };

  double _ceilOf(SensorType type) => switch (type) {
        SensorType.soilMoisture => 95,
        SensorType.temperature => 42,
        SensorType.humidity => 98,
        SensorType.pressure => 1025,
        SensorType.rain => 25,
      };

  /// Logika irigasi otomatis: nyalakan pompa bila tanah di bawah ambang,
  /// matikan bila sudah cukup basah.
  Farm _applyAutoIrrigation(Farm farm) {
    if (!farm.autoIrrigation) return farm;
    final moisture = farm.soilMoisture;
    if (!farm.pumpOn && moisture < farm.moistureThreshold) {
      _addLog(farm, 'Otomatis');
      _pushAlert(
        AlertItem(
          id: _newId('alert'),
          farmId: farm.id,
          title: 'Irigasi otomatis aktif',
          message: 'Kelembapan tanah ${moisture.toStringAsFixed(0)}% < ambang '
              '${farm.moistureThreshold.toStringAsFixed(0)}%. Pompa dinyalakan '
              'selama ${farm.irrigationDurationMinutes} menit.',
          level: AlertLevel.warning,
          time: DateTime.now(),
        ),
      );
      return farm.copyWith(pumpOn: true);
    }
    if (farm.pumpOn && moisture > farm.moistureThreshold + 15) {
      return farm.copyWith(pumpOn: false);
    }
    return farm;
  }

  void _checkLowMoisture(Farm farm) {
    if (farm.soilMoisture >= farm.moistureThreshold) return;
    if (farm.autoIrrigation) return; // sudah ditangani irigasi otomatis
    final already =
        _alerts.any((a) => a.farmId == farm.id && !a.read && a.title == 'Tanah kering');
    if (already) return;
    _pushAlert(
      AlertItem(
        id: _newId('alert'),
        farmId: farm.id,
        title: 'Tanah kering',
        message: 'Kelembapan tanah ${farm.soilMoisture.toStringAsFixed(0)}% di bawah '
            'ambang ${farm.moistureThreshold.toStringAsFixed(0)}%. Pertimbangkan menyiram.',
        level: AlertLevel.warning,
        time: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Irigasi
  // ---------------------------------------------------------------------------

  void togglePump() {
    _updateFarm(selectedFarm.copyWith(pumpOn: !selectedFarm.pumpOn));
    if (selectedFarm.pumpOn) {
      _addLog(selectedFarm, 'Manual');
    }
    NotificationService.toast(
      selectedFarm.pumpOn ? 'Pompa dinyalakan (manual)' : 'Pompa dimatikan',
    );
  }

  void runIrrigation({int? minutes}) {
    final farm = selectedFarm;
    _addLog(farm, 'Manual');
    _pushAlert(
      AlertItem(
        id: _newId('alert'),
        farmId: farm.id,
        title: 'Penyiraman manual dimulai',
        message: 'Pompa menyala ${minutes ?? farm.irrigationDurationMinutes} menit.',
        level: AlertLevel.info,
        time: DateTime.now(),
      ),
    );
    NotificationService.toast('Penyiraman dimulai…');
  }

  void setAutoIrrigation(bool value) {
    _updateFarm(selectedFarm.copyWith(autoIrrigation: value));
  }

  void setMoistureThreshold(double value) {
    _updateFarm(selectedFarm.copyWith(moistureThreshold: value));
  }

  void setIrrigationDuration(double value) {
    _updateFarm(selectedFarm.copyWith(irrigationDurationMinutes: value.round()));
  }

  void _addLog(Farm farm, String trigger) {
    _irrigationLogs.add(
      IrrigationLog(
        id: _newId('log'),
        farmId: farm.id,
        time: DateTime.now(),
        durationMinutes: farm.irrigationDurationMinutes,
        trigger: trigger,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Jadwal
  // ---------------------------------------------------------------------------

  void toggleSchedule(String id) {
    _schedules = _schedules
        .map((s) => s.id == id ? s.copyWith(enabled: !s.enabled) : s)
        .toList();
    notifyListeners();
  }

  void addSchedule(IrrigationSchedule schedule) {
    _schedules = <IrrigationSchedule>[..._schedules, schedule];
    notifyListeners();
  }

  void removeSchedule(String id) {
    _schedules = _schedules.where((s) => s.id != id).toList();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Tugas perawatan
  // ---------------------------------------------------------------------------

  void toggleTask(String id) {
    _tasks = _tasks.map((t) => t.id == id ? t.copyWith(done: !t.done) : t).toList();
    notifyListeners();
  }

  void addTask(PlantTask task) {
    _tasks = <PlantTask>[..._tasks, task];
    notifyListeners();
  }

  void removeTask(String id) {
    _tasks = _tasks.where((t) => t.id != id).toList();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lahan
  // ---------------------------------------------------------------------------

  void addFarm({required String name, required String crop, required String location}) {
    final farm = Farm(
      id: _newId('farm'),
      name: name,
      location: location,
      crop: crop,
      areaHectare: 0.5,
      ownerName: _user?.name ?? 'Petani',
      members: <String>[_user?.name ?? 'Petani'],
      metrics: <SensorType, SensorMetric>{
        for (final type in kSensorOrder)
          type: SensorMetric(
            type: type,
            value: type == SensorType.pressure ? 1010 : 50,
            history: const <TimePoint>[],
            updatedAt: DateTime.now(),
          ),
      },
      pumpOn: false,
      autoIrrigation: false,
      moistureThreshold: 45,
      irrigationDurationMinutes: 10,
      lastSync: DateTime.now(),
    );
    _farms = <Farm>[..._farms, farm];
    _selectedFarmId = farm.id;
    NotificationService.toast('Lahan "$name" ditambahkan');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Peringatan
  // ---------------------------------------------------------------------------

  void markAlertRead(String id) {
    _alerts = _alerts.map((a) => a.id == id ? a.copyWith(read: true) : a).toList();
    notifyListeners();
  }

  void markAllAlertsRead() {
    _alerts = _alerts.map((a) => a.copyWith(read: true)).toList();
    notifyListeners();
  }

  void _pushAlert(AlertItem alert) {
    _alerts = <AlertItem>[alert, ..._alerts];
    NotificationService.show(alert);
  }

  // ---------------------------------------------------------------------------
  // Chatbot
  // ---------------------------------------------------------------------------

  void _seedChat() {
    _chat.add(
      ChatMessage(
        id: _newId('msg'),
        text: 'Halo! Saya asisten AI smart farming Anda. Saya membaca data sensor '
            'secara langsung. Tanya soal kelembapan, irigasi, hama, atau jadwal perawatan.',
        fromUser: false,
        time: DateTime.now(),
      ),
    );
  }

  Future<void> sendChat(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _chat.add(
      ChatMessage(id: _newId('msg'), text: trimmed, fromUser: true, time: DateTime.now()),
    );
    _busy = true;
    notifyListeners();

    final reply = await ai.reply(trimmed, farm: selectedFarm);

    _chat.add(
      ChatMessage(id: _newId('msg'), text: reply, fromUser: false, time: DateTime.now()),
    );
    _busy = false;
    notifyListeners();
  }

  void clearChat() {
    _chat.clear();
    _seedChat();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  void _updateFarm(Farm farm) {
    _farms = _farms.map((f) => f.id == farm.id ? farm : f).toList();
    notifyListeners();
  }

  String _newId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
