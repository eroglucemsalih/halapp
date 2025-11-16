React Native (Expo) sample app

- Requests location permission on startup.
- Fetches nearest market via backend `/api/prices?lat=&lon=` and shows data.
- Can list other markets and fetch `/api/market/<id>/latest`.
- Includes AdMob test banner.

Setup
1. Install expo CLI: `npm install -g expo-cli` (if needed)
2. In this folder run: `npm install`
3. Set `BACKEND_URL` in `App.js` if your backend is not `http://10.0.2.2:5000`.
4. Run: `npm start` or `expo start`.

Notes
- Uses Expo AdMob test IDs. Replace with your own AdMob IDs for production.
- Android emulator: use `10.0.2.2` to reach host machine's `localhost`.
- iOS simulator: `localhost` typically works.
