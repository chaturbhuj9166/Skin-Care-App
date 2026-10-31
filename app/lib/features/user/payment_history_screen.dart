import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/payment_model.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  late Future<List<PaymentModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiRepositoryProvider).fetchMyPayments();
  }

  Future<void> _refresh() async {
    final future = ref.read(apiRepositoryProvider).fetchMyPayments();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<PaymentModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text(apiErrorMessage(snapshot.error!), style: const TextStyle(color: AppColors.error))),
                  ],
                );
              }
              final payments = snapshot.data ?? const [];
              if (payments.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 40),
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No payments yet',
                      subtitle: 'Payments you make when submitting a case will show up here.',
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: payments.length,
                itemBuilder: (context, i) => _PaymentTile(payment: payments[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  const _PaymentTile({required this.payment});

  (Color, Color, String) get _statusStyle {
    switch (payment.status) {
      case 'PAID':
        return (const Color(0xFFECFDF5), const Color(0xFF15803D), 'Paid');
      case 'REFUNDED':
        return (AppColors.surface, AppColors.textMuted, 'Refunded');
      case 'FAILED':
        return (const Color(0xFFFEF2F2), const Color(0xFFB91C1C), 'Failed');
      default:
        return (const Color(0xFFFFFBEB), const Color(0xFFB45309), 'Pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _statusStyle;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${payment.amountRupees.toStringAsFixed(0)} · Dermatologist consultation fee',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  DateFormat('MMM d, yyyy · hh:mm a').format(payment.createdAt),
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
