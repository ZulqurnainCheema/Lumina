import 'package:flutter/material.dart';
import 'package:lumina/models/books.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/services/home_widget_service.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/section_header.dart';

class EditBook extends StatefulWidget {
  const EditBook({super.key, required this.id});

  final int id;

  @override
  State<EditBook> createState() => _EditBookState();
}

class _EditBookState extends State<EditBook> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _bookmarkController = TextEditingController();
  bool _loaded = false;

  TextStyle? get _fieldTextStyle => Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: LuminaColors.white, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    final Books? book = await _databaseServices.getBook(widget.id);
    final int page = await _databaseServices.getCurrentPage(widget.id);
    if (!mounted || book == null) {
      return;
    }
    setState(() {
      _titleController.text = book.title;
      _authorController.text = book.author;
      _pagesController.text = '${book.totalPages}';
      _bookmarkController.text = '$page';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _databaseServices.updateBook(widget.id, {
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim(),
      'totalPages': int.parse(_pagesController.text.trim()),
    });
    await _databaseServices.setBookmark(
      widget.id,
      int.parse(_bookmarkController.text.trim()),
    );
    await HomeWidgetService.update();
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit book', style: textTheme.displayLarge),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _titleController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Please enter a title for the book'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _authorController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(
                            labelText: 'Author',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Please enter the author of the book'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pagesController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(
                            labelText: 'Total pages',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final int? pages = int.tryParse(
                              (value ?? '').trim(),
                            );
                            if (pages == null || pages < 1) {
                              return 'Please enter the total number of pages';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        const SectionHeader(label: 'Bookmark'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bookmarkController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(
                            labelText: 'Page you are on',
                            helperText:
                                'Fixes your place without logging a session.',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final int? page = int.tryParse(
                              (value ?? '').trim(),
                            );
                            final int? total = int.tryParse(
                              _pagesController.text.trim(),
                            );
                            if (page == null || page < 0) {
                              return 'Please enter a page number';
                            }
                            if (total != null && page > total) {
                              return 'The book has $total pages';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _save,
                          child: const Text('Save changes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
