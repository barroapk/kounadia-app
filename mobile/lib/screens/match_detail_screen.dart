import "dart:async";
import "package:flutter/material.dart";
import "../models/match_analysis.dart";
import "../models/standings.dart";
import "../services/api_service.dart";
import "../widgets/standings_table.dart";
import "../widgets/match_header_card.dart";
import "../widgets/match_statistics_view.dart";
import "../widgets/match_lineups_view.dart";
import "../widgets/match_details_tab.dart";
import "../widgets/form_and_h2h_widgets.dart";

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  final String homeTeam;
  final String awayTeam;
  final String? competitionCode;
  final String? homeTeamCrest;
  final String? awayTeamCrest;
  final String provider;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    this.competitionCode,
    this.homeTeamCrest,
    this.awayTeamCrest,
    this.provider = 'football-data',
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  MatchAnalysis? _analysis;
  Object? _loadError;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;

  Future<StandingsResponse?>? _standingsFuture;
  StandingsResponse? _standingsCache;

  TabController? _tabController;
  int _tabCountForController = 0;
  Timer? _liveRefreshTimer;
  String? _lastKnownStatus;

  /// Recharge en arrière-plan sans jamais effacer l'écran : les données
  /// précédentes restent visibles pendant qu'on récupère les nouvelles.
  Future<void> _fetchAnalysis({bool isInitial = false}) async {
    if (!isInitial) setState(() => _isRefreshing = true);

    try {
      final analysis = await _apiService.getMatchAnalysis(widget.matchId, provider: widget.provider);
      _updateRefreshStrategy(analysis.status ?? '');
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _loadError = null;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isInitial) _loadError = e;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _updateRefreshStrategy(String status) {
    if (_lastKnownStatus == status) return;
    _lastKnownStatus = status;

    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;

    Duration? interval;
    if (status == "IN_PLAY") {
      interval = const Duration(seconds: 20);
    } else if (status == "PAUSED") {
      interval = const Duration(seconds: 45);
    }

    if (interval != null) {
      _liveRefreshTimer = Timer.periodic(interval, (_) => _fetchAnalysis());
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAnalysis(isInitial: true);

    if (widget.competitionCode != null) {
      _standingsFuture = _apiService.getStandings(widget.competitionCode!);
      _standingsFuture!.then((data) {
        if (mounted) setState(() => _standingsCache = data);
      });
    }
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _reloadAnalysis() {
    _fetchAnalysis();
  }

  void _onSeasonChanged(String season) {
    setState(() {
      _standingsFuture = _apiService.getStandings(widget.competitionCode ?? '', season: season);
      _standingsFuture!.then((data) {
        if (mounted) setState(() => _standingsCache = data);
      });
    });
  }

  void _ensureTabController(int tabCount) {
    if (_tabController == null || _tabCountForController != tabCount) {
      _tabController?.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
      _tabCountForController = tabCount;
    }
  }

  void _goToTab(List<Tab> tabs, String label) {
    final index = tabs.indexWhere((t) => (t.text ?? '').toUpperCase() == label);
    if (index != -1) _tabController?.animateTo(index);
  }

  Widget _formTab(TeamForm home, TeamForm away, HeadToHead h2h, String homeTeamName, String awayTeamName) {
    Widget formCard(String label, TeamForm form) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (form.matchesAnalyzed == 0)
                const Text("Pas assez de données historiques pour l'instant.")
              else ...[
                Text("${form.wins}V - ${form.draws}N - ${form.losses}D sur ${form.matchesAnalyzed} match(s)"),
                Text("Forme : ${form.formPercent}% (${form.points}/${form.maxPoints} pts)"),
                Text("Buts : ${form.goalsFor} marqués / ${form.goalsAgainst} encaissés (diff. ${form.goalDifference})"),
                Text("Moyenne : ${form.avgGoalsFor} marqués / ${form.avgGoalsAgainst} encaissés par match"),
                Text("Clean sheets : ${form.cleanSheets} · Sans marquer : ${form.failedToScore}"),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: buildFormBar(homeTeamName, home),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: buildFormBar(awayTeamName, away),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Confrontations directes", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                buildHeadToHeadBar(h2h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _standingsTab() {
    return FutureBuilder<StandingsResponse?>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null || data.standings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text("Classement indisponible pour le moment.", textAlign: TextAlign.center),
            ),
          );
        }
        return StandingsTable(
          data: data,
          highlightHomeTeam: widget.homeTeam,
          highlightAwayTeam: widget.awayTeam,
          onSeasonChanged: _onSeasonChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_isInitialLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_analysis == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Erreur : ${_loadError ?? 'inconnue'}"),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _reloadAnalysis, child: const Text("Réessayer")),
                    ],
                  ),
                ),
              );
            }

            final analysis = _analysis!;
            final kickoff = analysis.utcDate != null ? DateTime.tryParse(analysis.utcDate!) : null;
            final isUpcoming = analysis.status == "TIMED" || analysis.status == "SCHEDULED";
            final isLive = analysis.status == "IN_PLAY" || analysis.status == "PAUSED";
            final isPaused = analysis.status == "PAUSED";
            final isFinished = analysis.status == "FINISHED";

            final hasStats = analysis.statistics != null &&
                (analysis.statistics!.home.isNotEmpty || analysis.statistics!.away.isNotEmpty);
            final hasLineups = analysis.lineups != null && analysis.lineups!.isNotEmpty;
            final hasStandings = widget.competitionCode != null;

            final tabs = <Tab>[];
            final tabViews = <Widget>[];

            if (isUpcoming) {
              tabs.add(const Tab(icon: Icon(Icons.show_chart, size: 18), text: "FORME"));
              tabViews.add(_formTab(analysis.home, analysis.away, analysis.headToHead, analysis.homeTeam, analysis.awayTeam));

              tabs.add(const Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: "DÉTAILS"));
              tabViews.add(MatchDetailsTab(
                analysis: analysis,
                standings: _standingsCache,
                onSeeStats: () => _goToTab(tabs, "STATS"),
                onSeeStandings: () => _goToTab(tabs, "CLASSEMENT"),
              ));

              if (hasLineups) {
                tabs.add(const Tab(icon: Icon(Icons.groups_outlined, size: 18), text: "COMPOS"));
                tabViews.add(MatchLineupsView(lineups: analysis.lineups!));
              }

              if (hasStandings) {
                tabs.add(const Tab(icon: Icon(Icons.leaderboard_outlined, size: 18), text: "CLASSEMENT"));
                tabViews.add(_standingsTab());
              }
            } else {
              tabs.add(const Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: "DÉTAILS"));
              tabViews.add(MatchDetailsTab(
                analysis: analysis,
                standings: _standingsCache,
                onSeeStats: () => _goToTab(tabs, "STATS"),
                onSeeStandings: () => _goToTab(tabs, "CLASSEMENT"),
              ));

              if (hasStats) {
                tabs.add(const Tab(icon: Icon(Icons.bar_chart, size: 18), text: "STATS"));
                tabViews.add(MatchStatisticsView(
                  statistics: analysis.statistics!,
                  homeTeam: analysis.homeTeam,
                  awayTeam: analysis.awayTeam,
                ));
              }

              if (hasLineups) {
                tabs.add(const Tab(icon: Icon(Icons.groups_outlined, size: 18), text: "COMPOS"));
                tabViews.add(MatchLineupsView(lineups: analysis.lineups!));
              }

              if (hasStandings) {
                tabs.add(const Tab(icon: Icon(Icons.leaderboard_outlined, size: 18), text: "CLASSEMENT"));
                tabViews.add(_standingsTab());
              }

              tabs.add(const Tab(icon: Icon(Icons.show_chart, size: 18), text: "FORME"));
              tabViews.add(_formTab(analysis.home, analysis.away, analysis.headToHead, analysis.homeTeam, analysis.awayTeam));
            }

            _ensureTabController(tabs.length);

            return Column(
              children: [
                if (_isRefreshing) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF16A34A)),
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: MatchHeaderCard(
                            homeTeam: analysis.homeTeam,
                            awayTeam: analysis.awayTeam,
                            homeTeamCrest: widget.homeTeamCrest,
                            awayTeamCrest: widget.awayTeamCrest,
                            homeScore: analysis.homeScore,
                            awayScore: analysis.awayScore,
                            wonAfter: analysis.wonAfter,
                            penaltyHomeScore: analysis.penaltyHomeScore,
                            penaltyAwayScore: analysis.penaltyAwayScore,
                            competition: analysis.competition,
                            venue: analysis.venue,
                            referee: analysis.referee,
                            isLive: isLive,
                            isPaused: isPaused,
                            isFinished: isFinished,
                            kickoff: kickoff,
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarDelegate(
                            TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              labelColor: const Color(0xFF16A34A),
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: const Color(0xFF16A34A),
                              tabs: tabs,
                            ),
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(controller: _tabController, children: tabViews),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: const Color(0xFFF4F5F7), child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}
