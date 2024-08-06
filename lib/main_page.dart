import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_code_generator/styles.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  //Controls the text being edited in the text field.
  final TextEditingController _textController = TextEditingController(text: '');
  String data = ''; //Stores the data to be encoded into the QR code.
  //A key used for identifying the RepaintBoundary widget for capturing and exporting the QR code as an image.
  final GlobalKey _qrKey = GlobalKey();
  //bool dirExists = false;
  //dynamic externalDir = '/Storage/Emulated/0/Download';

  Future<void> _captureAndSavePng() async {
    // Request storage permissions
    if (await Permission.storage.request().isGranted) {
      try {
        RenderRepaintBoundary boundary =
            _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        var image = await boundary.toImage(pixelRatio: 3.0);

        //drawing white background because qr is black
        final whitePaint = Paint()..color = Colors.white;
        final recorder = PictureRecorder();
        final canvas = Canvas(
            recorder,
            Rect.fromLTWH(
                0, 0, image.width.toDouble(), image.height.toDouble()));
        canvas.drawRect(
            Rect.fromLTWH(
                0, 0, image.width.toDouble(), image.height.toDouble()),
            whitePaint);
        canvas.drawImage(image, Offset.zero, Paint());
        final picture = recorder.endRecording();
        final img = await picture.toImage(image.width, image.height);
        ByteData? byteData = await img.toByteData(format: ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        // Get the external storage directory
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          throw Exception("Could not find the external storage directory");
        }

        String externalDir = directory.path;

        //check for duplicate file name to avoid override
        String fileName = 'qr_code';
        int i = 1;
        while (await File('$externalDir/$fileName.png').exists()) {
          fileName = 'qr_code_$i';
          i++;
        }

        final file = await File('$externalDir/$fileName.png').create();
        await file.writeAsBytes(pngBytes);
        // Trigger the media scanner
        final result = await Process.run('am', [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$externalDir/$fileName.png'
        ]);

        if (!mounted) return;
        const snackBar = SnackBar(content: Text('Qr code saved to gallery'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } catch (e) {
        if (!mounted) return;
        const snackBar = SnackBar(content: Text('Something went wrong'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } else {
      // Permission not granted
      const snackBar = SnackBar(
          content: Text('Storage permission is required to save the QR code'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qr code generator'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
          child: Column(
        children: [
          const SizedBox(
            height: 15,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(10),
                  labelText: 'Enter Text',
                  labelStyle: TextStyle(color: Colors.grey),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Color.fromARGB(255, 0, 146, 20), width: 2.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 2.0),
                  )),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          RawMaterialButton(
              onPressed: () {
                setState(() {
                  data = _textController.text;
                });
              },
              fillColor: AppColors.primaryColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              child: const Text(
                'Generate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              )),
          const SizedBox(
            height: 15,
          ),
          Center(
            child: RepaintBoundary(
              key: _qrKey,
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 250.0,
                gapless: true,
                errorStateBuilder: (ctx, err) {
                  return const Center(
                    child: Text(
                      'Someting went wrong!!!',
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          RawMaterialButton(
            onPressed: _captureAndSavePng,
            fillColor: AppColors.primaryColor,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            child: const Text(
              'Export',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      )),
    );
  }
}
