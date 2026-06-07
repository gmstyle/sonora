import 'dart:convert';

class CliOutput {
  final String text;
  final Map<String, dynamic>? data;
  final int exitCode;

  const CliOutput(this.text, {this.data, this.exitCode = 0});

  factory CliOutput.success(String text, {Map<String, dynamic>? data}) =>
      CliOutput(text, data: data, exitCode: 0);

  factory CliOutput.error(String text, {Map<String, dynamic>? data}) =>
      CliOutput(text, data: data, exitCode: 1);

  String toJson() {
    final d = data ?? {'message': text};
    return const JsonEncoder.withIndent('  ').convert(d);
  }

  String toText() => text;
}
