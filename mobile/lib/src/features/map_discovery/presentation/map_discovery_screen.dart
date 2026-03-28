import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../lot_details/data/lot_details_service.dart';
import '../../lot_details/presentation/lot_details_sheet.dart';
import '../data/map_discovery_service.dart';

typedef DriverMapCanvasBuilder =
    Widget Function(BuildContext context, MapDiscoveryViewData viewData);

class MapDiscoveryViewport {
  const MapDiscoveryViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final double zoom;
}

class MapDiscoveryViewData {
  const MapDiscoveryViewData({
    required this.lots,
    required this.clusterEnabled,
    required this.locationDenied,
    required this.defaultViewport,
  });

  final List<MapDiscoveryLotSummary> lots;
  final bool clusterEnabled;
  final bool locationDenied;
  final MapDiscoveryViewport defaultViewport;
}

abstract class MapLocationPermissionService {
  Future<bool> requestAccess();
}

class DeviceMapLocationPermissionService
    implements MapLocationPermissionService {
  const DeviceMapLocationPermissionService();

  @override
  Future<bool> requestAccess() async {
    final statuses = await [
      Permission.location,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.any((status) => status.isGranted);
  }
}

class MapDiscoveryScreen extends StatefulWidget {
  const MapDiscoveryScreen({
    super.key,
    required this.mapDiscoveryService,
    required this.lotDetailsService,
    required this.onOpenDriverCheckIn,
    required this.onOpenVehicles,
    required this.onSignOut,
    this.onOpenLotOwnerApplication,
    this.onOpenOperatorApplication,
    this.locationPermissionService = const DeviceMapLocationPermissionService(),
    this.mapCanvasBuilder = defaultDriverMapCanvasBuilder,
  });

  final MapDiscoveryService mapDiscoveryService;
  final LotDetailsService lotDetailsService;
  final Future<void> Function() onOpenDriverCheckIn;
  final Future<void> Function() onOpenVehicles;
  final Future<void> Function() onSignOut;
  final VoidCallback? onOpenLotOwnerApplication;
  final VoidCallback? onOpenOperatorApplication;
  final MapLocationPermissionService locationPermissionService;
  final DriverMapCanvasBuilder mapCanvasBuilder;

  @override
  State<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends State<MapDiscoveryScreen> {
  static const _defaultViewport = MapDiscoveryViewport(
    latitude: 10.7730,
    longitude: 106.7030,
    zoom: 14.5,
  );

  List<MapDiscoveryLotSummary> _lots = const [];
  bool _isLoading = true;
  bool _locationDenied = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locationGranted = await widget.locationPermissionService
          .requestAccess();
      final lots = await widget.mapDiscoveryService.fetchActiveLots();
      if (!mounted) {
        return;
      }
      setState(() {
        _locationDenied = !locationGranted;
        _lots = lots;
        _isLoading = false;
      });
    } on MapDiscoveryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _openLotDetails(MapDiscoveryLotSummary lot) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LotDetailsSheet(
        lotId: lot.id,
        lotName: lot.name,
        lotDetailsService: widget.lotDetailsService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewData = MapDiscoveryViewData(
      lots: _lots,
      clusterEnabled: true,
      locationDenied: _locationDenied,
      defaultViewport: _defaultViewport,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ bãi xe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_outlined),
            tooltip: 'Mã check-in',
            onPressed: widget.onOpenDriverCheckIn,
          ),
          IconButton(
            icon: const Icon(Icons.directions_car_outlined),
            tooltip: 'Xe của tôi',
            onPressed: widget.onOpenVehicles,
          ),
          if (widget.onOpenLotOwnerApplication != null)
            IconButton(
              icon: const Icon(Icons.storefront_outlined),
              tooltip: 'Chủ bãi',
              onPressed: widget.onOpenLotOwnerApplication,
            ),
          if (widget.onOpenOperatorApplication != null)
            IconButton(
              icon: const Icon(Icons.settings_suggest_outlined),
              tooltip: 'Operator',
              onPressed: widget.onOpenOperatorApplication,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: _errorMessage != null
          ? _MapDiscoveryErrorState(
              message: _errorMessage!,
              onRetry: _bootstrap,
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: widget.mapCanvasBuilder(context, viewData),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_locationDenied)
                        const _MapDiscoveryNotice(
                          message:
                              'Bản đồ đang hiển thị vị trí mặc định của TP.HCM vì ứng dụng chưa được cấp quyền truy cập vị trí.',
                        ),
                      const SizedBox(height: 8),
                      _MapDiscoverySummaryCard(lotCount: _lots.length),
                    ],
                  ),
                ),
                if (_lots.isEmpty && !_isLoading)
                  const Center(child: _MapDiscoveryEmptyState()),
                if (_lots.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: SizedBox(
                      height: 156,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _lots.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final lot = _lots[index];
                          return _LotQuickCard(
                            lot: lot,
                            onTap: () => _openLotDetails(lot),
                          );
                        },
                      ),
                    ),
                  ),
                if (_isLoading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MapDiscoverySummaryCard extends StatelessWidget {
  const _MapDiscoverySummaryCard({required this.lotCount});

  final int lotCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$lotCount bãi đang hoạt động',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _LegendChip(label: 'Xanh: còn nhiều', color: Color(0xFF2E7D32)),
                _LegendChip(label: 'Cam: sắp đầy', color: Color(0xFFEF6C00)),
                _LegendChip(label: 'Đỏ: hết chỗ', color: Color(0xFFC62828)),
                _LegendChip(
                  label: 'Xanh dương: cụm khi thu nhỏ',
                  color: Color(0xFF1565C0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _MapDiscoveryNotice extends StatelessWidget {
  const _MapDiscoveryNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE08A)),
        ),
        child: Text(message),
      ),
    );
  }
}

class _MapDiscoveryEmptyState extends StatelessWidget {
  const _MapDiscoveryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Hiện chưa có bãi xe đang hoạt động để hiển thị trên bản đồ.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _MapDiscoveryErrorState extends StatelessWidget {
  const _MapDiscoveryErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _LotQuickCard extends StatelessWidget {
  const _LotQuickCard({required this.lot, required this.onTap});

  final MapDiscoveryLotSummary lot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 252,
      child: Card(
        child: InkWell(
          key: ValueKey('lotCard:${lot.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lot.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(lot.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Row(
                  children: [
                    Chip(label: Text(lot.availabilityText)),
                    const Spacer(),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget defaultDriverMapCanvasBuilder(
  BuildContext context,
  MapDiscoveryViewData viewData,
) {
  return _MapboxLotCanvas(viewData: viewData);
}

Widget defaultDriverMapFallbackCanvasBuilder(
  BuildContext context,
  MapDiscoveryViewData viewData,
) {
  return DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFE3F2FD), Color(0xFFF5F5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: Color(0xFF1565C0)),
            const SizedBox(height: 16),
            Text(
              'Bản đồ tương tác đang ở chế độ fallback vì workspace chưa có MAPBOX_ACCESS_TOKEN.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn vẫn có thể xem ${viewData.lots.length} bãi đang hoạt động và mở chi tiết từ danh sách bên dưới.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapboxLotCanvas extends StatefulWidget {
  const _MapboxLotCanvas({required this.viewData});

  final MapDiscoveryViewData viewData;

  @override
  State<_MapboxLotCanvas> createState() => _MapboxLotCanvasState();
}

class _MapboxLotCanvasState extends State<_MapboxLotCanvas> {
  static const _sourceId = 'driver-lot-source';
  static const _clusterLayerId = 'driver-lot-clusters';
  static const _clusterCountLayerId = 'driver-lot-cluster-count';
  static const _lotCircleLayerId = 'driver-lot-points';
  static const _lotCountLayerId = 'driver-lot-point-count';

  MapboxMap? _mapboxMap;
  bool _styleLoaded = false;

  @override
  void didUpdateWidget(covariant _MapboxLotCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewData.lots != widget.viewData.lots ||
        oldWidget.viewData.locationDenied != widget.viewData.locationDenied) {
      _syncMapState();
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(
            widget.viewData.defaultViewport.longitude,
            widget.viewData.defaultViewport.latitude,
          ),
        ),
        zoom: widget.viewData.defaultViewport.zoom,
        pitch: 0,
        bearing: 0,
      ),
    );
    _syncMapState();
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    _styleLoaded = true;
    _syncMapState();
  }

  Future<void> _syncMapState() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }

    mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: !widget.viewData.locationDenied,
        pulsingEnabled: !widget.viewData.locationDenied,
      ),
    );

    if (!_styleLoaded) {
      return;
    }

    final style = mapboxMap.style;
    final sourceData = _buildGeoJson(widget.viewData.lots);
    if (await style.styleSourceExists(_sourceId)) {
      final source = await style.getSource(_sourceId);
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(sourceData);
      } else {
        await style.removeStyleSource(_sourceId);
        await style.addSource(
          GeoJsonSource(
            id: _sourceId,
            data: sourceData,
            cluster: widget.viewData.clusterEnabled,
            clusterMaxZoom: 14,
            clusterRadius: 50,
          ),
        );
      }
    } else {
      await style.addSource(
        GeoJsonSource(
          id: _sourceId,
          data: sourceData,
          cluster: widget.viewData.clusterEnabled,
          clusterMaxZoom: 14,
          clusterRadius: 50,
        ),
      );
    }

    await _ensureLayer(style, _clusterLayerId, _clusterLayerSpec());
    await _ensureLayer(style, _clusterCountLayerId, _clusterCountLayerSpec());
    await _ensureLayer(style, _lotCircleLayerId, _lotCircleLayerSpec());
    await _ensureLayer(style, _lotCountLayerId, _lotCountLayerSpec());
  }

  Future<void> _ensureLayer(
    StyleManager style,
    String layerId,
    Map<String, dynamic> layerSpec,
  ) async {
    if (!await style.styleLayerExists(layerId)) {
      await style.addStyleLayer(jsonEncode(layerSpec), null);
    }
  }

  String _buildGeoJson(List<MapDiscoveryLotSummary> lots) {
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': lots
          .map(
            (lot) => {
              'type': 'Feature',
              'id': lot.id,
              'properties': {
                'lot_id': lot.id,
                'name': lot.name,
                'address': lot.address,
                'current_available': lot.currentAvailable,
                'marker_count_label': lot.markerCountLabel,
              },
              'geometry': {
                'type': 'Point',
                'coordinates': [lot.longitude, lot.latitude],
              },
            },
          )
          .toList(growable: false),
    });
  }

  Map<String, dynamic> _clusterLayerSpec() {
    return {
      'id': _clusterLayerId,
      'type': 'circle',
      'source': _sourceId,
      'filter': ['has', 'point_count'],
      'paint': {
        'circle-color': '#1565C0',
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          18,
          10,
          24,
          25,
          30,
        ],
        'circle-opacity': 0.88,
      },
    };
  }

  Map<String, dynamic> _clusterCountLayerSpec() {
    return {
      'id': _clusterCountLayerId,
      'type': 'symbol',
      'source': _sourceId,
      'filter': ['has', 'point_count'],
      'layout': {
        'text-field': '{point_count_abbreviated}',
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12,
      },
      'paint': {'text-color': '#FFFFFF'},
    };
  }

  Map<String, dynamic> _lotCircleLayerSpec() {
    return {
      'id': _lotCircleLayerId,
      'type': 'circle',
      'source': _sourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      'paint': {
        'circle-color': [
          'case',
          [
            '<=',
            ['get', 'current_available'],
            0,
          ],
          '#C62828',
          [
            '<=',
            ['get', 'current_available'],
            5,
          ],
          '#EF6C00',
          '#2E7D32',
        ],
        'circle-radius': 18,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#FFFFFF',
      },
    };
  }

  Map<String, dynamic> _lotCountLayerSpec() {
    return {
      'id': _lotCountLayerId,
      'type': 'symbol',
      'source': _sourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      'layout': {
        'text-field': '{marker_count_label}',
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12,
      },
      'paint': {'text-color': '#FFFFFF'},
    };
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('driverMapWidget'),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
