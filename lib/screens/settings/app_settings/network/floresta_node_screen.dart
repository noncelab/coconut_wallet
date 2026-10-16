import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/floresta_peer_info.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/floresta_node_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Floresta 노드 설정/디버그 화면.
///
/// 임베드 노드 생명주기/동기화/피어/체인 상태를 노출하고, raw RPC로 디버깅한다.
/// IP 입력은 외부 Floresta에 연결할 때만 노출된다.
class FlorestaNodeScreen extends StatefulWidget {
  const FlorestaNodeScreen({super.key});

  @override
  State<FlorestaNodeScreen> createState() => _FlorestaNodeScreenState();
}

class _FlorestaNodeScreenState extends State<FlorestaNodeScreen> {
  late FlorestaNodeViewModel _viewModel;

  final _hostController = TextEditingController();
  final _electrumPortController = TextEditingController();
  final _rpcPortController = TextEditingController();
  final _rawParamsController = TextEditingController();

  bool _isEmbedded = true;
  bool _ssl = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    final server = nodeProvider.currentElectrumServer;
    final backend = nodeProvider.backend;
    _isEmbedded = backend.isEmbedded;
    _ssl = server.ssl;
    _hostController.text = backend.isEmbedded ? '' : server.host;
    _electrumPortController.text = server.port.toString();
    _rpcPortController.text = backend.rpcPort.toString();
    _rawParamsController.text = '[]';
  }

  @override
  void dispose() {
    _hostController.dispose();
    _electrumPortController.dispose();
    _rpcPortController.dispose();
    _rawParamsController.dispose();
    super.dispose();
  }

  Future<void> _applyMode() async {
    final electrumPort = int.tryParse(_electrumPortController.text) ?? 50001;
    final rpcPort = int.tryParse(_rpcPortController.text) ?? 8332;
    setState(() => _applying = true);
    final bool ok;
    if (_isEmbedded) {
      ok = await _viewModel.switchToEmbedded(electrumPort: electrumPort, rpcPort: rpcPort);
    } else {
      ok = await _viewModel.switchToExternal(
        host: _hostController.text.trim(),
        port: electrumPort,
        rpcPort: rpcPort,
        ssl: _ssl,
      );
    }
    if (!mounted) return;
    setState(() {
      _applying = false;
      _hostController.text = _isEmbedded ? '' : _viewModel.host;
      _electrumPortController.text = _viewModel.electrumPort.toString();
      _rpcPortController.text = _viewModel.rpcPort.toString();
    });
    _showSnack(ok ? t.floresta_node.switch_success : t.floresta_node.switch_failed);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyDump() async {
    await Clipboard.setData(ClipboardData(text: _viewModel.buildDump()));
    if (!mounted) return;
    _showSnack(t.copied);
  }

  Future<void> _confirmStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(t.floresta_node.confirm_stop),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t.confirm)),
        ],
      ),
    );
    if (confirmed == true) await _viewModel.stopNode();
  }

  /// 노드 정지 버튼은 regtest + debug 빌드에서만 노출한다.
  /// mainnet/release에서는 상태를 되돌릴 수 없는 위험을 피하려고 숨긴다.
  bool get _canStopNode => kDebugMode && NetworkType.currentNetworkType == NetworkType.regtest;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FlorestaNodeViewModel>(
      create: (_) {
        _viewModel = FlorestaNodeViewModel(Provider.of<NodeProvider>(context, listen: false));
        return _viewModel;
      },
      child: Consumer<FlorestaNodeViewModel>(
        builder: (context, viewModel, _) {
          final colors = context.coconutColors;
          return Scaffold(
            backgroundColor: colors.background,
            appBar: CoconutAppBar.build(title: t.floresta_node.title, context: context, isBottom: true),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(t.floresta_node.sync),
                  _card(_buildSyncSection(viewModel)),
                  CoconutLayout.spacing_400h,

                  _section(t.floresta_node.peers),
                  _card(_buildPeersSection(viewModel)),
                  CoconutLayout.spacing_400h,

                  _section(t.floresta_node.chain),
                  _card(_buildChainSection(viewModel)),
                  CoconutLayout.spacing_400h,

                  // 고급: 연결 모드 / 노드 상태 / 디버그
                  _section(t.floresta_node.advanced),
                  _card(_buildModeSection()),
                  CoconutLayout.spacing_400h,
                  _card(_buildStatusSection(viewModel)),
                  if (kDebugMode) ...[
                    CoconutLayout.spacing_400h,
                    _card(_buildDebugSection(viewModel)),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 4.1 연결 모드 ────────────────────────────────────────────────────────────
  Widget _buildModeSection() {
    final colors = context.coconutColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _modeButton(t.floresta_node.mode_embedded, _isEmbedded, () => setState(() => _isEmbedded = true))),
            const SizedBox(width: 8),
            Expanded(child: _modeButton(t.floresta_node.mode_external, !_isEmbedded, () => setState(() => _isEmbedded = false))),
          ],
        ),
        const SizedBox(height: 16),
        // 임베드 모드에서는 IP를 렌더/검증/표시하지 않는다.
        if (!_isEmbedded) ...[
          _field(_hostController, t.floresta_node.host, hint: t.floresta_node.host_hint),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_electrumPortController, t.floresta_node.electrum_port, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field(_rpcPortController, t.floresta_node.rpc_port, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(t.floresta_node.use_ssl, style: CoconutTypography.body3_12.setColor(colors.primaryText)),
              const Spacer(),
              CoconutSwitch(
                isOn: _ssl,
                activeTrackColor: colors.primary,
                onChanged: (v) => setState(() => _ssl = v),
                scale: 0.75,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t.floresta_node.use_ssl_hint,
              style: CoconutTypography.caption_10.setColor(colors.mutedText),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(child: _field(_electrumPortController, t.floresta_node.electrum_port, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field(_rpcPortController, t.floresta_node.rpc_port, keyboardType: TextInputType.number)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SingleButton(
            title: t.floresta_node.apply,
            onPressed: _applying ? null : _applyMode,
          ),
        ),
      ],
    );
  }

  Widget _modeButton(String label, bool selected, VoidCallback onTap) {
    final colors = context.coconutColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.12) : colors.surface,
          border: Border.all(color: selected ? colors.primary : colors.border, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: CoconutTypography.body2_14_Bold.setColor(selected ? colors.primary : colors.secondaryText),
        ),
      ),
    );
  }

  // ── 4.2 상태 요약 ────────────────────────────────────────────────────────────
  Widget _buildStatusSection(FlorestaNodeViewModel vm) {
    final mode = vm.isFlorestaEmbedded ? t.floresta_node.mode_embedded : t.floresta_node.mode_external;
    return Column(
      children: [
        _row(t.floresta_node.mode, mode),
        _row(t.floresta_node.running, vm.isRunning ? t.floresta_node.running : t.floresta_node.stopped),
        _row(t.floresta_node.platform, vm.platform),
        _row(t.floresta_node.handle, vm.nodeHandle?.toString() ?? '-'),
        _row(t.floresta_node.data_dir, vm.dataDir ?? '-'),
        _row(t.floresta_node.uptime, vm.uptime != null ? '${vm.uptime}s' : '-'),
        _row('host:port', '${vm.host}:${vm.electrumPort}'),
        _row('rpcPort', vm.rpcPort.toString()),
        _row(t.floresta_node.connection_count, vm.connectionCount.toString()),
        _row(t.floresta_node.latency, vm.lastLatencyMs != null ? '${vm.lastLatencyMs}ms' : '-'),
      ],
    );
  }

  // ── 4.3 IBD / 동기화 ─────────────────────────────────────────────────────────
  Widget _buildSyncSection(FlorestaNodeViewModel vm) {
    final colors = context.coconutColors;
    final info = vm.syncInfo;
    final progress = (info?.verificationProgress ?? 0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 진행도를 맨 위에
        Row(
          children: [
            Text(t.floresta_node.progress, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
            const Spacer(),
            Text('${(progress * 100).toStringAsFixed(2)}%', style: CoconutTypography.body2_14_Bold.setColor(colors.primary)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: colors.surfaceInset),
        ),
        const SizedBox(height: 16),
        _row(
          'IBD',
          info == null
              ? '-'
              : (info.initialBlockDownload ? t.floresta_node.ibd_true : t.floresta_node.ibd_false),
          valueColor: info != null && !info.initialBlockDownload ? colors.success : null,
        ),
        _row(t.floresta_node.headers, info?.headers.toString() ?? '-'),
        _row(t.floresta_node.blocks, info?.blocks.toString() ?? '-'),
        _row(t.floresta_node.best_block, info?.bestBlockHash ?? '-', mono: true),
        _row(t.floresta_node.block_time, _formatTime(info?.time)),
      ],
    );
  }

  // ── 4.4 피어 ─────────────────────────────────────────────────────────────────
  Widget _buildPeersSection(FlorestaNodeViewModel vm) {
    final colors = context.coconutColors;
    if (vm.peers.isEmpty) {
      return Row(
        children: [
          Icon(Icons.circle, size: 8, color: colors.danger),
          const SizedBox(width: 8),
          Text(t.floresta_node.no_peers, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(t.floresta_node.connection_count, vm.connectionCount.toString(), valueColor: colors.success),
        const Divider(height: 20),
        ...vm.peers.map((peer) => _peerTile(peer)),
      ],
    );
  }

  Widget _peerTile(FlorestaPeerInfo peer) {
    final colors = context.coconutColors;
    final services = peer.servicesNames.isEmpty ? '-' : peer.servicesNames.join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: peer.isReady ? colors.success : colors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  peer.address,
                  style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('id ${peer.id}', style: CoconutTypography.caption_10.setColor(colors.mutedText)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${peer.userAgent} · ${peer.inbound ? 'inbound' : 'outbound'} · height ${peer.initialHeight} '
            '· ${peer.state} · $services',
            style: CoconutTypography.caption_10.setColor(colors.secondaryText),
          ),
        ],
      ),
    );
  }

  // ── 4.5 체인 / 블록 ──────────────────────────────────────────────────────────
  Widget _buildChainSection(FlorestaNodeViewModel vm) {
    return Column(
      children: [
        _row(t.floresta_node.best_block, vm.bestBlockHash ?? '-', mono: true),
        _row(t.floresta_node.difficulty, vm.difficulty?.toStringAsFixed(4) ?? '-'),
        _row(t.floresta_node.roots, vm.roots.isEmpty ? t.floresta_node.roots_empty : '${vm.roots.length}'),
        if (vm.roots.isNotEmpty)
          ...vm.roots.take(4).map(
            (r) => _row('', r.length > 16 ? '${r.substring(0, 16)}…' : r, mono: true),
          ),
      ],
    );
  }

  // ── 4.6 디버그 ───────────────────────────────────────────────────────────────
  Widget _buildDebugSection(FlorestaNodeViewModel vm) {
    final colors = context.coconutColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.floresta_node.raw_rpc, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
        const SizedBox(height: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: vm.rawMethod,
            isExpanded: true,
            dropdownColor: colors.surface,
            style: CoconutTypography.body3_12.setColor(colors.primaryText),
            items: vm.rawMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (value) {
              if (value != null) vm.setRawMethod(value);
            },
          ),
        ),
        const SizedBox(height: 8),
        _field(
          _rawParamsController,
          t.floresta_node.params,
          onChanged: vm.setRawParams,
          mono: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SingleButton(
                title: t.floresta_node.send,
                onPressed: vm.isRawLoading ? null : vm.sendRawRpc,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: SingleButton(title: t.floresta_node.refresh, onPressed: vm.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        _row(t.floresta_node.last_error, _errorText(vm), valueColor: vm.lastErrorMessage != null ? colors.danger : null),
        if (vm.rawResponse != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(color: colors.surfaceInset, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(
              child: SelectableText(
                vm.rawResponse!,
                style: CoconutTypography.caption_10.setColor(colors.primaryText).copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ButtonGroup(
          buttons: [
            SingleButton(title: t.floresta_node.copy_dump, onPressed: _copyDump),
            if (_canStopNode) SingleButton(title: t.floresta_node.stop_node, onPressed: _confirmStop),
          ],
        ),
      ],
    );
  }

  String _errorText(FlorestaNodeViewModel vm) {
    if (vm.lastErrorMessage == null) return t.floresta_node.none;
    final at = vm.lastErrorAt;
    final time = at == null ? '' : ' (${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')})';
    return '${vm.lastErrorMethod ?? ''}: ${vm.lastErrorMessage}$time';
  }

  String _formatTime(int? epochSeconds) {
    if (epochSeconds == null || epochSeconds == 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── 공통 위젯 ────────────────────────────────────────────────────────────────
  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
    child: Text(title, style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText)),
  );

  Widget _card(Widget child) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool mono = false}) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 110,
              child: Text(label, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
            ),
          ],
          Expanded(
            child: SelectableText(
              value,
              style: CoconutTypography.body3_12
                  .setColor(valueColor ?? colors.primaryText)
                  .copyWith(fontFamily: mono ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? hint,
    bool mono = false,
    ValueChanged<String>? onChanged,
  }) {
    final colors = context.coconutColors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: CoconutTypography.body3_12
          .setColor(colors.primaryText)
          .copyWith(fontFamily: mono ? 'monospace' : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: CoconutTypography.caption_10.setColor(colors.secondaryText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.primary)),
      ),
    );
  }
}
