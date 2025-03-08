// dart_frog new route {パス} で新たにルートを作成できる
// 例：dart_frog new route "/tutorial/new_route"

// ターミナルで dart_frog dev を実行されているか確認
// このルートは開発環境では http://localhost:8080/tutorial/new_route でアクセス可能

import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  // TODO: implement route handler
  return Response(body: 'This is a new route!');
}
