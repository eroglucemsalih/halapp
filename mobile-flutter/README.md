Flutter sample app

- Requests location permission on startup via `geolocator`.
- Fetches nearest market via backend `/api/prices?lat=&lon=` and shows data.
- Can list other markets and fetch `/api/market/<id>/latest`.
- Includes Google Mobile Ads test Banner.

Setup
1. Install Flutter SDK and tools.
2. From this folder run: `flutter pub get`.
3. Edit `main.dart` BACKEND_URL constant if needed.
4. Run on emulator/device: `flutter run`.

Notes
- Uses test ad units. Replace with your AdMob IDs in production.
- For Android emulator use `10.0.2.2` to reach host `localhost`.
