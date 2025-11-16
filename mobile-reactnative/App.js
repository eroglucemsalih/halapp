import React, { useEffect, useState } from 'react';
import { View, Text, Button, FlatList, SafeAreaView, ActivityIndicator, StyleSheet, TouchableOpacity } from 'react-native';
import * as Location from 'expo-location';
import { AdMobBanner } from 'expo-ads-admob';

// EDIT THIS: set your backend URL (use emulator host mapping if needed)
const BACKEND_URL = 'http://10.0.2.2:5000'; // Android emulator -> 10.0.2.2 ; iOS simulator can use localhost

export default function App() {
  const [loading, setLoading] = useState(true);
  const [location, setLocation] = useState(null);
  const [nearestData, setNearestData] = useState(null);
  const [markets, setMarkets] = useState([]);
  const [selectedMarket, setSelectedMarket] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    (async () => {
      setLoading(true);
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        setError('Location permission not granted');
        setLoading(false);
        return;
      }
      let loc = await Location.getCurrentPositionAsync({});
      setLocation(loc.coords);
      await fetchNearest(loc.coords.latitude, loc.coords.longitude);
      setLoading(false);
    })();
  }, []);

  async function fetchMarkets() {
    try {
      const res = await fetch(`${BACKEND_URL}/api/markets`);
      const json = await res.json();
      setMarkets(json.markets || []);
    } catch (e) {
      setError(e.message);
    }
  }

  async function fetchNearest(lat, lon) {
    try {
      const res = await fetch(`${BACKEND_URL}/api/prices?lat=${lat}&lon=${lon}`);
      const json = await res.json();
      if (json.nearby && json.nearby.length > 0) {
        setNearestData(json.nearby[0]);
      } else {
        setNearestData(null);
      }
    } catch (e) {
      setError(e.message);
    }
  }

  async function fetchMarketLatest(id) {
    try {
      const res = await fetch(`${BACKEND_URL}/api/market/${id}/latest`);
      const json = await res.json();
      setSelectedMarket({ id, rows: json.data || [] });
    } catch (e) {
      setError(e.message);
    }
  }

  if (loading) return (
    <SafeAreaView style={styles.container}><ActivityIndicator size="large" /></SafeAreaView>
  );

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>HAL Fiyatları</Text>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Konum</Text>
        <Text>Lat: {location?.latitude?.toFixed(6)} Lon: {location?.longitude?.toFixed(6)}</Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>En Yakın Hal</Text>
        {nearestData ? (
          <View>
            <Text style={styles.bold}>{nearestData.market.name}</Text>
            <FlatList
              data={nearestData.data}
              keyExtractor={(item, idx) => `${item.product || item['Ürün Adı']}-${idx}`}
              renderItem={({item}) => (
                <View style={styles.row}>
                  <Text style={styles.prod}>{item.product || item['Ürün Adı']}</Text>
                  <Text style={styles.price}>{item.price_min ?? item['En Düşük Fiyat (TL)']}</Text>
                </View>
              )}
            />
          </View>
        ) : (
          <Text>Veri bulunamadı.</Text>
        )}
      </View>

      <View style={styles.section}>
        <Button title="Diğer Halleri Gör" onPress={() => fetchMarkets()} />
        {markets.length > 0 && (
          <FlatList
            data={markets}
            keyExtractor={(m) => m.id}
            renderItem={({item}) => (
              <TouchableOpacity style={styles.marketRow} onPress={() => fetchMarketLatest(item.id)}>
                <Text style={styles.marketName}>{item.name}</Text>
                <Text style={styles.marketCoord}>{item.lat}, {item.lon}</Text>
              </TouchableOpacity>
            )}
          />
        )}
      </View>

      {selectedMarket && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Seçilen Hal: {selectedMarket.id}</Text>
          <FlatList
            data={selectedMarket.rows}
            keyExtractor={(item, i) => `${item.product || item['Ürün Adı']}-${i}`}
            renderItem={({item}) => (
              <View style={styles.row}>
                <Text style={styles.prod}>{item.product || item['Ürün Adı']}</Text>
                <Text style={styles.price}>{item.price_min ?? item['En Düşük Fiyat (TL)']}</Text>
              </View>
            )}
          />
        </View>
      )}

      <View style={styles.adContainer}>
        <AdMobBanner
          bannerSize="smartBannerPortrait"
          adUnitID="ca-app-pub-3940256099942544/6300978111" // TEST ID
          servePersonalizedAds={true}
          onDidFailToReceiveAdWithError={(err) => console.log('Ad error', err)}
        />
      </View>

    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 12 },
  title: { fontSize: 22, fontWeight: 'bold', marginBottom: 8 },
  section: { marginVertical: 8 },
  sectionTitle: { fontWeight: '600' },
  bold: { fontWeight: '700', fontSize: 16, marginBottom: 4 },
  row: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 6, borderBottomWidth: 1, borderBottomColor: '#eee' },
  prod: { flex: 1 },
  price: { marginLeft: 8, width: 100, textAlign: 'right' },
  marketRow: { padding: 8, borderBottomWidth: 1, borderBottomColor: '#ddd' },
  marketName: { fontWeight: '600' },
  marketCoord: { color: '#666' },
  adContainer: { marginTop: 12 },
  error: { color: 'red' }
});
