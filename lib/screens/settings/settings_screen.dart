import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../services/billing_service.dart';
import '../../services/settings_service.dart';
import 'pro_upgrade_screen.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final BillingService billingService;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.billingService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _footerController;

  bool _isSavingInfo = false;
  String? _lastSavedText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.settingsService.storeName);
    _addressController = TextEditingController(text: widget.settingsService.storeAddress);
    _footerController = TextEditingController(text: widget.settingsService.receiptFooter);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreInfo() async {
    if (_isSavingInfo) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSavingInfo = true);

    try {
      await widget.settingsService.updateStoreInfo(
        name: _nameController.text,
        address: _addressController.text,
        footer: _footerController.text,
      );

      // Sinkronkan controller dengan nilai final yang tersimpan
      _nameController.text = widget.settingsService.storeName;
      _addressController.text = widget.settingsService.storeAddress;
      _footerController.text = widget.settingsService.receiptFooter;

      if (mounted) {
        final nowText = formatTimeWithSeconds(DateTime.now());
        setState(() {
          _lastSavedText = 'Tersimpan pada $nowText';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informasi toko berhasil disimpan'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan info toko: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingInfo = false);
      }
    }
  }

  void _openProUpgrade() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProUpgradeScreen(billingService: widget.billingService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListenableBuilder(
        listenable: widget.settingsService,
        builder: (context, _) {
          final isPro = widget.settingsService.isPro;
          final currentMode = widget.settingsService.themeMode;
          final currentColor = widget.settingsService.themeColor;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Kartu Status Pro / Billing
                  Card(
                    color: isPro ? const Color(0xFFFFF8E1) : null,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isPro ? AppTheme.gold : colorScheme.primaryContainer,
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: isPro ? Colors.black87 : colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        isPro ? 'Kasirku Pro Aktif' : 'Upgrade ke Kasirku Pro',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPro ? Colors.black87 : null,
                        ),
                      ),
                      subtitle: Text(
                        isPro
                            ? 'Bebas iklan & produk tanpa batas.'
                            : 'Hapus iklan AdMob & buka produk tanpa batas via Google Play Billing.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPro ? Colors.black54 : null,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: isPro ? Colors.black87 : null,
                      ),
                      onTap: _openProUpgrade,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tema Tampilan (Mode & Warna)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette_outlined, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'Tema Tampilan',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Mode Layar',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _themeModeChip(
                                label: 'Terang',
                                icon: Icons.light_mode_outlined,
                                mode: ThemeMode.light,
                                current: currentMode,
                              ),
                              _themeModeChip(
                                label: 'Gelap',
                                icon: Icons.dark_mode_outlined,
                                mode: ThemeMode.dark,
                                current: currentMode,
                              ),
                              _themeModeChip(
                                label: 'Sistem',
                                icon: Icons.brightness_auto_outlined,
                                mode: ThemeMode.system,
                                current: currentMode,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Warna Utama',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: AppThemeColor.values.map((palette) {
                              final selected = palette == currentColor;
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => widget.settingsService.setThemeColor(palette),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? palette.primary
                                          : Theme.of(context).dividerColor,
                                      width: selected ? 2 : 1,
                                    ),
                                    color: selected
                                        ? palette.primary.withValues(alpha: 0.12)
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: palette.primary,
                                        child: selected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 13,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        palette.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              selected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Informasi Toko & Struk
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront_outlined, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Informasi Toko (Untuk Struk)',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Nama Toko / Usaha',
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nama toko tidak boleh kosong'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Alamat Toko',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _footerController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Catatan Bawah Struk',
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                            if (_lastSavedText != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _lastSavedText!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isSavingInfo ? null : _saveStoreInfo,
                                icon: _isSavingInfo
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _isSavingInfo ? 'Menyimpan...' : 'Simpan Info Toko',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Info Aplikasi Offline
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.cloud_off_rounded, color: colorScheme.primary),
                      title: const Text(
                        'Mode 100% Offline',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Semua data produk, info toko, tema, transaksi, dan laporan tersimpan aman di database SQLite perangkat Anda.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _themeModeChip({
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode current,
  }) {
    final selected = mode == current;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: (_) => widget.settingsService.setThemeMode(mode),
    );
  }
}
