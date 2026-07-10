import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/main_don't%20look%20at%20this%20please.dart';

void main() {
  group('RadioController', () {
    test('selectStation updates the current station', () {
      final controller = RadioControllerProvider();

      controller.selectStation(2);

      expect(controller.selectedStationIndex, 2);
      expect(controller.currentStation.name, 'Joe Gold');
      expect(controller.currentStation.url, contains('joe-gold'));
    });
  });
}
