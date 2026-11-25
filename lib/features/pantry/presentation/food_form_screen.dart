import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/offline_error.dart';
import '../../../core/connectivity/online_status.dart';
import '../../../core/connectivity/sync_status.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/pantry_providers.dart';
import '../domain/shelf_life.dart';
import 'food_form_entry.dart';
import 'formatters.dart';

/// Figma "Food Details" (355:94 / 400:187).
///
/// * Add mode: one entry per scanned photo/barcode (or one manual entry).
///   The thumbnails on top switch between entries; "×" removes one.
/// * Edit mode ("Edit food details", PRD §3.4): every text field is
///   editable, the photo is locked, and "×" on the photo deletes the item.
class FoodFormScreen extends ConsumerStatefulWidget {
  const FoodFormScreen.add({super.key, required this.entries}) : item = null;

  const FoodFormScreen.edit({super.key, required FoodItem this.item})
    : entries = const [];

  final List<FoodFormEntry> entries;
  final FoodItem? item;

  bool get isEdit => item != null;

  @override
  ConsumerState<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends ConsumerState<FoodFormScreen> {
  late final List<FoodFormEntry> _entries;
  int _selected = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // In add mode the caller's list is shared on purpose: entries removed here
    // are also gone when the user goes back to the scanner.
    _entries = widget.isEdit
        ? [FoodFormEntry.fromItem(widget.item!)]
        : (widget.entries.isEmpty ? <FoodFormEntry>[] : widget.entries);
    if (widget.isEdit) {
      ref.read(photoStoreProvider).find(widget.item!.foodId).then((file) {
        if (mounted && file != null) {
          setState(() => _entries.first.photoFile = file);
        }
      });
    }
    if (_entries.isEmpty) {
      _entries.add(
        FoodFormEntry(
          name: '',
          category: 'Others',
          location: StorageLocation.fridge,
          purchaseDate: dateOnly(DateTime.now()),
        ),
      );
    }
  }

  FoodFormEntry get _current => _entries[_selected];

  Future<void> _removeEntry(int index) async {
    if (widget.isEdit) {
      await _deleteItem();
      return;
    }
    if (_entries.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _entries.removeAt(index);
      _selected = _selected.clamp(0, _entries.length - 1);
      _error = null;
    });
  }

  Future<void> _deleteItem() async {
    final item = widget.item!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this food?'),
        content: Text(
          '${item.name} will be removed from your pantry, together with its '
          'photo and reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(pantryControllerProvider.notifier).remove(item.foodId);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${item.name} deleted')));
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = isOfflineError(error)
              ? offlineActionMessage
              : 'Could not delete. Please try again.';
        });
      }
    }
  }

  Future<void> _save() async {
    for (var i = 0; i < _entries.length; i++) {
      final message = _entries[i].validate();
      if (message != null) {
        setState(() {
          _selected = i;
          _error = message;
        });
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(pantryControllerProvider.notifier);
    try {
      if (widget.isEdit) {
        await controller.edit(_current.applyTo(widget.item!));
        if (mounted) Navigator.of(context).pop();
        return;
      }
      for (final e in _entries) {
        await controller.add(e.toDraft(), photo: e.photoBytes);
      }
      if (!mounted) return;
      final count = _entries.length;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? '${_entries.first.name.trim()} added to your pantry'
                : '$count foods added to your pantry',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          // A connection lost mid-save gets the same explanation as the
          // disabled buttons instead of a generic retry (PRD §7.5).
          _error = isOfflineError(error)
              ? offlineActionMessage
              : 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // `writeBlockedProvider` also covers a network without internet, where a
    // write would fail even though connectivity reports "connected".
    final canWrite = !ref.watch(writeBlockedProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the dark photo header.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 420,
              child: _HeaderPhoto(entry: _current),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 300 + topInset),
                    if (_entries.any((e) => e.hasPhoto))
                      _PhotoStrip(entries: _entries),
                    const SizedBox(height: 16),
                    _Sheet(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Thumbnails(
                            entries: _entries,
                            selected: _selected,
                            removable: !widget.isEdit || canWrite,
                            onSelect: (i) => setState(() {
                              _selected = i;
                              _error = null;
                            }),
                            onRemove: _removeEntry,
                          ),
                          const SizedBox(height: 20),
                          _FormCard(
                            key: ObjectKey(_current),
                            entry: _current,
                            canRemove: !widget.isEdit || canWrite,
                            onRemove: () => _removeEntry(_selected),
                            onChanged: () => setState(() => _error = null),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: topInset + 16,
              left: 24,
              right: 24,
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    background: AppColors.glassButton,
                    shadow: false,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Food Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    background: AppColors.glassButton,
                    shadow: false,
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: widget.isEdit ? 'Save' : 'Add Food',
                    busy: _saving,
                    onPressed: canWrite ? _save : null,
                  ),
                  if (!canWrite)
                    const ColoredBox(
                      color: AppColors.background,
                      child: OfflineHint(offlineActionMessage),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPhoto extends StatelessWidget {
  const _HeaderPhoto({required this.entry});

  final FoodFormEntry entry;

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (entry.photoBytes != null) {
      image = Image.memory(entry.photoBytes!, fit: BoxFit.cover);
    } else if (entry.photoFile != null) {
      image = Image.file(entry.photoFile!, fit: BoxFit.cover);
    } else {
      image = const ColoredBox(
        color: AppColors.primary,
        child: Center(
          child: Icon(Icons.restaurant, color: Colors.white54, size: 72),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0x66000000), Color(0x00000000)],
            ),
          ),
        ),
      ],
    );
  }
}

/// White pill with small round previews of every captured photo.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.entries});

  final List<FoodFormEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in entries.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipOval(
                child: SizedBox(width: 40, height: 40, child: _entryImage(e)),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _entryImage(FoodFormEntry e) {
  if (e.photoBytes != null) {
    return Image.memory(e.photoBytes!, fit: BoxFit.cover);
  }
  if (e.photoFile != null) {
    return Image.file(e.photoFile!, fit: BoxFit.cover);
  }
  return const ColoredBox(
    color: AppColors.primarySoft,
    child: Icon(Icons.restaurant, color: AppColors.primary, size: 20),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: child,
  );
}

class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.entries,
    required this.selected,
    required this.removable,
    required this.onSelect,
    required this.onRemove,
  });

  final List<FoodFormEntry> entries;
  final int selected;
  final bool removable;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, i) => Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: i == selected
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                    boxShadow: appCardShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: _entryImage(entries[i]),
                  ),
                ),
              ),
            ),
            if (removable)
              Positioned(
                top: 0,
                right: 0,
                child: _RemoveBadge(
                  onTap: () => onRemove(i),
                  label: 'Remove photo',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFFE6E6E3),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 12, color: AppColors.textPrimary),
      ),
    ),
  );
}

class _FormCard extends StatefulWidget {
  const _FormCard({
    super.key,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final FoodFormEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<_FormCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.entry.name,
  );
  late final TextEditingController _qty = TextEditingController(
    text: widget.entry.quantityText,
  );

  FoodFormEntry get e => widget.entry;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  Future<void> _pickPurchaseDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: e.purchaseDate.isAfter(today) ? today : e.purchaseDate,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked != null) _update(() => e.purchaseDate = picked);
  }

  Future<void> _pickEndDate() async {
    final first = computeEstimatedEndDate(e.purchaseDate, 1);
    final initial = e.estimatedEndDate.isBefore(first)
        ? first
        : e.estimatedEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(first.year + 5),
      helpText: 'Shelf life estimate',
    );
    if (picked != null) _update(() => e.setEstimatedEndDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: widget.canRemove
                ? Semantics(
                    button: true,
                    label: 'Remove this food',
                    child: GestureDetector(
                      onTap: widget.onRemove,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(height: 22),
          ),
          const _Label('Food Name'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration(),
            onChanged: (v) => _update(() => e.name = v),
          ),
          if (e.lowConfidence)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'We are not sure about this result. Please check the name.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          const SizedBox(height: 16),
          const _Label('Category'),
          DropdownButtonFormField<String>(
            initialValue: e.category,
            isExpanded: true,
            decoration: _fieldDecoration(),
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(Icons.keyboard_arrow_down),
            items: [
              for (final c in foodCategories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => _update(() => e.category = v ?? e.category),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Location'),
                    DropdownButtonFormField<StorageLocation>(
                      initialValue: e.location,
                      isExpanded: true,
                      decoration: _fieldDecoration(),
                      dropdownColor: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: const [
                        // Order from the Figma location dropdown.
                        DropdownMenuItem(
                          value: StorageLocation.fridge,
                          child: Text('Fridge'),
                        ),
                        DropdownMenuItem(
                          value: StorageLocation.roomTemperature,
                          child: Text('Pantry'),
                        ),
                        DropdownMenuItem(
                          value: StorageLocation.freezer,
                          child: Text('Freezer'),
                        ),
                      ],
                      onChanged: (v) =>
                          _update(() => e.location = v ?? e.location),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Qty / Size'),
                    TextField(
                      controller: _qty,
                      decoration: _fieldDecoration(hint: 'e.g. 1 bunch'),
                      onChanged: (v) => _update(() => e.quantityText = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Purchase Date'),
          _DateBox(
            text: formatDisplayDate(e.purchaseDate),
            showIcon: true,
            onTap: _pickPurchaseDate,
          ),
          const SizedBox(height: 16),
          const _Label('Shelf Life Estimate'),
          _DateBox(
            text: formatDisplayDate(e.estimatedEndDate),
            onTap: _pickEndDate,
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({String? hint}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textLabel,
      ),
    ),
  );
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.text,
    required this.onTap,
    this.showIcon = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool showIcon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            const Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
          ],
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    ),
  );
}
