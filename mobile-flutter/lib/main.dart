import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

const String BACKEND_URL = 'http://10.22.57.172:5000'; // device testing via phone hotspot

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hal Fiyatları',
      theme: ThemeData(primarySwatch: Colors.green),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Position? _position;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? nearest;
  List markets = [];
  Map<String, dynamic>? selectedMarket;
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      _appendDebug('Checking location permission...');
      LocationPermission permission = await Geolocator.checkPermission();
      _appendDebug('Current permission: $permission');
      if (permission == LocationPermission.denied) {
        _appendDebug('Requesting permission...');
        permission = await Geolocator.requestPermission();
        _appendDebug('Permission after request: $permission');
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() { _error = 'Location permission denied'; _loading=false; });
        _appendDebug('Permission denied (forever or denied)');
        return;
      }
      _appendDebug('Getting current position...');
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _position = pos; });
      _appendDebug('Got position: ${pos.latitude}, ${pos.longitude}');
      await _fetchNearest(pos.latitude, pos.longitude);
      setState(() { _loading = false; });
    } catch (e, st) {
      setState(() { _error = e.toString(); _loading = false; });
      _appendDebug('Exception during _initLocation: $e\n$st');
    }
  }

  Future<void> _fetchNearest(double lat, double lon) async {
    try {
      final res = await http.get(Uri.parse('$BACKEND_URL/api/prices?lat=$lat&lon=$lon'));
      final json = jsonDecode(res.body);
      if (json['nearby'] != null && json['nearby'].length > 0) {
        setState(() { nearest = json['nearby'][0]; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
  }

  Future<void> _fetchMarkets() async {
    try {
      final res = await http.get(Uri.parse('$BACKEND_URL/api/markets'));
      final json = jsonDecode(res.body);
      setState(() { markets = json['markets'] ?? []; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
  }

  Future<void> _pingBackend() async {
    try {
      _appendDebug('Pinging backend...');
      final res = await http.get(Uri.parse('$BACKEND_URL/api/markets')).timeout(Duration(seconds: 5));
      _appendDebug('Ping status: ${res.statusCode}');
      setState(() {});
    } catch (e) {
      _appendDebug('Ping failed: $e');
    }
  }

  void _appendDebug(String msg) {
    setState(() { _debugLog = '${DateTime.now().toIso8601String()} - $msg\n' + _debugLog; });
  }

  Future<void> _fetchMarketLatest(String id) async {
    try {
      final res = await http.get(Uri.parse('$BACKEND_URL/api/market/$id/latest'));
      final json = jsonDecode(res.body);
      setState(() { selectedMarket = {'id':id, 'rows': json['data'] ?? []}; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hal Fiyatları')),
      body: _loading ? Center(child: CircularProgressIndicator()) : Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
            // Debug header
            if (_debugLog.isNotEmpty) Container(
              color: Colors.black12,
              padding: EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Debug info (most recent first):', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(height: 80, child: SingleChildScrollView(child: Text(_debugLog, style: TextStyle(fontSize: 12))))
              ])
            ),
            Row(children: [
              ElevatedButton(onPressed: _pingBackend, child: Text('Ping backend')),
              SizedBox(width:8),
              ElevatedButton(onPressed: _fetchMarkets, child: Text('Listele')),
            ]),
          if (_error != null) Text(_error!, style: TextStyle(color: Colors.red)),
          Text('Konum: ${_position?.latitude?.toStringAsFixed(6)} , ${_position?.longitude?.toStringAsFixed(6)}'),
          SizedBox(height:8),
          if (nearest != null) ...[
            Text('En yakın: ${nearest!['market']['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: ListView.builder(
              itemCount: nearest!['data'].length,
              itemBuilder: (ctx, i) {
                final item = nearest!['data'][i];
                return ListTile(
                  title: Text(item['product'] ?? item['Ürün Adı'] ?? ''),
                  subtitle: Text('${item['price_min'] ?? item['En Düşük Fiyat (TL)']}'),
                );
              }
            ))
          ] else Text('Yakın hal verisi yok'),

          ElevatedButton(onPressed: _fetchMarkets, child: Text('Diğer Halleri Göster')),
          if (markets.isNotEmpty) Expanded(child: ListView.builder(
            itemCount: markets.length,
            itemBuilder: (ctx,i){ final m=markets[i]; return ListTile(title: Text(m['name']), subtitle: Text('${m['lat']}, ${m['lon']}'), onTap: () => _fetchMarketLatest(m['id'])); }
          )),

          if (selectedMarket != null) Expanded(child: ListView.builder(
            itemCount: (selectedMarket!['rows'] ?? []).length,
            itemBuilder: (ctx,i){ final item = selectedMarket!['rows'][i]; return ListTile(title: Text(item['product'] ?? item['Ürün Adı'] ?? ''), subtitle: Text('${item['price_min'] ?? item['En Düşük Fiyat (TL)']}')); }
          )),

          // Ads removed for build/test: the ad container was here.
        ]),
      ),
    );
  }
}
