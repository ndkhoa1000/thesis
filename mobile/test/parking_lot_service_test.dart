import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_app/src/features/parking_lot_registration/data/parking_lot_service.dart';
import 'package:parking_app/src/shared/media/media_picker_service.dart';

void main() {
  test(
    'BackendParkingLotService submits multipart payload with selected image',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'parking-lot-service',
      );
      final imageFile = File('${tempDir.path}/cover.jpg');
      await imageFile.writeAsBytes(const [1, 2, 3, 4]);

      final dio = Dio();
      Object? lastData;
      RequestOptions? lastRequestOptions;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastData = options.data;
            lastRequestOptions = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': 7,
                  'lot_owner_id': 1,
                  'name': 'Bai xe Ben Thanh',
                  'address': '45 Le Loi, Quan 1',
                  'latitude': 10.7729,
                  'longitude': 106.6983,
                  'current_available': 0,
                  'status': 'PENDING',
                  'cover_image': 'https://media.example/cover.jpg',
                },
              ),
            );
          },
        ),
      );
      final service = BackendParkingLotService(dio: dio, accessToken: 'token');

      final result = await service.createParkingLot(
        name: 'Bai xe Ben Thanh',
        address: '45 Le Loi, Quan 1',
        latitude: 10.7729,
        longitude: 106.6983,
        description: 'Co camera',
        coverImageFile: SelectedMediaFile(
          path: imageFile.path,
          fileName: 'cover.jpg',
        ),
      );

      final payload = lastData;
      expect(payload, isA<FormData>());
      final formData = payload! as FormData;
      expect(formData.fields.any((field) => field.key == 'name'), isTrue);
      expect(
        formData.files.any((entry) => entry.key == 'cover_image_file'),
        isTrue,
      );
      expect(lastRequestOptions?.headers['Authorization'], 'Bearer token');
      expect(result.coverImage, 'https://media.example/cover.jpg');

      await tempDir.delete(recursive: true);
    },
  );

  test('BackendParkingLotService surfaces backend upload errors', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                data: {'detail': 'Tải ảnh đại diện thất bại.'},
              ),
            ),
          );
        },
      ),
    );
    final service = BackendParkingLotService(dio: dio, accessToken: 'token');

    expect(
      () => service.createParkingLot(
        name: 'Bai xe Ben Thanh',
        address: '45 Le Loi, Quan 1',
        latitude: 10.7729,
        longitude: 106.6983,
        description: 'Co camera',
      ),
      throwsA(
        isA<ParkingLotException>().having(
          (error) => error.message,
          'message',
          'Tải ảnh đại diện thất bại.',
        ),
      ),
    );
  });
}
