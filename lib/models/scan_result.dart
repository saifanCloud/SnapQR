class ScanResult {
  final String url;
  final bool shouldLaunch;

  ScanResult({
    required this.url,
    this.shouldLaunch = false,
  });
}
