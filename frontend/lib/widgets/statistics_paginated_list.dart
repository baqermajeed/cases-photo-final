import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../repositories/local/patient_local_repository.dart';

typedef StatisticsPageFetcher = Future<Map<String, dynamic>> Function({
  required int page,
  required int limit,
});

class StatisticsPaginatedPatientList extends StatefulWidget {
  static const int defaultPageSize = 30;

  final StatisticsPageFetcher onFetchPage;
  final Widget Function(BuildContext context, Patient patient) itemBuilder;
  final String emptyMessage;
  final Widget? emptyState;

  const StatisticsPaginatedPatientList({
    super.key,
    required this.onFetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyState,
  });

  @override
  StatisticsPaginatedPatientListState createState() =>
      StatisticsPaginatedPatientListState();
}

class StatisticsPaginatedPatientListState
    extends State<StatisticsPaginatedPatientList> {
  final _localRepository = PatientLocalRepository.instance;
  final _scrollController = ScrollController();

  final List<Patient> _patients = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _nextPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _loadFirstPage();

  Future<void> _loadFirstPage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _hasMore = true;
        _nextPage = 1;
      });
    }

    final result = await widget.onFetchPage(
      page: 1,
      limit: StatisticsPaginatedPatientList.defaultPageSize,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final patients = result['patients'] as List<Patient>;
      await _localRepository.upsertPatients(patients);
      setState(() {
        _patients
          ..clear()
          ..addAll(patients);
        _isLoading = false;
        _hasMore = _resolveHasMore(result['pagination'], patients.length);
        _nextPage = _hasMore ? 2 : 1;
      });
      return;
    }

    setState(() {
      _error = result['message']?.toString() ?? 'فشل جلب البيانات';
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    final result = await widget.onFetchPage(
      page: _nextPage,
      limit: StatisticsPaginatedPatientList.defaultPageSize,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final patients = result['patients'] as List<Patient>;
      if (patients.isNotEmpty) {
        await _localRepository.upsertPatients(patients);
      }
      setState(() {
        _patients.addAll(patients);
        _isLoadingMore = false;
        _hasMore = _resolveHasMore(result['pagination'], patients.length);
        if (_hasMore) _nextPage += 1;
      });
      return;
    }

    setState(() => _isLoadingMore = false);
  }

  bool _resolveHasMore(dynamic pagination, int batchLength) {
    if (pagination is Map) {
      if (pagination['has_next'] == true) return true;
      final page = pagination['page'];
      final pages = pagination['pages'];
      if (page is num && pages is num && page < pages) return true;
    }
    return batchLength == StatisticsPaginatedPatientList.defaultPageSize;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Widget _buildEmptyState() {
    if (widget.emptyState != null) return widget.emptyState!;
    return Center(child: Text(widget.emptyMessage));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFirstPage,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_patients.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _patients.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _patients.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return widget.itemBuilder(context, _patients[index]);
        },
      ),
    );
  }
}
