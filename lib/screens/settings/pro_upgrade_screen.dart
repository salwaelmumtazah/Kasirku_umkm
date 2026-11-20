import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/monetization_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/billing_service.dart';

class ProUpgradeScreen extends StatelessWidget {
  final BillingService billingService;

  const ProUpgradeScreen({
    super.key,
    required this.billingService,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Kasirku Pro'),
      ),
      body: ListenableBuilder(
        listenable: billingService,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 56,
                          color: Color(0xFFFFD54F),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          billingService.isPro
                              ? 'Kasirku Pro Aktif!'
                              : 'Buka Semua Fitur Pro',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          billingService.isPro
                              ? 'Terima kasih telah mendukung Kasirku Offline. Semua iklan telah dinonaktifkan.'
                              : 'Nikmati pengalaman kasir offline tanpa iklan & produk tanpa batas.',
                          style: TextStyle(
                            color: colorScheme.onPrimary.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Daftar Keunggulan Pro
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Keuntungan Kasirku Pro',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _benefitRow(
                            colorScheme,
                            Icons.block_rounded,
                            'Bebas iklan AdMob (Banner & Interstitial)',
                          ),
                          _benefitRow(
                            colorScheme,
                            Icons.all_inclusive_rounded,
                            'Jumlah produk tanpa batas (Gratis: maks ${MonetizationConfig.freeProductLimit})',
                          ),
                          _benefitRow(
                            colorScheme,
                            Icons.cloud_off_rounded,
                            'Status Pro tersimpan lokal — tetap aktif saat offline',
                          ),
                          _benefitRow(
                            colorScheme,
                            Icons.verified_user_outlined,
                            'Pembayaran aman via Google Play Billing / App Store',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (billingService.statusMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        billingService.statusMessage!,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  if (billingService.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              billingService.errorMessage!,
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Daftar Paket Billing dari Google Play / App Store
                  if (!billingService.isPro) ...[
                    if (billingService.isLoading)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(color: colorScheme.primary),
                        ),
                      )
                    else if (billingService.products.isNotEmpty)
                      ...billingService.products.map(
                        (product) => _buildProductCard(context, product, colorScheme),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Paket Billing Belum Tersedia',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pastikan perangkat terhubung ke internet dan ID produk '
                                '(${MonetizationConfig.proLifetimeProductId}, ${MonetizationConfig.proMonthlyProductId}) '
                                'sudah dibuat di Google Play Console.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: billingService.loadProducts,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Muat Ulang Paket'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: billingService.isPurchasing
                          ? null
                          : billingService.restorePurchases,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Pulihkan Pembelian Sebelumnya'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductDetails product,
    ColorScheme colorScheme,
  ) {
    final isLifetime = product.id == MonetizationConfig.proLifetimeProductId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isLifetime) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HEMAT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.price,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: billingService.isPurchasing
                  ? null
                  : () => billingService.buyProduct(product),
              child: const Text('Beli'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitRow(ColorScheme colorScheme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
