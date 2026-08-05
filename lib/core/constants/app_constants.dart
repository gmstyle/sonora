const double kCompactBreakpoint = 600.0;
const double kMediumBreakpoint = 840.0;
const double kExpandedBreakpoint = 1200.0;

/// Max number of downloads running at the same time. Higher concurrency
/// triggers YouTube Music 429 (rate limit) responses, mirroring the batch
/// size already used by album/playlist bulk download loops.
const int kMaxConcurrentDownloads = 3;

const String kAppVersion = '1.0.0+1';
const String kGitHubRepoOwner = 'gmstyle';
const String kGitHubRepoName = 'sonora';
const String kGitHubRepoUrl = 'https://github.com/gmstyle/sonora';
const String kPaypalDonateUrl = 'https://paypal.me/gmstyle';
