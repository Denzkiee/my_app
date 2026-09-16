// Unit tests for the Clinic model, focusing on the establishment image
// handling added for clinic verification uploads.

import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/src/models/clinic.dart';

void main() {
  Map<String, dynamic> baseMap() => {
        'id': 'clinic-1',
        'owner_id': 'owner-1',
        'name': 'Bright Smile Dental',
        'description': 'Family dental clinic',
        'address': '123 Mabini St, Manila',
        'phone': '09171234567',
      };

  group('Clinic.establishmentImages', () {
    test('parses establishment image URLs from the database map', () {
      final clinic = Clinic.fromMap({
        ...baseMap(),
        'establishment_images': [
          'https://example.com/clinic-images/clinic-1/front.jpg',
          'https://example.com/clinic-images/clinic-1/reception.jpg',
        ],
      });

      expect(clinic.establishmentImages, hasLength(2));
      expect(
        clinic.establishmentImages.first,
        'https://example.com/clinic-images/clinic-1/front.jpg',
      );
      expect(clinic.hasEstablishmentImages, isTrue);
    });

    test('defaults to an empty list when the column is absent', () {
      final clinic = Clinic.fromMap(baseMap());

      expect(clinic.establishmentImages, isEmpty);
      expect(clinic.hasEstablishmentImages, isFalse);
    });

    test('defaults to an empty list when the column is null', () {
      final clinic = Clinic.fromMap({...baseMap(), 'establishment_images': null});

      expect(clinic.establishmentImages, isEmpty);
    });

    test('toMap includes establishment_images when images are present', () {
      const urls = ['https://example.com/a.jpg'];
      final clinic = Clinic(
        ownerId: 'owner-1',
        name: 'Bright Smile Dental',
        establishmentImages: urls,
      );

      expect(clinic.toMap()['establishment_images'], urls);
    });

    test('toMap omits establishment_images when there are no images', () {
      final clinic = Clinic(ownerId: 'owner-1', name: 'Bright Smile Dental');

      expect(clinic.toMap().containsKey('establishment_images'), isFalse);
    });

    test('survives a toMap/fromMap round trip', () {
      const urls = [
        'https://example.com/one.jpg',
        'https://example.com/two.jpg',
        'https://example.com/three.jpg',
      ];
      final original = Clinic(
        ownerId: 'owner-1',
        name: 'Bright Smile Dental',
        establishmentImages: urls,
      );

      final restored = Clinic.fromMap(original.toMap());

      expect(restored.establishmentImages, urls);
    });

    test('supports the 5 image maximum from the application screen', () {
      final urls = List.generate(5, (i) => 'https://example.com/$i.jpg');
      final clinic = Clinic(
        ownerId: 'owner-1',
        name: 'Bright Smile Dental',
        establishmentImages: urls,
      );

      expect(clinic.establishmentImages, hasLength(5));
      expect(clinic.hasEstablishmentImages, isTrue);
    });
  });

  group('Clinic.hasValidLocation', () {
    test('is true only when both latitude and longitude are set', () {
      final both = Clinic.fromMap({
        ...baseMap(),
        'latitude': 14.5995,
        'longitude': 120.9842,
      });
      expect(both.hasValidLocation, isTrue);

      final latitudeOnly = Clinic.fromMap({...baseMap(), 'latitude': 14.5995});
      expect(latitudeOnly.hasValidLocation, isFalse);

      final neither = Clinic.fromMap(baseMap());
      expect(neither.hasValidLocation, isFalse);
    });
  });
}