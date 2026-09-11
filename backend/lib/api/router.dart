import 'package:shelf/shelf.dart';

Handler buildHandler() {
  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_jsonErrorMiddleware())
      .addHandler(_router);
}

Handler get _router => (Request request) {
  if (request.method == 'GET' && request.url.path == 'health') {
    return Response.ok(
      '{"status": "ok"}',
      headers: {'content-type': 'application/json'},
    );
  }
  return Response.notFound('Not Found');
};

Middleware _jsonErrorMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } catch (e, stackTrace) {
        print('Error handling ${request.method} ${request.url}: $e');
        print(stackTrace);
        return Response.internalServerError(
          body: '{"error": "Internal Server Error"}',
          headers: {'content-type': 'application/json'},
        );
      }
    };
  };
}