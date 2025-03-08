import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';
import 'package:http/http.dart' as http;

// 以下のコマンドでセッションの作成が可能
// 返り値の return_url を開くと、決済画面が表示される
// curl --request POST \
//   --url http://localhost:8080/db/firestore/komoju \
//   --header 'Content-Type: application/json' \
//   --data '{
//     "order_id": "order_123",
//     "amount": 1000,
//     "currency": "JPY",
//     "customer_email": "test@example.com",
//     "return_url": "tocsa://payment/return"
//   }'

// KOMOJUの設定
class KomojuConfig {
  static const String hostedPageBaseUrl = 'https://komoju.com';
}

// セッションモデル
class KomojuSession {
  KomojuSession({
    required this.id,
    required this.sessionUrl,
    required this.status,
    required this.paymentMethods,
    required this.expired,
    this.payment,
  });

  factory KomojuSession.fromJson(Map<String, dynamic> json) {
    return KomojuSession(
      id: json['id'] as String,
      sessionUrl: json['session_url'] as String,
      status: json['status'] as String,
      paymentMethods:
          (json['payment_methods'] as List).cast<Map<String, dynamic>>(),
      expired: json['expired'] as bool,
      payment: json['payment'] as Map<String, dynamic>?,
    );
  }
  final String id;
  final String sessionUrl;
  final String status;
  final List<Map<String, dynamic>> paymentMethods;
  final bool expired;
  final Map<String, dynamic>? payment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_url': sessionUrl,
        'status': status,
        'payment_methods': paymentMethods,
        'expired': expired,
        'payment': payment,
      };
}

Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.post => _createSession(context),
    HttpMethod.get => _checkSession(context),
    _ => Future.value(
        Response(statusCode: HttpStatus.methodNotAllowed),
      ),
  };
}

// Basic認証のヘッダーを生成
// FirestoreのプロジェクトIDとKOMOJUのシークレットキーは dart_frog dev 実行時に定義
// 参考: https://dartfrog.vgv.dev/docs/basics/environments
// FIRESTORE_PROJECT_ID="hoge-hoge" KOMOJU_SECRET_KEY="hoge-hoge" dart_frog dev

String _getAuthHeader() {
  final secretKey = Platform.environment['KOMOJU_SECRET_KEY'];
  print('secretKey: $secretKey');

  if (secretKey == null) {
    throw Exception('KOMOJU secret key is not configured');
  }
  final credentials = '$secretKey:';
  final encodedCredentials = base64Encode(utf8.encode(credentials));
  return 'Basic $encodedCredentials';
}

// セッション作成エンドポイント
Future<Response> _createSession(RequestContext context) async {
  try {
    final body = await context.request.json() as Map<String, dynamic>;

    final orderId = body['order_id'] as String;
    final amount = body['amount'] as num;
    final currency = body['currency'] as String;
    final customerEmail = body['customer_email'] as String;
    final returnUrl = body['return_url'] as String?;

    final url = Uri.parse('${KomojuConfig.hostedPageBaseUrl}/api/v1/sessions');

    final response = await http.post(
      url,
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        'default_locale': 'ja',
        'payment_data': {
          'capture': 'auto',
          'email': customerEmail,
        },
        'external_order_num': orderId,
        'return_url': returnUrl ?? 'tocsa://payment/return',
        'cancel_url': 'tocsa://payment/cancel',
        'metadata': {
          'order_id': orderId,
          'customer_email': customerEmail,
        },
      }),
    );

    if (response.statusCode == 200) {
      final session = KomojuSession.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      // Firestoreにセッション情報を保存
      final sessionData = {
        ...session.toJson(),
        'created_at': DateTime.now().toIso8601String(),
        'order_id': orderId,
        'amount': amount,
        'currency': currency,
        'customer_email': customerEmail,
      };

      final docRef = await Firestore.instance
          .collection('komoju_payment_sessions')
          .add(sessionData);

      // セッション情報にFirestoreのドキュメントIDを追加して返却
      return Response.json(
        body: {
          ...session.toJson(),
          'firestore_doc_id': docRef.id,
        },
      );
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      return Response.json(
        statusCode: response.statusCode,
        body: {
          'error': error['error'] ?? error,
          'message': error['message'] ?? 'Unknown error occurred',
        },
      );
    }
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': 'Failed to create session', 'message': e.toString()},
    );
  }
}

// セッション状態確認エンドポイント
Future<Response> _checkSession(RequestContext context) async {
  try {
    final sessionId = context.request.uri.queryParameters['session_id'];
    if (sessionId == null) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'error': 'session_id is required'},
      );
    }

    final url = Uri.parse(
      '${KomojuConfig.hostedPageBaseUrl}/api/v1/sessions/$sessionId',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': _getAuthHeader(),
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final session = KomojuSession.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      return Response.json(body: session.toJson());
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      return Response.json(
        statusCode: response.statusCode,
        body: {
          'error': error['error'] ?? error,
          'message': error['message'] ?? 'Unknown error occurred',
        },
      );
    }
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': 'Failed to check session', 'message': e.toString()},
    );
  }
}
