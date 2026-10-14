import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/services/database_services.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/services/cover_services.dart';
import 'package:lumina/widgets/cover_picker.dart';

class Addbooks extends StatefulWidget {
  const Addbooks({super.key});

  @override
  State<Addbooks> createState() => _AddbooksState();
}

class _AddbooksState extends State<Addbooks> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController();
  String _coverUrl = '';
  bool _isFetchingCover = false;

  TextStyle? get _fieldTextStyle => Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: LuminaColors.white, fontWeight: FontWeight.w500);

  Future<void> fetchCover() async {
    if (_isFetchingCover) {
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _showMessage('Type the title first.');
      return;
    }
    setState(() {
      _isFetchingCover = true;
    });
    try {
      final String? cover = await CoverServices.instance.findCover(
        _titleController.text,
        _authorController.text,
      );
      if (!mounted) {
        return;
      }
      if (cover == null) {
        _showMessage(
          'No cover found for that title. The book will get a coloured cover.',
        );
      } else {
        setState(() {
          _coverUrl = cover;
        });
      }
    } catch (e) {
      debugPrint('Cover lookup failed: $e');
      _showMessage('Could not reach the cover service. Check your connection.');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCover = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final String? path = await CoverServices.instance.pickCoverFromGallery();
      if (path == null || !mounted) {
        return;
      }
      // A photo chosen earlier and then replaced is no longer needed.
      await CoverServices.deleteStoredCover(_coverUrl);
      setState(() {
        _coverUrl = path;
      });
    } catch (e) {
      debugPrint('Gallery cover failed: $e');
      _showMessage('Could not use that image.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final newBook = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'coverUrl': _coverUrl,
        'totalPages': int.parse(_pagesController.text.trim()),
        'status': 'to-read',
        'createdAt': DateTime.now().toIso8601String(),
      };
      await _databaseServices.addBook(newBook);
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Book added successfully!')));
        GoRouter.of(context).pop(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: Align(
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
                  Text('Add a book', style: textTheme.displayLarge),
                  SizedBox(height: 8),
                  Text(
                    'The page count lets Lumina tell you how much is left.',
                    style: textTheme.bodySmall,
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    style: _fieldTextStyle,
                    decoration: InputDecoration(labelText: 'Title'),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title for the book';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _authorController,
                    style: _fieldTextStyle,
                    decoration: InputDecoration(labelText: 'Author'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the author of the book';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _pagesController,
                    style: _fieldTextStyle,
                    decoration: InputDecoration(labelText: 'Total pages'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the total number of pages';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  CoverPicker(
                    coverUrl: _coverUrl,
                    title: _titleController.text,
                    busy: _isFetchingCover,
                    onFind: fetchCover,
                    onGallery: _pickFromGallery,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      await _submit(context);
                    },
                    child: Text('Add book'),
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
