import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farming/models/models.dart';
import 'package:smart_farming/state/app_state.dart';

void main() {
  late AppState state;

  setUp(() {
    state = AppState(enableFirebase: false);
    state.stopLive();
  });

  tearDown(() => state.dispose());

  group('Autentikasi', () {
    test('login mengisi user dan menandai sudah masuk', () {
      expect(state.isLoggedIn, isFalse);

      state.setUserForTesting(
        email: 'tani@example.com',
        name: 'Pak Tani',
      );

      expect(state.isLoggedIn, isTrue);
      expect(state.user!.name, 'Pak Tani');
      expect(state.user!.initials, 'PT');
    });

    test('logout menghapus sesi', () {
      state.setUserForTesting(
        email: 'a@b.com',
        name: 'A B',
      );

      state.logout();

      expect(state.isLoggedIn, isFalse);
      expect(state.user, isNull);
    });
  });

  group('Multi lahan', () {
    test('memilih lahan mengganti konteks dashboard', () {
      final first = state.selectedFarm;
      final other = state.farms.firstWhere((f) => f.id != first.id);

      state.selectFarm(other.id);

      expect(state.selectedFarm.id, other.id);
    });

    test('menambah lahan baru langsung terpilih', () {
      final before = state.farms.length;

      state.addFarm(
        name: 'Kebun Cabai',
        crop: 'Cabai',
        location: 'Bogor',
      );

      expect(state.farms.length, before + 1);
      expect(state.selectedFarm.name, 'Kebun Cabai');
      expect(state.selectedFarm.crop, 'Cabai');
    });
  });

  group('Irigasi', () {
    test('togglePump membalik status pompa', () {
      final before = state.selectedFarm.pumpOn;

      state.togglePump();

      expect(state.selectedFarm.pumpOn, !before);
    });

    test('irigasi otomatis menyalakan pompa saat tanah di bawah ambang', () {
      state.selectFarm('farm-a');
      state.setAutoIrrigation(false);
      state.setMoistureThreshold(80);
      state.setAutoIrrigation(true);

      expect(state.selectedFarm.pumpOn, isFalse);

      state.simulateTick();

      expect(state.selectedFarm.pumpOn, isTrue);
      expect(
        state.alerts.any((a) => a.title == 'Irigasi otomatis aktif'),
        isTrue,
      );
    });

    test('durasi penyiraman tersimpan sebagai angka bulat', () {
      state.setIrrigationDuration(12.6);

      expect(state.selectedFarm.irrigationDurationMinutes, 13);
    });
  });

  group('Jadwal & tugas', () {
    test('addSchedule menambah jadwal ke lahan aktif', () {
      final before = state.schedules.length;

      state.addSchedule(
        IrrigationSchedule(
          id: 'uji-1',
          farmId: state.selectedFarm.id,
          label: 'Uji jadwal',
          hour: 7,
          minute: 15,
          durationMinutes: 8,
          enabled: true,
        ),
      );

      expect(state.schedules.length, before + 1);

      final added = state.schedules.firstWhere((s) => s.id == 'uji-1');

      expect(added.timeLabel, '07:15');
      expect(added.dayLabel, 'Setiap hari');
    });

    test('toggleSchedule membalik status aktif', () {
      final schedule = state.schedules.first;

      state.toggleSchedule(schedule.id);

      final updated =
          state.schedules.firstWhere((s) => s.id == schedule.id);

      expect(updated.enabled, !schedule.enabled);
    });

    test('toggleTask menandai tugas selesai', () {
      final task = state.tasks.first;

      state.toggleTask(task.id);

      final updated = state.tasks.firstWhere((t) => t.id == task.id);

      expect(updated.done, !task.done);
    });
  });

  group('Peringatan', () {
    test('markAllAlertsRead menghapus hitungan belum dibaca', () {
      expect(state.unreadAlertCount, greaterThan(0));

      state.markAllAlertsRead();

      expect(state.unreadAlertCount, 0);
    });
  });

  group('Chatbot', () {
    test('sendChat menambah pesan pengguna dan balasan asisten', () async {
      final before = state.chat.length;

      await state.sendChat('apakah tanahnya perlu disiram?');

      expect(state.chat.length, before + 2);
      expect(state.chat[state.chat.length - 2].fromUser, isTrue);

      final reply = state.chat.last;

      expect(reply.fromUser, isFalse);
      expect(reply.text.toLowerCase(), contains('kelembapan'));
      expect(state.busy, isFalse);
    });

    test('pesan kosong tidak menambah apa pun', () async {
      final before = state.chat.length;

      await state.sendChat('   ');

      expect(state.chat.length, before);
    });
  });
}