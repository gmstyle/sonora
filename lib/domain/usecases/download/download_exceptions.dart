sealed class DownloadException implements Exception {
  final String? message;

  const DownloadException([this.message]);

  @override
  String toString() => message ?? runtimeType.toString();
}

class DownloadWifiRestrictionException extends DownloadException {
  const DownloadWifiRestrictionException([
    super.message = 'Downloads are restricted to WiFi only.',
  ]);
}

class DownloadCancelledException extends DownloadException {
  const DownloadCancelledException([super.message = 'Download cancelled.']);
}
