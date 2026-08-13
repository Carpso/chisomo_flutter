import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_sponsor_app/core/router.dart';

void main() {
  group('deepLinkToRoute', () {
    test('maps kingdomsponsor://campaign/<id> to a route', () {
      expect(deepLinkToRoute('kingdomsponsor://campaign/7'), '/campaign/7');
      expect(deepLinkToRoute('kingdomsponsor://campaign/7?ref=ABC123'), '/campaign/7');
    });

    test('maps donate deep links', () {
      expect(deepLinkToRoute('kingdomsponsor://donate/9'), '/donate/9');
      expect(deepLinkToRoute('kingdomsponsor://donate/9?ref=XYZ'), '/donate/9');
    });

    test('maps event deep links to the event screen', () {
      expect(deepLinkToRoute('kingdomsponsor://event/18'), '/event/18');
      expect(deepLinkToRoute('kingdomsponsor://event/18?ref=FT5JCT2W'), '/event/18');
      expect(deepLinkToRoute('kingdomsponsor://event/18/'), '/event/18');
    });

    test('maps event buy-ticket deep links to the ticket screen', () {
      expect(deepLinkToRoute('kingdomsponsor://event/18/buy-ticket'), '/event/18/buy-ticket');
      expect(deepLinkToRoute('kingdomsponsor://event/18/buy-ticket?ref=ABC'), '/event/18/buy-ticket');
    });

    test('handles support, accept-link and reject-link hosts', () {
      expect(deepLinkToRoute('kingdomsponsor://support'), '/settings/support');
      expect(deepLinkToRoute('kingdomsponsor://accept-link/3'), '/settings/links/3/accept');
      expect(deepLinkToRoute('kingdomsponsor://reject-link/3'), '/settings/links/3/reject');
    });

    test('tolerates a trailing slash and uppercase scheme/host', () {
      expect(deepLinkToRoute('kingdomsponsor://campaign/7/'), '/campaign/7');
      expect(deepLinkToRoute('KingdomSponsor://Campaign/7'), '/campaign/7');
    });

    test('drops query strings from already-path values so the router never 404s', () {
      expect(deepLinkToRoute('/campaign/7?ref=ABC'), '/campaign/7');
      expect(deepLinkToRoute('/campaign/7#section'), '/campaign/7');
    });

    test('accepts known path values verbatim', () {
      expect(deepLinkToRoute('/campaign/7'), '/campaign/7');
      expect(deepLinkToRoute('/settings/support'), '/settings/support');
      expect(deepLinkToRoute('/admin'), '/admin');
    });

    test('returns null for anything unknown instead of crashing', () {
      expect(deepLinkToRoute(null), isNull);
      expect(deepLinkToRoute(''), isNull);
      expect(deepLinkToRoute('https://example.com/campaign/7'), isNull);
      expect(deepLinkToRoute('kingdomsponsor://unknown/7'), isNull);
      expect(deepLinkToRoute('not a link'), isNull);
      expect(deepLinkToRoute('/bogus/route'), isNull);
    });
  });
}
