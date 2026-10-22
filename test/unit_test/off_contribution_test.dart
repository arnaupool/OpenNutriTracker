import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/off_contribution/data/off_account_data_source.dart';
import 'package:opennutritracker/features/off_contribution/data/off_contribution_data_source.dart';
import 'package:opennutritracker/features/off_contribution/domain/contribute_to_off_usecase.dart';

// A custom food with a barcode (typically from "photograph the label" after
// a scan found nothing) can be sent to Open Food Facts with the user's own
// OFF account. The product must not exist on OFF yet: the app never
// overwrites somebody else's data with a local copy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MealEntity meal({
    String? code = '8437000000019',
    String? name = 'Hummus casero',
    double? kcal = 166,
    String unit = 'g',
  }) =>
      MealEntity(
        code: code,
        name: name,
        brands: 'Mercado Local',
        url: null,
        mealQuantity: null,
        mealUnit: unit,
        servingQuantity: null,
        servingUnit: null,
        servingSize: null,
        nutriments: MealNutrimentsEntity(
          energyKcal100: kcal,
          carbohydrates100: 14.3,
          fat100: 9.6,
          proteins100: 7.9,
          sugars100: 0.3,
          saturatedFat100: 1.4,
          fiber100: 6,
          sodium100: 379,
        ),
        source: MealSourceEntity.custom,
      );

  late List<http.Request> requests;
  late OffAccountDataSource account;

  ContributeToOffUsecase usecase(Future<http.Response> Function(http.Request) handler, {bool staging = true}) {
    final client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    return ContributeToOffUsecase(
      account,
      OffContributionDataSource(client: client, userAgent: () async => 'ONT-test/1.0', staging: staging),
    );
  }

  http.Response notFound(http.Request r) => http.Response('{"status":0,"status_verbose":"product not found"}', 404);

  setUp(() async {
    requests = [];
    FlutterSecureStorage.setMockInitialValues({});
    account = OffAccountDataSource();
    await account.save(const OffCredentials(userId: 'ana', password: 's3cret'));
  });

  test('sends a new product with nutrition per 100 g and the user account', () async {
    final result = await usecase((r) async {
      if (r.method == 'GET') return notFound(r);
      return http.Response('{"status":1,"status_verbose":"fields saved"}', 200);
    }).contribute(meal());

    expect(result, OffContributionResult.sent);
    expect(requests.map((r) => r.method), ['GET', 'POST']);
    final get = requests.first;
    expect(get.url.host, 'world.openfoodfacts.net');
    expect(get.url.path, '/api/v2/product/8437000000019');
    final post = requests.last;
    expect(post.url.toString(), 'https://world.openfoodfacts.net/cgi/product_jqm2.pl');
    expect(post.headers['User-Agent'], 'ONT-test/1.0');
    // Staging sits behind basic auth off:off.
    expect(post.headers['Authorization'], 'Basic ${base64Encode(utf8.encode('off:off'))}');
    final form = post.bodyFields;
    expect(form['code'], '8437000000019');
    expect(form['user_id'], 'ana');
    expect(form['password'], 's3cret');
    expect(form['product_name'], 'Hummus casero');
    expect(form['brands'], 'Mercado Local');
    expect(form['nutrition_data_per'], '100g');
    expect(form['nutriment_energy-kcal'], '166');
    expect(form['nutriment_energy-kcal_unit'], 'kcal');
    expect(form['nutriment_fat'], '9.6');
    expect(form['nutriment_saturated-fat'], '1.4');
    expect(form['nutriment_carbohydrates'], '14.3');
    expect(form['nutriment_sugars'], '0.3');
    expect(form['nutriment_fiber'], '6');
    expect(form['nutriment_proteins'], '7.9');
    // The app keeps sodium in mg; OFF gets grams.
    expect(form['nutriment_sodium'], '0.379');
    expect(form['nutriment_sodium_unit'], 'g');
  });

  test('production host without basic auth', () async {
    await usecase((r) async {
      if (r.method == 'GET') return notFound(r);
      return http.Response('{"status":1}', 200);
    }, staging: false)
        .contribute(meal());
    expect(requests.last.url.host, 'world.openfoodfacts.org');
    expect(requests.last.headers.containsKey('Authorization'), isFalse);
  });

  test('a product already on OFF is never overwritten', () async {
    final result = await usecase((r) async => http.Response('{"status":1,"product":{"code":"8437000000019"}}', 200))
        .contribute(meal());
    expect(result, OffContributionResult.alreadyOnOff);
    expect(requests.map((r) => r.method), ['GET']);
  });

  test('wrong OFF credentials (HTTP 403) are reported as such', () async {
    final result = await usecase((r) async {
      if (r.method == 'GET') return notFound(r);
      return http.Response('<html>Error</html>', 403);
    }).contribute(meal());
    expect(result, OffContributionResult.wrongCredentials);
  });

  test('a rejected save (status 0) is a failure, not a success', () async {
    final result = await usecase((r) async {
      if (r.method == 'GET') return notFound(r);
      return http.Response('{"status":0,"status_verbose":"no code or invalid code"}', 200);
    }).contribute(meal());
    expect(result, OffContributionResult.failed);
  });

  test('network errors are a failure', () async {
    final result = await usecase((r) async => throw http.ClientException('offline')).contribute(meal());
    expect(result, OffContributionResult.failed);
  });

  test('without an account nothing is sent', () async {
    await account.clear();
    final result = await usecase(notFoundAsync).contribute(meal());
    expect(result, OffContributionResult.notSignedIn);
    expect(requests, isEmpty);
  });

  test('needs a real barcode, a name and the energy', () async {
    final uc = usecase(notFoundAsync);
    expect(await uc.contribute(meal(code: 'f3a9-uuid')), OffContributionResult.missingData);
    expect(await uc.contribute(meal(name: '  ')), OffContributionResult.missingData);
    expect(await uc.contribute(meal(kcal: null)), OffContributionResult.missingData);
    expect(requests, isEmpty);
  });

  // Simple-mode custom meals store the totals of one serving in the per-100
  // fields with unit "g/ml"; sending them as "per 100 g" would publish
  // wrong values, so only explicit g / ml foods qualify.
  test('only foods with values per 100 g or 100 ml can be sent', () async {
    final uc = usecase(notFoundAsync);
    expect(ContributeToOffUsecase.canContribute(meal(unit: 'ml')), isTrue);
    expect(ContributeToOffUsecase.canContribute(meal(unit: 'g/ml')), isFalse);
    expect(await uc.contribute(meal(unit: 'g/ml')), OffContributionResult.missingData);
    expect(requests, isEmpty);
  });

  test('credentials round-trip through secure storage', () async {
    expect((await account.read())?.userId, 'ana');
    await account.clear();
    expect(await account.read(), isNull);
  });
}

Future<http.Response> notFoundAsync(http.Request r) async =>
    http.Response('{"status":0,"status_verbose":"product not found"}', 404);
