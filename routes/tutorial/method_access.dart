// dart_frog new route "/tutorial/method_access"

// ターミナルで dart_frog dev を実行されているか確認
// http://localhost:8080/tutorial/method_access

// request.method.value でHTTPメソッドを取得できる
// この場合は GET メソッドが表示される

// 手元で `curl --request POST --url http://localhost:8080/tutorial/method_access` を叩くと POST メソッドが表示される

import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  // Access the incoming request.
  final request = context.request;

  // Access the HTTP method.
  final method = request.method.value;

  return Response(body: 'This is a $method request.');
}
