import 'dart:io';

import 'package:linos_backend/api/router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final server = await shelf_io.serve(buildHandler(), ip, port);

  print('Linos backend listening on http://${server.address.host}:${server.port}');
}