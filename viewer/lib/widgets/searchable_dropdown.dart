import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

/// Dropdown pesquisável usando Autocomplete do Flutter Material.
class SearchableDropdown<T extends Object> extends StatelessWidget {
  final String name;
  final String labelText;
  final List<T> items;
  final String Function(T) getLabel;
  final String Function(T) getValue;
  final String? initialValue;
  final String? Function(String?)? validator;
  final void Function(String?)? onChanged;

  const SearchableDropdown({
    super.key,
    required this.name,
    required this.labelText,
    required this.items,
    required this.getLabel,
    required this.getValue,
    this.initialValue,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<String>(
      name: name,
      initialValue: initialValue,
      validator: validator,
      builder: (field) {
        T? selectedItem;
        if (initialValue != null && items.isNotEmpty) {
          try {
            selectedItem = items.firstWhere(
              (item) => getValue(item) == initialValue,
            );
          } catch (_) {
            selectedItem = null;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<T>(
              initialValue: selectedItem != null
                  ? TextEditingValue(text: getLabel(selectedItem))
                  : null,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return items;
                }
                final query = textEditingValue.text.toLowerCase();
                return items.where((item) =>
                    getLabel(item).toLowerCase().contains(query));
              },
              displayStringForOption: getLabel,
              onSelected: (T selection) {
                final value = getValue(selection);
                field.didChange(value);
                onChanged?.call(value);
              },
              fieldViewBuilder: (
                BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: 'Digite para pesquisar...',
                    suffixIcon: const Icon(Icons.search),
                    errorText: field.errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (
                BuildContext context,
                AutocompleteOnSelected<T> onSelected,
                Iterable<T> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(getLabel(option)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
