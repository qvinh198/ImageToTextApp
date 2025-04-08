import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(ImageToTextApp());

class ImageToTextApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image to Text',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<XFile> _images = [];
  final List<String> _texts = [];

  bool _isProcessing = false;
  final picker = ImagePicker();

  Future<void> _pickImages() async {
    try {
      final List<XFile> selected = await picker.pickMultiImage();
      if (selected.isNotEmpty) {
        for (var file in selected) {
          
          if (!isValidImage(file.name)) {
            _showSnack('Chỉ hỗ trợ ảnh JPG, PNG, JPEG');
            continue;
          }

          final fileSize = await file.length(); // bytes
          
          if (fileSize > 5 * 1024 * 1024) {
            _showSnack('Ảnh quá lớn (> 5MB): ${file.name}');
            continue;
          }

          setState(() {
            _images.add(file);
          });
        }
        _showSnack('Tải hình ảnh hoàn tất');
      }
    } catch (e) {
      _showSnack('Lỗi trong quá trình tải ảnh');
    }
  }


  Future<String> extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin); // Latin hỗ trợ cả tiếng Việt
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    return recognizedText.text;
  }

  Future<void> exportTextToExcel(List<String> texts) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Text Result'];

    // Thêm tiêu đề
    sheet.appendRow(['Văn bản']);

    // Thêm dữ liệu
    for (String text in texts) {
      sheet.appendRow([text]);
    }

    // Lưu file
    final dir = await getApplicationDocumentsDirectory();
    final filePath = "${dir.path}/ket_qua_ocr.xlsx";
    final fileBytes = excel.encode();
    final file = File(filePath);

    await file.writeAsBytes(fileBytes!);

    print('✅ Đã xuất file: $filePath');
  }

  void _convertImagesToText() async {
    if (_images.isEmpty) {
      _showSnack('Chưa có hình ảnh nào để xử lý');
      return;
    }

    setState(() {
      _isProcessing = true;
      _texts.clear();
    });

    for (var img in _images) {
      try {
        final text = await extractTextFromImage(img.path);
        _texts.add(text.trim().isEmpty ? '[Không phát hiện văn bản]' : text.trim());
      } catch (e) {
        _texts.add('[Lỗi xử lý ảnh: ${img.name}]');
      }
    }

    setState(() => _isProcessing = false);
    _showSnack('Đã xử lý xong tất cả ảnh');
  }



  void _exportToExcel() async {
    if (_texts.isEmpty) {
      _showSnack('Không có dữ liệu để xuất');
      return;
    }
    try {
      await exportTextToExcel(_texts);
      _showSnack('Xuất Excel thành công!');
    } catch (e) {
      _showSnack('Xuất Excel thất bại!');
    }
  }


  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool isValidImage(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image to Text Converter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 1. Thanh công cụ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(onPressed: _pickImages, child: Text('Tải hình ảnh')),
                ElevatedButton(onPressed: _convertImagesToText, child: Text('Image to Text')),
                ElevatedButton(onPressed: _exportToExcel, child: Text('Xuất Excel')),
              ],
            ),
            SizedBox(height: 12),

            // 2. Lưới ảnh
            if (_images.isNotEmpty)
              SizedBox(
                height: 150,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final isError = _texts.length > index && _texts[index].startsWith('[Lỗi');
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(File(_images[index].path), width: 120, height: 120),
                        if (isError)
                          Icon(Icons.error, color: Colors.red, size: 24),
                      ],
                    );
                  },
                ),
              ),

            SizedBox(height: 12),

            // 3. Bảng văn bản
            Expanded(
              child: _texts.isEmpty
                  ? Center(child: Text('Chưa có kết quả'))
                  : ListView.separated(
                      itemCount: _texts.length,
                      separatorBuilder: (_, __) => Divider(),
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: Icon(Icons.image),
                          title: Text(_texts[index]),
                        );
                      },
                    ),
            ),

            // Loading indicator nếu cần
            if (_isProcessing)
              Column(
                children: [
                  SizedBox(height: 8),
                  CircularProgressIndicator(),
                  Text('Đang xử lý...'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
