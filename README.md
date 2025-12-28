# 📱 HUREO HRIS App (Attendance Employee)
<img width="1920" height="960" alt="hureoprev" src="https://github.com/user-attachments/assets/7ca8dab1-d0c6-49ae-b67f-f30b65799973" />

Aplikasi mobile untuk absensi karyawan berbasis **Flutter**, terintegrasi dengan backend **Express.js** dan web admin **Vue.js**.  
Mendukung fitur check-in, check-out, validasi lokasi kantor (geofence), serta statistik kehadiran harian.

## 🚀 Fitur Utama
- **Login & Session Management** (JWT + SharedPreferences)
- **Absensi Online**
  - Check-in & Check-out dengan lokasi GPS
  - Validasi area perusahaan (geofence + radius)
  - Status *On Time* atau *Late* sesuai jam kerja perusahaan
- **Statistik Kehadiran**
  - Rekap jumlah hadir tepat waktu dan terlambat
- **Company Hours**
  - Sinkronisasi jam mulai & jam pulang dari server
- **Profile**
  - Data user + informasi perusahaan
  - Logout dengan konfirmasi dialog


## 🏗️ Arsitektur
- **Flutter App (Mobile)** → Aplikasi ini
- **Express.js Service (API & Attendance Logic)** → [attendance-service](https://github.com/viraalfita/attendance-service)
- **Vue.js Web Admin (Dashboard & Manajemen Karyawan)** → [my-attendance-app](https://github.com/viraalfita/my-attendance-app)


## 📦 Dependencies Penting
- [`geolocator`](https://pub.dev/packages/geolocator) → GPS & geofence
- [`intl`](https://pub.dev/packages/intl) → Format tanggal & waktu
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) → Simpan session user
- [`slide_to_act`](https://pub.dev/packages/slide_to_act) → Tombol geser untuk absensi
- [`url_launcher`](https://pub.dev/packages/url_launcher) → Buka Maps dari lokasi kantor


## ⚙️ Setup & Instalasi

1. **Clone repo Flutter**
   ```bash
   git clone <url-repo-flutter>
   cd attendance
    ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Jalankan di emulator/device**

   ```bash
   flutter run
   ```

4. **Konfigurasi API base URL**

   * Buka file: `lib/services/api_service.dart`
   * Ubah konstanta:

     ```dart
     static const String baseUrl = "http://localhost:5001/api";
     ```


## 🌐 Backend & Admin Panel

* **Express Service**: [hureo-service](https://github.com/viraalfita/hureo-service)
  Menyediakan API untuk login, attendance, company, dan leave.

* **Web Admin (Vue)**: [hureo-web](https://github.com/viraalfita/hureo-web)
  Untuk admin HR/owner dalam mengelola karyawan, jadwal, dan laporan absensi.

## 🛠️ Pengembangan

* Pastikan backend **attendance-service** sudah berjalan.
* Gunakan device nyata (bukan hanya emulator) untuk menguji GPS.
* Jalankan web admin untuk mengelola data perusahaan & karyawan.

