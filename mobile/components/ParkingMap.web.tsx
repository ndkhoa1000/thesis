import { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
// react-map-gl v8: must import from subpath 'react-map-gl/mapbox' for Mapbox token support
import MapboxMap, { Marker, Popup } from 'react-map-gl/mapbox';
import 'mapbox-gl/dist/mapbox-gl.css';
import { supabase } from '@/lib/supabase';
import { env, hasMapboxPublicToken } from '@/lib/env';
import { Tables } from '@/lib/database.types';

// HCMC center
const HCMC_LAT = 10.7769;
const HCMC_LNG = 106.7009;

export default function ParkingMap() {
  const [lots, setLots] = useState<Tables<'parking_lots'>[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<Tables<'parking_lots'> | null>(null);

  useEffect(() => {
    fetchLots();
  }, []);

  const fetchLots = async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('parking_lots')
      .select('*')
      .eq('is_active', true);
    if (!error && data) setLots(data);
    setLoading(false);
  };

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
      <MapboxMap
        mapboxAccessToken={env.mapboxPublicToken}
        initialViewState={{ longitude: HCMC_LNG, latitude: HCMC_LAT, zoom: 13 }}
        style={styles.map}
        mapStyle="mapbox://styles/mapbox/streets-v12"
      >
        {lots.map((lot) => (
          <Marker
            key={lot.id}
            longitude={lot.longitude}
            latitude={lot.latitude}
            onClick={(e: any) => {
              e.originalEvent?.stopPropagation();
              setSelected(selected?.id === lot.id ? null : lot);
            }}
          >
            <View style={styles.markerPin}>
              <Text style={styles.markerText}>🅿️</Text>
            </View>
          </Marker>
        ))}

        {selected && (
          <Popup
            longitude={selected.longitude}
            latitude={selected.latitude}
            anchor="bottom"
            onClose={() => setSelected(null)}
            closeOnClick={false}
            offset={28}
          >
            <div style={{ padding: '8px 12px', minWidth: 200 }}>
              <p style={{ fontWeight: 700, margin: '0 0 4px', fontSize: 14, color: '#0f172a' }}>
                {selected.name}
              </p>
              <p style={{ color: '#64748b', fontSize: 12, margin: '0 0 10px' }}>
                {selected.address}
              </p>
              <div style={{ display: 'flex', justifyContent: 'space-around', gap: 12 }}>
                <div style={{ textAlign: 'center' }}>
                  <p style={{ color: '#0ea5e9', fontWeight: 700, margin: 0, fontSize: 20 }}>
                    {selected.available_spots}
                  </p>
                  <p style={{ color: '#94a3b8', fontSize: 11, margin: 0 }}>Chỗ trống</p>
                </div>
                <div style={{ textAlign: 'center' }}>
                  <p style={{ color: '#0ea5e9', fontWeight: 700, margin: 0, fontSize: 20 }}>
                    {selected.capacity}
                  </p>
                  <p style={{ color: '#94a3b8', fontSize: 11, margin: 0 }}>Sức chứa</p>
                </div>
                <div style={{ textAlign: 'center' }}>
                  <p style={{ color: '#0ea5e9', fontWeight: 700, margin: 0, fontSize: 20 }}>
                    {(selected.base_price_per_hour / 1000).toFixed(0)}k
                  </p>
                  <p style={{ color: '#94a3b8', fontSize: 11, margin: 0 }}>₫/giờ</p>
                </div>
              </div>
            </div>
          </Popup>
        )}
      </MapboxMap>

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
  map: { flex: 1, width: '100%', height: '100%' } as any,
  feedbackContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    backgroundColor: '#f8fafc',
  },
  feedbackTitle: { fontSize: 18, fontWeight: '700', color: '#0f172a', marginBottom: 8 },
  feedbackText: { fontSize: 14, textAlign: 'center', color: '#64748b' },
  markerPin: {
    backgroundColor: 'white',
    padding: 6,
    borderRadius: 20,
    borderWidth: 2,
    borderColor: '#0ea5e9',
  } as any,
  markerText: { fontSize: 16 },
  topBar: {
    position: 'absolute',
    top: 12,
    left: 12,
    right: 12,
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderRadius: 16,
    padding: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  } as any,
  topBarTitle: { fontSize: 15, fontWeight: '600', color: '#0f172a' },
});
