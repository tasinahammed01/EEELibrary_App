import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../../catalog/widgets/catalog_widgets.dart';
import '../domain/purchase_models.dart';

class ManualPaymentForm extends StatefulWidget {
  const ManualPaymentForm({
    super.key,
    required this.options,
    required this.busy,
    required this.onSubmit,
    this.errorMessage,
  });
  final List<ManualPaymentOption> options;
  final bool busy;
  final String? errorMessage;
  final Future<void> Function(String method, String reference) onSubmit;
  @override
  State<ManualPaymentForm> createState() => _ManualPaymentFormState();
}

class _ManualPaymentFormState extends State<ManualPaymentForm> {
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController();
  String? _method;
  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options.firstWhere(
      (option) => option.method == _method,
      orElse: () => widget.options.first,
    );
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected.method,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              for (final option in widget.options)
                DropdownMenuItem(
                  value: option.method,
                  child: Text(option.method),
                ),
            ],
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _method = value),
          ),
          const SizedBox(height: AppSpace.sm),
          CatalogNotice(message: selected.instructions),
          if (selected.development) ...[
            const SizedBox(height: AppSpace.xs),
            const Text('Development testing only — do not send real money.'),
          ],
          const SizedBox(height: AppSpace.sm),
          TextFormField(
            controller: _reference,
            enabled: !widget.busy,
            maxLength: 100,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Transaction reference',
              helperText: 'Use the reference from your payment confirmation.',
            ),
            validator: (value) =>
                RegExp(r'^[A-Za-z0-9]{3,100}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Enter 3–100 letters or digits.',
          ),
          const SizedBox(height: AppSpace.sm),
          const Text(
            'Submitting a reference does not grant access. An authorized reviewer must verify and approve it.',
          ),
          const SizedBox(height: AppSpace.sm),
          if (widget.errorMessage != null) ...[
            CatalogNotice(message: widget.errorMessage!),
            const SizedBox(height: AppSpace.sm),
          ],
          FilledButton(
            onPressed: widget.busy
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    FocusScope.of(context).unfocus();
                    await widget.onSubmit(selected.method, _reference.text);
                  },
            child: Text(
              widget.busy ? 'Submitting…' : 'Submit payment reference',
            ),
          ),
        ],
      ),
    );
  }
}
