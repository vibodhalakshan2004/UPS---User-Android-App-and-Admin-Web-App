import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TaxScreen extends StatelessWidget {
  const TaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tax Payments')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Make a Payment',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentForm(context),
            const SizedBox(height: 32),
            Text(
              'Payment History',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentHistory(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Amount (Rs.)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Tax Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'waste',
                  child: Text('Waste Collection'),
                ),
                DropdownMenuItem(
                  value: 'property',
                  child: Text('Property Tax'),
                ),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const FaIcon(
                FontAwesomeIcons.moneyBillWave,
                color: Colors.white,
              ),
              label: const Text('Pay Now'),
              onPressed: () {
                // Handle payment logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(BuildContext context) {
    // Replace with actual data later
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        _buildPaymentHistoryItem(
          context,
          taxType: 'Waste Collection',
          amount: 'Rs. 50.00',
          date: '15 Oct 2023',
          status: 'Paid',
        ),
        _buildPaymentHistoryItem(
          context,
          taxType: 'Property Tax',
          amount: 'Rs. 250.00',
          date: '10 Sep 2023',
          status: 'Paid',
        ),
      ],
    );
  }

  Widget _buildPaymentHistoryItem(
    BuildContext context, {
    required String taxType,
    required String amount,
    required String date,
    required String status,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: FaIcon(
          FontAwesomeIcons.receipt,
          color: theme.colorScheme.secondary,
        ),
        title: Text(taxType),
        subtitle: Text('$amount - $date'),
        trailing: Chip(
          label: Text(status),
          backgroundColor: status == 'Paid'
              ? Colors.green.shade100
              : Colors.orange.shade100,
        ),
      ),
    );
  }
}
