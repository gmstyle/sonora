const double kCompactBreakpoint = 600.0;
const double kMediumBreakpoint = 840.0;
const double kExpandedBreakpoint = 1200.0;

/// Internal content split for the facet utility rail on ultra-wide.
/// Not a shell breakpoint. Shells stay compact, tablet, and wide.
const double kWideContentBreakpoint = 1600.0;

/// Content-box width where feed grids step from three columns to four.
/// Not a shell breakpoint. Measure the content box, not the window.
/// Below this, explore grids use 3 columns; from here until
/// [kWideContentBreakpoint] they use 4.
const double kFeedFourColumnContentWidth = 800.0;

/// Left filter rail on wide facet screens (Search, Library, Downloads).
/// Also the tablet master rail for Library, Downloads, and Settings.
const double kFacetFilterRailWidth = 200.0;

/// Right utility rail on wide facet screens at [kWideContentBreakpoint] and above.
const double kFacetUtilityRailWidth = 280.0;

/// Soft content max for wide document screens (Settings, artist see-all).
/// The clamp does not apply on tablet.
const double kDocumentContentMaxWidth = 1320.0;

/// Settings category rail on wide. Tablet keeps [kFacetFilterRailWidth].
const double kSettingsRailWidth = 260.0;

/// Settings form column inside the wide document card.
const double kSettingsFormMaxWidth = 800.0;

/// Section cards inside the tablet Settings split.
const double kSettingsSectionRadius = 20.0;

/// Horizontal padding for wide feed, facet, and entity content.
const double kWideContentPadding = 32.0;

/// Horizontal padding for tablet feed, facet, entity, and document content.
/// Home already uses 24 through `HomeLayoutMetrics`.
const double kTabletContentPadding = 24.0;

/// Horizontal padding for compact (MobileShell) feed, facet, and entity content.
/// Matches Home mobile shelves. Prefer this over a bare `16`.
const double kCompactContentPadding = 16.0;

/// Largest home mix tile. The 3-up row fills its width until a square would
/// pass this, then the tiles stay left-aligned. 220 matches a tablet portrait
/// row, so landscape and wide do not grow the mixes into posters.
const double kHomeMixCardMaxWidth = 220.0;

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
