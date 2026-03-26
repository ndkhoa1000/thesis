import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/core/auth/token_store.dart';
import 'src/core/network/api_client.dart';
import 'src/features/auth/data/auth_service.dart';
import 'src/features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final mapboxToken =
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['ACCESS_TOKEN'];

  if (mapboxToken != null && mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }

  runApp(
    MyApp(
      authService: BackendAuthService(
        apiClient: ApiClient(),
        tokenStore: SecureTokenStore(),
      ),
    ),
  );
}

// ======================= MOCK DATA =======================
class ParkingLot {
  final String id;
  final String name;
  final String address;
  final int capacity;
  final int available;
  final double pricePerHour;
  final double lat;
  final double lng;

  ParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.capacity,
    required this.available,
    required this.pricePerHour,
    required this.lat,
    required this.lng,
  });
}

// Bãi xe ở khu vực trung tâm TPHCM (Quận 1)
final List<ParkingLot> mockParkingLots = [
  ParkingLot(
    id: "p1",
    name: "Bãi xe Bitexco Financial Tower",
    address: "2 Hải Triều, Bến Nghé, Quận 1, TPHCM",
    capacity: 200,
    available: 45,
    pricePerHour: 20000,
    lat: 10.7715,
    lng: 106.7044,
  ),
  ParkingLot(
    id: "p2",
    name: "Bãi xe Takashimaya",
    address: "92-94 Nam Kỳ Khởi Nghĩa, Bến Nghé, Quận 1, TPHCM",
    capacity: 500,
    available: 12,
    pricePerHour: 30000,
    lat: 10.7731,
    lng: 106.7013,
  ),
  ParkingLot(
    id: "p3",
    name: "Bãi tạm Phố đi bộ Nguyễn Huệ",
    address: "Nguyễn Huệ, Bến Nghé, Quận 1, TPHCM",
    capacity: 50,
    available: 0,
    pricePerHour: 15000,
    lat: 10.7745,
    lng: 106.7042,
  ),
];
// =========================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkingApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: AuthGate(
        authService: authService,
        authenticatedBuilder: (_) => const AuthenticatedHome(),
      ),
    );
  }
}

class AuthenticatedHome extends StatelessWidget {
  const AuthenticatedHome({super.key});

  @override
  Widget build(BuildContext context) {
    final mapboxToken =
        dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['ACCESS_TOKEN'];
    if (mapboxToken == null || mapboxToken.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ParkingApp')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Đăng ký thành công. Hãy thêm MAPBOX_ACCESS_TOKEN vào mobile/.env để bật bản đồ thử nghiệm.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return const MapScreen();
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  String currentStyle = MapboxStyles.STANDARD;

  // Lưu trữ map id -> thông tin ParkingLot để tra cứu khi ấn vào marker
  final Map<String, ParkingLot> annotationMap = {};

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.location, Permission.locationWhenInUse].request();
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    // Bật vị trí người dùng
    mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Khởi tạo Marker Manager
    pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    pointAnnotationManager?.addOnPointAnnotationClickListener(
      AnnotationClickListener(onAnnotationClick: _onMarkerClicked),
    );

    _addMockParkingMarkers();

    // Chuyển camera về khu vực có bãi đỗ xe (Q1, TPHCM)
    _resetCamera();
  }

  void _resetCamera() {
    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(106.703, 10.773)), // Kinh độ, vĩ độ
        zoom: 15.0,
        pitch: 0,
        bearing: 0,
      ),
    );
  }

  void _addMockParkingMarkers() async {
    annotationMap.clear();

    // Lặp qua mock data và vẽ lên map
    for (var lot in mockParkingLots) {
      final isFull = lot.available <= 0;

      final options = PointAnnotationOptions(
        geometry: Point(coordinates: Position(lot.lng, lot.lat)),
        textField: isFull ? "${lot.name} (Đầy)" : "${lot.name}",
        textColor: isFull ? Colors.red.value : Colors.teal.value,
        textOffset: [0.0, -2.0],
        iconImage: "marker-15",
        iconSize: 2.5,
      );

      final annotation = await pointAnnotationManager?.create(options);
      if (annotation != null) {
        // Lưu annotation.id và bãi giữ xe tương ứng vào map
        annotationMap[annotation.id] = lot;
      }
    }
  }

  // Handle click marker
  void _onMarkerClicked(PointAnnotation annotation) {
    final lot = annotationMap[annotation.id];
    if (lot != null) {
      _showParkingLotModal(lot);
    }
  }

  // Bottom Sheet hiển thị thông tin chi tiết bãi giữ xe
  void _showParkingLotModal(ParkingLot lot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isFull = lot.available <= 0;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      lot.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isFull
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFull ? "Hết chỗ" : "Còn ${lot.available} chỗ",
                      style: TextStyle(
                        color: isFull
                            ? Colors.red.shade900
                            : Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lot.address,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "${lot.pricePerHour.toInt()} VNĐ/giờ",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Sức chứa: ${lot.capacity} xe",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isFull
                      ? null
                      : () {
                          // Xử lý logic đặt chỗ ở đây
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đang xử lý đặt chỗ tại: ${lot.name}',
                              ),
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isFull ? 'Không thể đặt chỗ' : 'Đặt chỗ ngay',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _changeStyle() {
    if (mapboxMap != null) {
      setState(() {
        currentStyle = currentStyle == MapboxStyles.STANDARD
            ? MapboxStyles.SATELLITE_STREETS
            : MapboxStyles.STANDARD;
      });
      mapboxMap!.loadStyleURI(currentStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ParkingApp'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _changeStyle,
            tooltip: 'Đổi kiểu bản đồ',
          ),
        ],
      ),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,
        styleUri: currentStyle,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _resetCamera,
        tooltip: 'Trung tâm Quận 1',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

// Lớp wrapper nhỏ hỗ trợ bắt sự kiện click markers của Mapbox SDK v2
class AnnotationClickListener extends OnPointAnnotationClickListener {
  final void Function(PointAnnotation annotation) onAnnotationClick;

  AnnotationClickListener({required this.onAnnotationClick});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onAnnotationClick(annotation);
  }
}
