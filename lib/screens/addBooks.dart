import 'package:flutter/material.dart';
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
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  String _coverUrl = 'assets/book.jpg';

  Future<void> fetchCover() async {
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
      response.data['url'] != null
          ? setState(() {
              _coverUrl = response.data['url'].toString();
            })
          : debugPrint('Cover URL not found in response');
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.message}');
      debugPrint('response: ${e.response?.statusCode} ${e.response?.data}');
    } catch (e) {
      debugPrint('Unexpected error: $e');
    }
  }

  Future Submit() async {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Processing Data')));
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
                        SizedBox(height: 30),

                        TextButton(
                          onPressed: () async {
                            await fetchCover();
                          },
                          style: Theme.of(context).textButtonTheme.style,
                          child: Text('Fetch Cover'),
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
                            child: Image.network(
                              _coverUrl,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/book.jpg',
                                  height: 200,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 50),
                        ElevatedButton(
                          onPressed: () async {
                            await Submit();
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
