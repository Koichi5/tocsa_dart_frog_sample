import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';

// ミドルウェアを作成して、Firestoreの初期化を行う
// FirestoreのプロジェクトIDとKOMOJUのシークレットキーは dart_frog dev 実行時に定義
// 参考: https://dartfrog.vgv.dev/docs/basics/environments
// FIRESTORE_PROJECT_ID="hoge-hoge" KOMOJU_SECRET_KEY="hoge-hoge" dart_frog dev

Handler middleware(Handler handler) {
  print('middleware is activated');
  final projectId = Platform.environment['FIRESTORE_PROJECT_ID'];
  if (projectId == null) {
    throw Exception('FIRESTORE_PROJECT_ID is not set');
  }

  return (context) async {
    if (!Firestore.initialized) {
      Firestore.initialize(projectId);
    }
    final response = await handler(context);
    return response;
  };
}
