import 'package:trellis_site/trellis_site.dart';

void main() {
  final config = SiteConfig(siteDir: '.', title: 'My Site', baseUrl: 'https://example.com', taxonomies: ['tags']);

  final site = TrellisSite(config);
  print(site.runtimeType);
}
