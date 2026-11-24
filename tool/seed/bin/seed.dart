// Prints an invented Lilith document: dart run tool/seed/bin/seed.dart
// <scenario> [--seed N]. Plain JSON; encryption and the pod are not here.

import 'dart:io';

import '../scenarios.dart';

void main(List<String> args) {
  try {
    stdout.write(seedDocument(args));
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  }
}
