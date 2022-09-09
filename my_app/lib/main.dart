import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image/image.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Center(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
      ),
      home: const Home(),
      routes: <String, WidgetBuilder>{
        '/home': (BuildContext context) => const Home(),
        '/camera': (BuildContext context) => const CameraView(),
      },
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MaterialApp"), actions: const []),
      body: Center(
          child: Column(children: [
        const Padding(padding: EdgeInsets.only(top: 50)),
        Text(
          'Camera App',
          style: Theme.of(context).textTheme.headline2,
        ),
        const Padding(padding: EdgeInsets.only(top: 50)),
        Text(
          'welcome to camera app.',
          style: Theme.of(context).textTheme.bodyText1,
        ),
      ])),
      bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).primaryColor,
          shape: const CircularNotchedRectangle(),
          child: Container(height: 50.0)),
      floatingActionButton: FloatingActionButton(
          onPressed: () => {Navigator.of(context).pushNamed('/camera')},
          tooltip: 'Open Camera',
          child: const Icon(Icons.camera_alt)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraView();
}

class _CameraView extends State<CameraView> {
  CameraController? _controller;
  late List<CameraDescription> _cameras;
  final GlobalKey _globalKey = GlobalKey();

  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();

    availableCameras().then((value) {
      _cameras = value;
      _initCameraController(_cameras[_cameraIndex]);
    });
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    try {
      _controller = CameraController(camera, ResolutionPreset.max);

      if (_controller == null) {
        print('failed to initialize camera controller.');
        return;
      }

      _controller!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      await _controller!.initialize();
    } catch (e) {
      print(e);
    }
  }

  void nextCamera() {
    if (_cameraIndex + 1 >= _cameras.length) {
      _cameraIndex = 0;
    } else {
      _cameraIndex += 1;
    }

    // インカメ使わない
    if (_cameraIndex == 1) {
      return nextCamera();
    }

    _initCameraController(_cameras[_cameraIndex]).then((value) => {});
  }

  void prevCamera() {
    if (_cameraIndex > 0) {
      _cameraIndex -= 1;
    } else {
      _cameraIndex = _cameras.length - 1;
    }

    // インカメ使わない
    if (_cameraIndex == 1) {
      return prevCamera();
    }

    _initCameraController(_cameras[_cameraIndex]).then((value) => {});
  }

  void takePicture() async {
    if (_controller == null) {
      return;
    }

    final _picture = await _controller!.takePicture();
    final Uint8List _picture_buffer = await _picture.readAsBytes();
    await ImageGallerySaver.saveImage(_picture_buffer);

    RenderRepaintBoundary rrb =
        _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    final overlay = await rrb.toImage();
    final overlayByteData =
        await overlay.toByteData(format: ImageByteFormat.png);
    final Uint8List? overlayBuffer = overlayByteData?.buffer.asUint8List();
    await ImageGallerySaver.saveImage(overlayBuffer!);

    final _pictureImage = decodeImage(_picture_buffer);
    final _overlayImage = copyResize(
      decodeImage(overlayBuffer)!,
      width: _pictureImage!.width,
    );

    final _compositeImage = drawImage(_pictureImage!, _overlayImage!);

    await ImageGallerySaver.saveImage(
        Uint8List.fromList(encodePng(_compositeImage)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black12.withAlpha(50),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            nextCamera();
          } else {
            prevCamera();
          }
        },
        child: Container(
          color: Colors.blueGrey[100],
          child: Center(
            child: _cameraWidgetWithLoading(context),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => {takePicture()}, // カメラ切り替えボタンは別で用意したいが一旦はシャッターボタンで代用
          tooltip: 'shutter',
          child: const Icon(Icons.camera)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _cameraWidgetWithLoading(BuildContext context) {
    if (_controller == null) {
      return Row(children: const [
        CircularProgressIndicator(),
        Text('カメラ準備中'),
      ]);
    } else {
      return CameraPreview(
        _controller!,
        child: RepaintBoundary(
          key: _globalKey,
          child: Center(
            child: Text(
              'OVERLAY TEXT',
              style: Theme.of(context).textTheme.headline1,
            ),
          ),
        ),
      );
    }
  }
}
