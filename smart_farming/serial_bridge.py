import serial
import json
import requests

# Konfigurasi ESP32 Receiver
PORT = "COM3"
BAUD_RATE = 115200

# Konfigurasi Firebase
FIREBASE_URL = (
    "https://subako-smart-farming-default-rtdb.firebaseio.com/"
    "sensors/ESP32-001.json"
)


def kirim_ke_firebase(data):
    """Mengirim data sensor ke Firebase Realtime Database."""

    payload = {
        "temperature": data["temperature"],
        "soilMoisture": data.get("soil_moisture", 0),
        "device_id": data.get("device_id", "ESP32-001"),
        "nomor": data.get("nomor", 0),
    }

    try:
        response = requests.patch(
            FIREBASE_URL,
            json=payload,
            timeout=10,
        )

        if response.ok:
            print("Firebase berhasil diperbarui:", payload)
        else:
            print(
                "Gagal mengirim ke Firebase:",
                response.status_code,
                response.text,
            )

    except requests.RequestException as error:
        print("Koneksi Firebase bermasalah:", error)


try:
    esp32 = serial.Serial(PORT, BAUD_RATE, timeout=2)

    print(f"Terhubung ke ESP32 Receiver di {PORT}")
    print("Menunggu data sensor...\n")

    while True:
        line = esp32.readline().decode(
            "utf-8", errors="ignore"
        ).strip()

        if not line:
            continue

        try:
            data = json.loads(line)

            if "temperature" in data:
                print("Data dari ESP32:", data)
                kirim_ke_firebase(data)

        except json.JSONDecodeError:
            print("Pesan:", line)

except serial.SerialException as error:
    print("Gagal membuka port serial:", error)

except KeyboardInterrupt:
    print("\nProgram dihentikan.")

finally:
    if "esp32" in locals() and esp32.is_open:
        esp32.close()