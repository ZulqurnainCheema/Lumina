import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reading_assist/services/database_services.dart';
import 'package:reading_assist/theme.dart';
import 'package:dio/dio.dart';

class Addbooks extends StatefulWidget {
  const Addbooks({super.key});

  @override
  State<Addbooks> createState() => _AddbooksState();
}

class _AddbooksState extends State<Addbooks> {
  final dio = Dio();
  final _formKey = GlobalKey<FormState>();
  final DatabaseServices _databaseServices = DatabaseServices.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController();
  String _coverUrl = 'assets/book.jpg';
  bool _isFetchingCover = false;

  Future<void> fetchCover() async {
    if (_isFetchingCover) {
      return;
    }
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isFetchingCover = true;
        });
      });
    }
    try {
      debugPrint('fetchCover called');
      final response = await dio.get(
        'https://bookcover.longitood.com/bookcover',
        queryParameters: {
          'book_title': _titleController.text.trim(),
          'author_name': _authorController.text.trim(),
          'size': 'large',
        },
      );
      debugPrint('status: ${response.statusCode}');
      debugPrint('data: ${response.data}');
      if (response.data['url'] != null) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _coverUrl = response.data['url'].toString();
              });
            }
          });
        }
      } else {
        debugPrint('Cover URL not found in response');
      }
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.message}');
      debugPrint('response: ${e.response?.statusCode} ${e.response?.data}');
    } catch (e) {
      debugPrint('Unexpected error: $e');
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isFetchingCover = false;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    dio.close();
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
    return Scaffold(
      appBar: AppBar(title: Text('Add Books')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: LuminaColors.accent),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: LuminaColors.accent.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add New Books',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Expand your Digital Library',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  SizedBox(height: 30),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            hintText: 'Enter the title of the book',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title for the book';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _authorController,
                          decoration: InputDecoration(
                            labelText: 'Author',
                            hintText: 'Enter the author of the book',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the author of the book';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _pagesController,
                          decoration: InputDecoration(
                            labelText: 'Total Pages',
                            hintText: 'Enter the total number of pages',
                          ),
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
                        SizedBox(height: 30),

                        TextButton(
                          onPressed: fetchCover,
                          style: Theme.of(context).textButtonTheme.style,
                          child: Text(
                            _isFetchingCover
                                ? 'Fetching Cover...'
                                : 'Fetch Cover',
                          ),
                        ),
                        SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: LuminaColors.accent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: LuminaColors.accent.withAlpha(30),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.network(
                                  _coverUrl,
                                  height: 220,
                                  width: 140,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/book.jpg',
                                      height: 220,
                                      width: 140,
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                                if (_isFetchingCover)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: LuminaColors.background
                                            .withAlpha(210),
                                      ),
                                      child: Center(
                                        child: const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 50),
                        ElevatedButton(
                          onPressed: () async {
                            await _submit(context);
                          },
                          child: Text('Add Book'),
                        ),
                      ],
                    ),
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
