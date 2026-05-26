import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AmountInput extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final String? label;

  const AmountInput({
    super.key,
    required this.controller,
    this.currency = 'EUR',
    this.label,
  });

  String get _symbol {
    switch (currency) {
      case 'USD': return '\$';
      case 'GBP': return '£';
      default:    return '€';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label ?? 'Amount',
        prefixText: '$_symbol ',
        prefixStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
        ),
      ),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter an amount';
        if (double.tryParse(v) == null) return 'Invalid amount';
        if (double.parse(v) <= 0) return 'Amount must be positive';
        return null;
      },
    );
  }
}
