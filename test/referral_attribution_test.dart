import 'package:flutter_test/flutter_test.dart';
import 'package:ss_pay/services/referral_attribution.dart';

void main() {
  group('ReferralAttribution.parseReferralCode', () {
    test('parses ref=CODE', () {
      expect(
        ReferralAttribution.parseReferralCode('ref=INFLU0042'),
        'INFLU0042',
      );
    });

    test('parses encoded referrer', () {
      expect(
        ReferralAttribution.parseReferralCode('ref%3DINFLU99'),
        'INFLU99',
      );
    });

    test('parses utm_content fallback', () {
      expect(
        ReferralAttribution.parseReferralCode(
          'utm_source=influencer&utm_content=INFLU12',
        ),
        'INFLU12',
      );
    });

    test('returns null for empty', () {
      expect(ReferralAttribution.parseReferralCode(null), isNull);
      expect(ReferralAttribution.parseReferralCode(''), isNull);
      expect(ReferralAttribution.parseReferralCode('utm_source=organic'), isNull);
    });

    test('builds web entry url with ref', () {
      expect(
        ReferralAttribution.webEntryUrl('INFLU1'),
        'https://2s-pay.2s-group.com/register?ref=INFLU1',
      );
      expect(
        ReferralAttribution.webEntryUrl(null),
        'https://2s-pay.2s-group.com/',
      );
    });
  });
}
