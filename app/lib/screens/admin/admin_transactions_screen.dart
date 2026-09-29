import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/payment_transaction.dart';
import '../../presentation/utils/date_formatter.dart';
import '../../theme/app_colors.dart';

/// Admin view of every recorded payment transaction, with per-order details.
class AdminTransactionsScreen extends ConsumerWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Could not load transactions.\n$e')),
        data: (transactions) {
          if (transactions.isEmpty) return const _NoTransactions();
          final total = transactions.fold<int>(
            0,
            (sum, t) => sum + t.amountRupees,
          );
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: transactions.length + 1,
            separatorBuilder: (_, i) => const SizedBox(height: 11),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _SummaryHeader(count: transactions.length, total: total);
              }
              return _TransactionCard(transaction: transactions[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int count;
  final int total;

  const _SummaryHeader({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const Text(
                  'Transactions',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
              const Text(
                'Total collected',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final PaymentTransaction transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${transaction.orderId}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.customerName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${transaction.amountRupees}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Date',
            value: formatDateTime(transaction.createdAt),
          ),
          if (transaction.customerPhone != null &&
              transaction.customerPhone!.isNotEmpty)
            _DetailRow(label: 'Phone', value: transaction.customerPhone!),
          _DetailRow(label: 'Status', value: transaction.status.toUpperCase()),
          _DetailRow(label: 'Method', value: transaction.method.toUpperCase()),
          _DetailRow(
            label: 'Payment ID',
            value: transaction.razorpayPaymentId,
            copyable: true,
          ),
          _DetailRow(
            label: 'Order Ref',
            value: transaction.razorpayOrderId,
            copyable: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          if (copyable)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$label copied')));
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy, size: 14, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoTransactions extends StatelessWidget {
  const _NoTransactions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.muted),
          SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Confirmed customer payments will appear here',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
