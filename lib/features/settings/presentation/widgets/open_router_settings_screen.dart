import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/open_router_model_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_open_router_models_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FR-01: lets the user paste their own OpenRouter API key (bring-your-own-
/// key — OpenRouter is a proxy in front of many LLM providers, billed to the
/// user's own account) and pick a model from OpenRouter's full catalog. The
/// catalog endpoint is public, so the model list loads and is searchable
/// even before a key is entered; only actually sending a chat completion
/// (FR-02's job, not this screen's) requires the key to be valid.
class OpenRouterSettingsScreen extends StatefulWidget {
  final GetConfigUsecase? getConfigUsecase;
  final GetOpenRouterModelsUsecase? getOpenRouterModelsUsecase;
  final ConfigRepository? configRepository;

  const OpenRouterSettingsScreen({
    super.key,
    this.getConfigUsecase,
    this.getOpenRouterModelsUsecase,
    this.configRepository,
  });

  @override
  State<OpenRouterSettingsScreen> createState() =>
      _OpenRouterSettingsScreenState();
}

class _OpenRouterSettingsScreenState extends State<OpenRouterSettingsScreen> {
  late final GetConfigUsecase _getConfigUsecase =
      widget.getConfigUsecase ?? locator<GetConfigUsecase>();
  late final GetOpenRouterModelsUsecase _getModelsUsecase =
      widget.getOpenRouterModelsUsecase ??
      locator<GetOpenRouterModelsUsecase>();
  late final ConfigRepository _configRepository =
      widget.configRepository ?? locator<ConfigRepository>();

  final _apiKeyController = TextEditingController();
  final _searchController = TextEditingController();
  bool _obscureApiKey = true;
  String? _selectedModelId;

  bool _loadingModels = true;
  String? _modelsError;
  List<OpenRouterModelEntity> _models = const [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _getConfigUsecase.getConfig();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = config.openRouterApiKey ?? '';
      _selectedModelId = config.openRouterModelId;
    });
    await _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });
    try {
      final models = await _getModelsUsecase.getModels();
      if (!mounted) return;
      setState(() {
        _models = models;
        _loadingModels = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _modelsError = S.of(context).openRouterModelsLoadError;
        _loadingModels = false;
      });
    }
  }

  Future<void> _saveApiKey() async {
    final value = _apiKeyController.text.trim();
    await _configRepository.setConfigOpenRouterApiKey(
      value.isEmpty ? null : value,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).openRouterApiKeySavedSnackbar)),
    );
  }

  Future<void> _selectModel(OpenRouterModelEntity model) async {
    setState(() => _selectedModelId = model.id);
    await _configRepository.setConfigOpenRouterModelId(model.id);
  }

  List<OpenRouterModelEntity> get _filteredModels {
    if (_searchQuery.isEmpty) return _models;
    final query = _searchQuery.toLowerCase();
    return _models
        .where(
          (m) =>
              m.name.toLowerCase().contains(query) ||
              m.id.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.openRouterSettingsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  identifier: 'openrouter-api-key-field',
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: s.openRouterApiKeyLabel,
                      hintText: s.openRouterApiKeyHint,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    identifier: 'openrouter-api-key-save',
                    child: FilledButton(
                      onPressed: _saveApiKey,
                      child: Text(s.buttonSaveLabel),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  s.openRouterModelSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Semantics(
                  identifier: 'openrouter-model-search',
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: s.openRouterModelSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildModelList(context)),
        ],
      ),
    );
  }

  Widget _buildModelList(BuildContext context) {
    final s = S.of(context);
    if (_loadingModels) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_modelsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_modelsError!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadModels, child: Text(s.retryLabel)),
          ],
        ),
      );
    }
    final filtered = _filteredModels;
    if (filtered.isEmpty) {
      return Center(child: Text(s.openRouterModelsEmptyState));
    }
    return Semantics(
      identifier: 'openrouter-model-list',
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final model = filtered[index];
          final isSelected = model.id == _selectedModelId;
          return ListTile(
            title: Text(model.name),
            subtitle: Text(model.id),
            leading: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : const Icon(Icons.circle_outlined),
            trailing: model.supportsImages
                ? Tooltip(
                    message: s.openRouterVisionBadgeTooltip,
                    child: const Icon(Icons.image_outlined),
                  )
                : null,
            selected: isSelected,
            onTap: () => _selectModel(model),
          );
        },
      ),
    );
  }
}
