
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/body_measurement_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_body_measurement_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/user_image_picker_tile.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/profile/presentation/progress_photo_compare_screen.dart';
import 'package:opennutritracker/features/profile/presentation/progress_photo_viewer_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// The circumferences MacroFactor tracks (up to 21) are more than most
/// users need day to day — FC-01 ships a practical subset that still
/// covers both waist-to-height and waist-to-hip, the two ratios the
/// research called out as the actual differentiator over BMI.
enum BodyMeasurementMetric {
  neck,
  shoulders,
  chest,
  waist,
  hips,
  biceps,
  thigh;

  double? valueCm(BodyMeasurementEntity entry) {
    switch (this) {
      case BodyMeasurementMetric.neck:
        return entry.neckCm;
      case BodyMeasurementMetric.shoulders:
        return entry.shouldersCm;
      case BodyMeasurementMetric.chest:
        return entry.chestCm;
      case BodyMeasurementMetric.waist:
        return entry.waistCm;
      case BodyMeasurementMetric.hips:
        return entry.hipsCm;
      case BodyMeasurementMetric.biceps:
        return entry.bicepsCm;
      case BodyMeasurementMetric.thigh:
        return entry.thighCm;
    }
  }

  String label(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case BodyMeasurementMetric.neck:
        return s.bodyMeasurementsNeckLabel;
      case BodyMeasurementMetric.shoulders:
        return s.bodyMeasurementsShouldersLabel;
      case BodyMeasurementMetric.chest:
        return s.bodyMeasurementsChestLabel;
      case BodyMeasurementMetric.waist:
        return s.bodyMeasurementsWaistLabel;
      case BodyMeasurementMetric.hips:
        return s.bodyMeasurementsHipsLabel;
      case BodyMeasurementMetric.biceps:
        return s.bodyMeasurementsBicepsLabel;
      case BodyMeasurementMetric.thigh:
        return s.bodyMeasurementsThighLabel;
    }
  }
}

/// The three angles MacroFactor's progress-photo flow captures per entry.
enum ProgressPhotoAngle {
  front,
  side,
  back;

  String? pathFor(BodyMeasurementEntity entry) {
    switch (this) {
      case ProgressPhotoAngle.front:
        return entry.frontPhotoPath;
      case ProgressPhotoAngle.side:
        return entry.sidePhotoPath;
      case ProgressPhotoAngle.back:
        return entry.backPhotoPath;
    }
  }

  String label(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case ProgressPhotoAngle.front:
        return s.bodyMeasurementsPhotoFrontLabel;
      case ProgressPhotoAngle.side:
        return s.bodyMeasurementsPhotoSideLabel;
      case ProgressPhotoAngle.back:
        return s.bodyMeasurementsPhotoBackLabel;
    }
  }
}

class BodyMeasurementsScreen extends StatefulWidget {
  final GetBodyMeasurementUsecase? getUsecase;
  final AddBodyMeasurementUsecase? addUsecase;
  final DeleteBodyMeasurementUsecase? deleteUsecase;
  final ConfigRepository? configRepository;
  final GetUserUsecase? getUserUsecase;

  const BodyMeasurementsScreen({
    super.key,
    this.getUsecase,
    this.addUsecase,
    this.deleteUsecase,
    this.configRepository,
    this.getUserUsecase,
  });

  @override
  State<BodyMeasurementsScreen> createState() =>
      _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  late final GetBodyMeasurementUsecase _getUsecase =
      widget.getUsecase ?? locator<GetBodyMeasurementUsecase>();
  late final AddBodyMeasurementUsecase _addUsecase =
      widget.addUsecase ?? locator<AddBodyMeasurementUsecase>();
  late final DeleteBodyMeasurementUsecase _deleteUsecase =
      widget.deleteUsecase ?? locator<DeleteBodyMeasurementUsecase>();
  late final ConfigRepository _configRepository =
      widget.configRepository ?? locator<ConfigRepository>();
  late final GetUserUsecase? _getUserUsecase =
      widget.getUserUsecase ??
      (locator.isRegistered<GetUserUsecase>()
          ? locator<GetUserUsecase>()
          : null);

  bool _loading = true;
  bool _usesImperialUnits = false;
  List<BodyMeasurementEntity> _entries = const [];
  double? _userHeightCm;
  BodyMeasurementMetric _selectedMetric = BodyMeasurementMetric.waist;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _configRepository.getConfig();
    final entries = await _getUsecase.getAllEntries();
    entries.sort((a, b) => b.date.compareTo(a.date));
    final user = await _getUserUsecase?.getUserData();
    if (!mounted) return;
    setState(() {
      _usesImperialUnits = config.usesImperialUnits;
      _entries = entries;
      _userHeightCm = user?.heightCM;
      _loading = false;
    });
  }

  Future<void> _onAddEntry() async {
    final latest = _entries.isNotEmpty ? _entries.first : null;
    final result = await showDialog<BodyMeasurementEntity>(
      context: context,
      builder: (context) => _AddBodyMeasurementEntryDialog(
        initialDate: DateTime.now(),
        previousEntry: latest,
        usesImperialUnits: _usesImperialUnits,
      ),
    );
    if (result == null) return;

    await _addUsecase.addEntry(result);
    await _load();
  }

  Future<void> _onDelete(BodyMeasurementEntity entry) async {
    await _deleteUsecase.deleteEntry(entry.date);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyPhoto = _entries.any((e) => e.hasAnyPhoto);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).profileBodyMeasurementsTitle),
        actions: [
          if (hasAnyPhoto)
            Semantics(
              identifier: 'body-measurements-compare',
              child: IconButton(
                tooltip: S.of(context).bodyMeasurementsCompareTooltip,
                icon: const Icon(Icons.compare_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProgressPhotoCompareScreen(
                      getUsecase: _getUsecase,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Semantics(
        identifier: 'body-measurements-add',
        child: FloatingActionButton.extended(
          onPressed: _onAddEntry,
          icon: const Icon(Icons.add),
          label: Text(S.of(context).bodyMeasurementsAddEntry),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  S.of(context).bodyMeasurementsNoEntries,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: _entries.length + 1,
              separatorBuilder: (context, index) {
                if (index == 0) return const SizedBox.shrink();
                return const Divider(height: 1);
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricChips(
                        selected: _selectedMetric,
                        onSelected: (m) => setState(() => _selectedMetric = m),
                      ),
                      const SizedBox(height: 8),
                      _MeasurementTrendChart(
                        entries: _entries,
                        metric: _selectedMetric,
                        usesImperialUnits: _usesImperialUnits,
                      ),
                      const SizedBox(height: 12),
                      _RatioCards(
                        latest: _entries.first,
                        userHeightCm: _userHeightCm,
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }
                return _buildEntryTile(_entries[index - 1]);
              },
            ),
    );
  }

  Widget _buildEntryTile(BodyMeasurementEntity entry) {
    final dateLabel = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(entry.date);
    final s = S.of(context);
    final unit = _usesImperialUnits ? s.inLabel : s.cmLabel;

    String displayValue(double cm) {
      final value = _usesImperialUnits ? UnitCalc.cmToInches(cm) : cm;
      return value.toStringAsFixed(1);
    }

    final parts = <String>[
      for (final metric in BodyMeasurementMetric.values)
        if (metric.valueCm(entry) != null)
          '${metric.label(context)} ${displayValue(metric.valueCm(entry)!)} $unit',
    ];

    return ListTile(
      leading: entry.hasAnyPhoto ? _EntryThumbnails(entry: entry) : null,
      title: Text(
        parts.isEmpty ? dateLabel : parts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.note?.isNotEmpty == true ? '$dateLabel  •  ${entry.note}' : dateLabel,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _onDelete(entry),
      ),
    );
  }
}

/// Small stacked thumbnails (up to 3, one per logged angle) shown on an
/// entry's list tile so photos are visible at a glance without opening
/// the compare screen.
class _EntryThumbnails extends StatelessWidget {
  final BodyMeasurementEntity entry;

  const _EntryThumbnails({required this.entry});

  @override
  Widget build(BuildContext context) {
    final angles = [
      for (final angle in ProgressPhotoAngle.values)
        if (angle.pathFor(entry) != null) angle,
    ];

    return SizedBox(
      width: 40,
      height: double.infinity,
      child: Stack(
        children: [
          for (var i = 0; i < angles.length && i < 3; i++)
            Positioned(
              left: i * 6.0,
              child: GestureDetector(
                key: ValueKey(
                  'body-measurements-thumbnail-${entry.date.toIso8601String()}-${angles[i].name}',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProgressPhotoViewerScreen(
                      entry: entry,
                      initialAngle: angles[i],
                    ),
                  ),
                ),
                child: FutureBuilder<ImageProvider?>(
                  future: UserImageStorage.imageProvider(angles[i].pathFor(entry)!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox(width: 24, height: 40);
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image(
                        image: snapshot.data!,
                        width: 24,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => const SizedBox(
                          width: 24,
                          height: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricChips extends StatelessWidget {
  final BodyMeasurementMetric selected;
  final ValueChanged<BodyMeasurementMetric> onSelected;

  const _MetricChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'body-measurements-metric-chips',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final metric in BodyMeasurementMetric.values)
              ChoiceChip(
                label: Text(metric.label(context)),
                selected: selected == metric,
                onSelected: (_) => onSelected(metric),
              ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementTrendChart extends StatelessWidget {
  static const double _chartHeight = 200;

  final List<BodyMeasurementEntity> entries;
  final BodyMeasurementMetric metric;
  final bool usesImperialUnits;

  const _MeasurementTrendChart({
    required this.entries,
    required this.metric,
    required this.usesImperialUnits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points =
        entries
            .where((e) => metric.valueCm(e) != null)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (points.length < 2) {
      return Padding(
        key: const Key('bodyMeasurementsChartEmptyState'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: SizedBox(
          height: _chartHeight,
          child: Center(
            child: Text(
              S.of(context).bodyMeasurementsChartEmptyState,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    double displayValue(double cm) =>
        usesImperialUnits ? UnitCalc.cmToInches(cm) : cm;

    final windowStart = points.first.date;
    final windowEnd = points.last.date;
    final spanDays = windowEnd.difference(windowStart).inDays.clamp(1, 1 << 30);

    final spots = <FlSpot>[
      for (final entry in points)
        FlSpot(
          entry.date.difference(windowStart).inDays.toDouble(),
          displayValue(metric.valueCm(entry)!),
        ),
    ];

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPadding = ((maxY - minY) * 0.15).clamp(0.5, 5.0);

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = spanDays > 400
        ? DateFormat.yMMM(localeTag)
        : DateFormat.MMMd(localeTag);
    final labelInterval = (spanDays / 4).ceilToDouble();

    return Semantics(
      identifier: 'body-measurements-chart',
      child: SizedBox(
        key: const Key('bodyMeasurementsChart'),
        height: _chartHeight,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: spanDays.toDouble(),
            minY: minY - yPadding,
            maxY: maxY + yPadding,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: labelInterval,
                  getTitlesWidget: (value, meta) {
                    final day = windowStart.add(Duration(days: value.toInt()));
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dateFormat.format(day),
                        style: theme.textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: theme.colorScheme.primary,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 2.5,
                        color: theme.colorScheme.primary,
                        strokeWidth: 0,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Waist-to-height and waist-to-hip: the two ratios MacroFactor surfaces
/// as a BMI alternative. Computed on the fly from the latest entry that
/// has the inputs — never persisted, so there's nothing to keep in sync
/// if the user edits an old entry or their height later.
class _RatioCards extends StatelessWidget {
  final BodyMeasurementEntity latest;
  final double? userHeightCm;

  const _RatioCards({required this.latest, required this.userHeightCm});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final waist = latest.waistCm;
    final hips = latest.hipsCm;

    final waistToHeight = (waist != null && userHeightCm != null && userHeightCm! > 0)
        ? waist / userHeightCm!
        : null;
    final waistToHip = (waist != null && hips != null && hips > 0)
        ? waist / hips
        : null;

    return Semantics(
      identifier: 'body-measurements-ratios',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _RatioTile(
                label: s.bodyMeasurementsWaistToHeightRatioLabel,
                value: waistToHeight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RatioTile(
                label: s.bodyMeasurementsWaistToHipRatioLabel,
                value: waistToHip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioTile extends StatelessWidget {
  final String label;
  final double? value;

  const _RatioTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value == null ? '—' : value!.toStringAsFixed(2),
              style: theme.textTheme.titleLarge,
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBodyMeasurementEntryDialog extends StatefulWidget {
  final DateTime initialDate;
  final BodyMeasurementEntity? previousEntry;
  final bool usesImperialUnits;

  const _AddBodyMeasurementEntryDialog({
    required this.initialDate,
    required this.previousEntry,
    required this.usesImperialUnits,
  });

  @override
  State<_AddBodyMeasurementEntryDialog> createState() =>
      _AddBodyMeasurementEntryDialogState();
}

class _AddBodyMeasurementEntryDialogState
    extends State<_AddBodyMeasurementEntryDialog> {
  late DateTime _date;
  late final Map<BodyMeasurementMetric, TextEditingController> _controllers;
  late TextEditingController _noteController;
  // Photos are never prefilled from the previous entry — unlike a
  // circumference, reusing yesterday's photo for today makes no sense.
  String? _frontPhotoPath;
  String? _sidePhotoPath;
  String? _backPhotoPath;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _controllers = {
      for (final metric in BodyMeasurementMetric.values)
        metric: TextEditingController(text: _prefillText(metric)),
    };
    _noteController = TextEditingController();
  }

  String _prefillText(BodyMeasurementMetric metric) {
    final previousCm = widget.previousEntry == null
        ? null
        : metric.valueCm(widget.previousEntry!);
    if (previousCm == null) return '';
    final display = widget.usesImperialUnits
        ? UnitCalc.cmToInches(previousCm)
        : previousCm;
    return display.toStringAsFixed(1);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String? _pathForAngle(ProgressPhotoAngle angle) => switch (angle) {
    ProgressPhotoAngle.front => _frontPhotoPath,
    ProgressPhotoAngle.side => _sidePhotoPath,
    ProgressPhotoAngle.back => _backPhotoPath,
  };

  void _setPathForAngle(ProgressPhotoAngle angle, String? path) {
    switch (angle) {
      case ProgressPhotoAngle.front:
        _frontPhotoPath = path;
      case ProgressPhotoAngle.side:
        _sidePhotoPath = path;
      case ProgressPhotoAngle.back:
        _backPhotoPath = path;
    }
  }

  Future<void> _pickPhoto(ProgressPhotoAngle angle, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return;
      final ownerId =
          '${DateFormat('yyyy-MM-dd').format(_date)}_${angle.name}';
      final bytes = await picked.readAsBytes();
      final relative = await UserImageStorage.importFrom(
        kind: UserImageKind.progressPhoto,
        ownerId: ownerId,
        sourceBytes: bytes,
      );
      // Bust the cache so a replaced photo shows up immediately instead of
      // redrawing the previous bytes for the same (reused) relative path.
      await UserImageStorage.evictCache(relative);
      if (!mounted) return;
      setState(() => _setPathForAngle(angle, relative));
    } catch (_) {
      // Best-effort — a picker/compression failure just leaves the slot
      // empty rather than blocking the rest of the entry from saving.
    }
  }

  Future<void> _removePhoto(ProgressPhotoAngle angle) async {
    final current = _pathForAngle(angle);
    if (current == null) return;
    await UserImageStorage.delete(current);
    if (!mounted) return;
    setState(() => _setPathForAngle(angle, null));
  }

  void _submit() {
    double? parse(BodyMeasurementMetric metric) {
      final raw = _controllers[metric]!.text.trim();
      if (raw.isEmpty) return null;
      final value = double.tryParse(raw.replaceAll(',', '.'));
      if (value == null) return null;
      return widget.usesImperialUnits ? UnitCalc.inchesToCm(value) : value;
    }

    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      BodyMeasurementEntity(
        date: _date,
        neckCm: parse(BodyMeasurementMetric.neck),
        shouldersCm: parse(BodyMeasurementMetric.shoulders),
        chestCm: parse(BodyMeasurementMetric.chest),
        waistCm: parse(BodyMeasurementMetric.waist),
        hipsCm: parse(BodyMeasurementMetric.hips),
        bicepsCm: parse(BodyMeasurementMetric.biceps),
        thighCm: parse(BodyMeasurementMetric.thigh),
        note: note.isEmpty ? null : note,
        frontPhotoPath: _frontPhotoPath,
        sidePhotoPath: _sidePhotoPath,
        backPhotoPath: _backPhotoPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final unit = widget.usesImperialUnits ? s.inLabel : s.cmLabel;
    final dateLabel = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_date);

    return AlertDialog(
      title: Text(s.bodyMeasurementsAddEntry),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(s.bodyMeasurementsDateLabel),
              subtitle: Text(dateLabel),
              onTap: _pickDate,
            ),
            const SizedBox(height: 4),
            Text(s.bodyMeasurementsPhotosLabel, style: Theme.of(context).textTheme.titleSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final angle in ProgressPhotoAngle.values)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        angle.label(context),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      UserImagePickerTile(
                        kind: UserImageKind.progressPhoto,
                        imagePath: _pathForAngle(angle),
                        avatarSize: 68,
                        semanticsIdentifierOverride:
                            'body-measurements-photo-picker-${angle.name}',
                        onPickFromGallery: () =>
                            _pickPhoto(angle, ImageSource.gallery),
                        onTakePhoto: () =>
                            _pickPhoto(angle, ImageSource.camera),
                        onRemove: () => _removePhoto(angle),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final metric in BodyMeasurementMetric.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  identifier: 'body-measurements-field-${metric.name}',
                  child: TextField(
                    controller: _controllers[metric],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '${metric.label(context)} ($unit)',
                    ),
                  ),
                ),
              ),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(labelText: s.bodyMeasurementsNoteLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.dialogCancelLabel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(s.dialogOKLabel),
        ),
      ],
    );
  }
}
