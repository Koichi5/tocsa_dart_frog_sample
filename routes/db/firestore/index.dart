import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';

// GET: ユーザー一覧取得
// POST: ユーザー追加
Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => _getUserList(context),
    HttpMethod.post => _createUser(context),
    _ => Future.value(
        Response(
          statusCode: HttpStatus.methodNotAllowed,
        ),
      ),
  };
}

// 以下のコマンドで `dart_frog_sample_users` コレクションのデータを取得できる
// curl --request GET --url http://localhost:8080/db/firestore
Future<Response> _getUserList(RequestContext context) async {
  final userList = <Map<String, dynamic>>[];

  await Firestore.instance.collection('dart_frog_sample_users').get().then(
    (user) {
      for (final doc in user) {
        userList.add(doc.map);
      }
    },
  );

  return Response.json(body: userList.toString());
}

// 以下のコマンドで `dart_frog_sample_users` コレクションにデータを追加できる
// curl --request POST --url http://localhost:8080/db/firestore --data '{"name": "Lisa"}'
Future<Response> _createUser(RequestContext context) async {
  final body = await context.request.json() as Map<String, dynamic>;
  final name = body['name'] as String?;

  final data = <String, dynamic>{'name': name};

  final id = await Firestore.instance
      .collection('dart_frog_sample_users')
      .add(data)
      .then((doc) {
    return doc.id;
  });

  return Response.json(body: {'id': id});
}
