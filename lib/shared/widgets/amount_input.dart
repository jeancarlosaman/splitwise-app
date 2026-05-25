import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/utils/currency_utils.dart';

/// A text field tailored for currency amount input.
/// Shows a currency symbol prefix and restricts input to valid decimal numbers.
class AmountInput extends StatelessWidget {
  const AmountInput({
    super.key,
    required this.controller,
    required this.currency,
    this.onChanged,
    this.label = 'Amount',
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String currency;
  final ValueChanged<String>? onChanged;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
      ],
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            CurrencyUtils.symbol(currency),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter an amount';
        final parsed = CurrencyUtils.tryParse(value);
        if (parsed == null) return 'Invalid amount';
        if (parsed <= 0) return 'Amount must be greater than 0';
        return null;
      },
      onChanged: onChanged,
    );
  }
}

/// Dropdown for selecting a currency.
class CurrencySelector extends StatelessWidget {
  const CurrencySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Currency',
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: AppConstants.currencies
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text('${CurrencyUtils.symbol(c)}  $c'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
