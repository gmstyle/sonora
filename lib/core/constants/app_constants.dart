const double kCompactBreakpoint = 600.0;
const double kMediumBreakpoint = 840.0;
const double kExpandedBreakpoint = 1200.0;

/// Internal content split for utility and related rails on ultra-wide.
/// Not a shell breakpoint. Shells stay compact, tablet, and wide.
const double kWideContentBreakpoint = 1600.0;

/// Left filter rail on wide facet screens (Search, Library, Downloads).
const double kFacetFilterRailWidth = 200.0;

/// Right utility rail on wide facet screens at [kWideContentBreakpoint] and above.
const double kFacetUtilityRailWidth = 280.0;

/// Track or episode list cap on entity screens when the related rail is absent.
const double kEntityTrackMaxWidth = 960.0;

/// Related rail on entity screens at [kWideContentBreakpoint] and above.
const double kEntityRelatedRailWidth = 320.0;

/// Soft content max width for document screens (Settings, artist see-all).
const double kDocumentContentMaxWidth = 1320.0;

/// Horizontal padding for wide feed, facet, and entity content.
const double kWideContentPadding = 32.0;

/// Edge-to-edge mini-player shelf on tablet and wide layouts.
const double kMiniPlayerShelfHeight = 80.0;

/// Max number of downloads running at the same time. Higher concurrency
/// triggers YouTube Music 429 (rate limit) responses, mirroring the batch
/// size already used by album/playlist bulk download loops.
const int kMaxConcurrentDownloads = 3;

const String kAppVersion = '1.7.0+55';
const String kGitHubRepoOwner = 'gmstyle';
const String kGitHubRepoName = 'sonora';
const String kGitHubRepoUrl = 'https://github.com/gmstyle/sonora';
const String kPaypalDonateUrl = 'https://paypal.me/gmstyle';
