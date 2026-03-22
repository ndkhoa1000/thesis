import { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { WebView } from 'react-native-webview';
import { env, hasMapboxPublicToken } from '@/lib/env';
import { supabase } from '@/lib/supabase';
import { Tables } from '@/lib/database.types';

type ParkingLot = Tables<'parking_lots'>;

function buildMapHtml(lots: ParkingLot[], mapboxToken: string): string {
  const lotsJson = JSON.stringify(lots);
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <link href="https://api.mapbox.com/mapbox-gl-js/v3.3.0/mapbox-gl.css" rel="stylesheet" />
  <script src="https://api.mapbox.com/mapbox-gl-js/v3.3.0/mapbox-gl.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { width: 100vw; height: 100vh; overflow: hidden; font-family: -apple-system, sans-serif; }
    #map { width: 100%; height: 100%; }
    .mapboxgl-popup-content {
      border-radius: 14px;
      padding: 14px 16px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.15);
      min-width: 200px;
    }
    .lot-name { font-size: 15px; font-weight: 700; color: #0f172a; margin: 0 0 4px; }
    .lot-addr { font-size: 12px; color: #64748b; margin: 0 0 12px; }
    .lot-stats { display: flex; justify-content: space-around; }
    .stat { text-align: center; }
    .stat-val { font-size: 20px; font-weight: 700; color: #0ea5e9; line-height: 1.2; }
    .stat-lbl { font-size: 11px; color: #94a3b8; }
    .marker {
      background: white;
      border: 2.5px solid #0ea5e9;
      border-radius: 50%;
      width: 36px; height: 36px;
      display: flex; align-items: center; justify-content: center;
      font-size: 18px;
      cursor: pointer;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    mapboxgl.accessToken = '${mapboxToken}';
    const map = new mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/streets-v12',
      center: [106.7009, 10.7769],
      zoom: 13
    });

    map.addControl(new mapboxgl.NavigationControl(), 'top-right');

    const lots = ${lotsJson};
    let activePopup = null;

    lots.forEach(lot => {
      const el = document.createElement('div');
      el.className = 'marker';
      el.innerHTML = '🅿️';

      const popup = new mapboxgl.Popup({ offset: 20, closeButton: true })
        .setHTML(\`
          <p class="lot-name">\${lot.name}</p>
          <p class="lot-addr">\${lot.address}</p>
          <div class="lot-stats">
            <div class="stat">
              <div class="stat-val">\${lot.available_spots}</div>
              <div class="stat-lbl">Chỗ trống</div>
            </div>
            <div class="stat">
              <div class="stat-val">\${lot.capacity}</div>
              <div class="stat-lbl">Sức chứa</div>
            </div>
            <div class="stat">
              <div class="stat-val">\${(lot.base_price_per_hour / 1000).toFixed(0)}k</div>
              <div class="stat-lbl">₫/giờ</div>
            </div>
          </div>
        \`);

      new mapboxgl.Marker(el)
        .setLngLat([lot.longitude, lot.latitude])
        .setPopup(popup)
        .addTo(map);
    });
  </script>
</body>
</html>
  `.trim();
}

export default function ParkingMap() {
  const [lots, setLots] = useState<ParkingLot[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const { data, error } = await supabase
        .from('parking_lots')
        .select('*')
        .eq('is_active', true);
      if (!error && data) setLots(data);
      setLoading(false);
    })();
  }, []);

  if (!hasMapboxPublicToken) {
    return (
      <View style={styles.feedbackContainer}>
        <Text style={styles.feedbackTitle}>Mapbox token is missing</Text>
        <Text style={styles.feedbackText}>
          Set EXPO_PUBLIC_MAPBOX_TOKEN in the mobile .env file to load the map.
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {loading ? (
        <View style={styles.loader}>
          <ActivityIndicator size="large" color="#0ea5e9" />
          <Text style={styles.loaderText}>Đang tải bản đồ...</Text>
        </View>
      ) : (
        <WebView
          source={{ html: buildMapHtml(lots, env.mapboxPublicToken) }}
          style={styles.webview}
          originWhitelist={['*']}
          javaScriptEnabled
          domStorageEnabled
          allowUniversalAccessFromFileURLs
          mixedContentMode="always"
        />
      )}

      {/* Top bar overlay */}
      <View style={styles.topBar}>
        <Text style={styles.topBarTitle}>🔍 Tìm bãi đỗ xe</Text>
        {loading && <ActivityIndicator size="small" color="#0ea5e9" />}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  webview: { flex: 1 },
  feedbackContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    backgroundColor: '#f8fafc',
  },
  feedbackTitle: { fontSize: 18, fontWeight: '700', color: '#0f172a', marginBottom: 8 },
  feedbackText: { fontSize: 14, textAlign: 'center', color: '#64748b' },
  loader: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
    backgroundColor: '#f8fafc',
  },
  loaderText: { fontSize: 14, color: '#64748b' },
  topBar: {
    position: 'absolute',
    top: 12,
    left: 12,
    right: 12,
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderRadius: 16,
    paddingVertical: 12,
    paddingHorizontal: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  topBarTitle: { fontSize: 15, fontWeight: '600', color: '#0f172a' },
});
