import 'package:betfriends/services/functions/functions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PingResult converte a resposta do systemPing', () {
    final result = PingResult.fromMap({
      'ok': true,
      'uid': 'user-123',
      'email': 'a@b.com',
      'emailVerified': false,
      'region': 'southamerica-east1',
      'serverTime': '2026-10-01T12:00:00.000Z',
    });

    expect(result.uid, 'user-123');
    expect(result.email, 'a@b.com');
    expect(result.region, kFunctionsRegion);
    expect(result.serverTime, DateTime.utc(2026, 10, 1, 12));
  });
}
