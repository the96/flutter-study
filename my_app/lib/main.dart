import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  final GlobalKey _overlayKey = GlobalKey();
  final GlobalKey _previewKey = GlobalKey();

  int _cameraIndex = 0;
  double _zoomLevel = 1;
  double _currentZoomLevel = 1;
  late double _currentMaxZoomLevel;
  late double _currentMinZoomLevel;
  DateTime scaleEndAt = DateTime.now();

  Point _focusPoint = Point();
  FocusMode _focusMode = FocusMode.auto;

  double _exposureOffsetStepSize = 1;
  double _maxExposureOffset = 0;
  double _currentExposureOffset = 0;

  ExposureMode _exposureMode = ExposureMode.auto;

  String getFocusMode() {
    switch (_focusMode) {
      case FocusMode.auto:
        return 'auto';
      case FocusMode.locked:
        return 'user';
    }
  }

  String getExposureMode() {
    switch (_exposureMode) {
      case ExposureMode.auto:
        return 'auto';
      case ExposureMode.locked:
        return 'user';
    }
  }

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
      _currentMinZoomLevel = await _controller!.getMinZoomLevel();
      _exposureOffsetStepSize = await _controller!.getExposureOffsetStepSize();
      _maxExposureOffset = await _controller!.getMaxExposureOffset();

      setState(() {
        _zoomLevel = 1.0;
        _currentMaxZoomLevel = 12.01; // getMaxZoomLevelで得られる最大値を使うと写真が撮れなくなる
        _currentExposureOffset = 0;
      });

      print('stepsize:$_exposureOffsetStepSize');
      print('maxoffset:$_maxExposureOffset');
      await _controller!.setZoomLevel(_zoomLevel);
      await _controller!.setFocusMode(_focusMode);
      await _controller!.setExposureMode(_exposureMode);
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

    // インカメ使わない、見たくないので
    if (_cameraIndex == 1) {
      return prevCamera();
    }

    _initCameraController(_cameras[_cameraIndex]).then((value) => {});
  }

  void zoomCamera(double scale) async {
    if (scaleEndAt.millisecondsSinceEpoch + 500 >
        DateTime.now().millisecondsSinceEpoch) {
      return;
    }

    final zoomSensitivity = (_currentMaxZoomLevel - _currentMinZoomLevel) / 8;
    final normalizedScale = (scale - 1) * zoomSensitivity + 1;
    _currentZoomLevel = _zoomLevel * normalizedScale;
    if (_currentZoomLevel > _currentMaxZoomLevel) {
      _currentZoomLevel = _currentMaxZoomLevel;
    } else if (_currentZoomLevel < _currentMinZoomLevel) {
      _currentZoomLevel = _currentMinZoomLevel;
    }

    _controller!.setZoomLevel(_currentZoomLevel);
  }

  void zoomEnd() async {
    scaleEndAt = DateTime.now();
    _zoomLevel = _currentZoomLevel;
  }

  void setFocus(double dx, double dy) async {
    RenderBox? renderBox =
        _previewKey.currentContext!.findRenderObject() as RenderBox?;

    Size size = renderBox!.size;
    double focusX = dx / size.width;
    double focusY = dy / size.height;
    if (focusX < 0 || focusX > 1 || focusY < 0 || focusY > 1) {
      print('out of range: focus');
      return;
    }
    _focusMode = FocusMode.locked;
    _focusPoint = Point(focusX, focusY);

    await _controller!.setFocusMode(_focusMode);
    await _controller!.setFocusPoint(Offset(focusX, focusY));
  }

  void resetFocus() async {
    _focusMode = FocusMode.auto;
    await _controller!.setFocusMode(_focusMode);
  }

  void toggleExposureMode() async {
    if (_exposureMode == ExposureMode.auto) {
      _exposureMode = ExposureMode.locked;
      await _controller!.setExposureMode(_exposureMode);
    } else if (_exposureMode == ExposureMode.locked) {
      _exposureMode = ExposureMode.auto;
      await _controller!.setExposureMode(_exposureMode);
    }

    _exposureOffsetStepSize = await _controller!.getExposureOffsetStepSize();
    _maxExposureOffset = await _controller!.getMaxExposureOffset();

    print('stepsize:$_exposureOffsetStepSize');
    print('maxoffset:$_maxExposureOffset');
    setState(() {});
  }

  void setExposure(double exposure) async {
    _controller!.setExposureOffset(exposure);
  }

  void takePicture() async {
    if (_controller == null) {
      return;
    }

    final picture = await _controller!.takePicture();
    final Uint8List pictureBuffer = await picture.readAsBytes();

    RenderRepaintBoundary rrb =
        _overlayKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    final overlay = await rrb.toImage();
    final overlayByteData =
        await overlay.toByteData(format: ImageByteFormat.png);
    final Uint8List? overlayBuffer = overlayByteData?.buffer.asUint8List();

    final pictureImage = decodeImage(pictureBuffer);
    final overlayImage = copyResize(
      decodeImage(overlayBuffer!)!,
      width: pictureImage!.width,
    );

    final compositeImage = drawImage(pictureImage, overlayImage);

    await ImageGallerySaver.saveImage(
        Uint8List.fromList(encodeJpg(compositeImage)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black12.withAlpha(50),
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Text(
              'FocusMode: ${getFocusMode()}\nExposureMode: ${getExposureMode()}\nExposure: $_currentExposureOffset'),
          TextButton(
            onPressed: () {
              toggleExposureMode();
            },
            child: const Text('Alt'),
          ),
        ]),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GestureDetector(
            key: _previewKey,
            onScaleUpdate: (ScaleUpdateDetails data) {
              zoomCamera(data.scale);
            },
            onScaleEnd: (ScaleEndDetails end) {
              zoomEnd();
            },
            onTapDown: (TapDownDetails details) {
              print(
                  'x: ${details.localPosition.dx}, y: ${details.localPosition.dy}');
              setFocus(details.localPosition.dx, details.localPosition.dy);
            },
            onDoubleTap: () {
              print('reset');
              resetFocus();
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                nextCamera();
              } else if (details.primaryVelocity! < 0) {
                prevCamera();
              }
            },
            child: Container(
              alignment: Alignment.bottomCenter,
              margin: const EdgeInsets.only(bottom: 48),
              color: Colors.blueGrey[100],
              child: _cameraWidgetWithLoading(context),
            ),
          ),
          _cameraController(context),
        ],
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
          key: _overlayKey,
          child: Stack(
            children: [
              Center(
                child: Text(
                  'OVERLAY TEXT',
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              if (_focusMode == FocusMode.locked)
                Positioned(
                  top: _focusPoint.y as double,
                  left: _focusPoint.x as double,
                  child: Container(
                    width: 5,
                    height: 5,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _cameraController(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          if (_maxExposureOffset > 0 && _exposureMode != ExposureMode.auto)
            Positioned(
              bottom: 40,
              left: 12,
              width: 172,
              child: Slider(
                min: 0,
                max: _maxExposureOffset,
                value: _currentExposureOffset,
                activeColor: Colors.lightBlue,
                inactiveColor: Colors.blueGrey,
                divisions: _exposureOffsetStepSize > 0
                    ? _maxExposureOffset ~/ _exposureOffsetStepSize
                    : 1000,
                onChanged: (double value) {
                  setState(() {
                    _currentExposureOffset = value;
                  });
                },
                onChangeEnd: ((value) {
                  setExposure(value);
                }),
              ),
            ),
        ],
      ),
    );
  }
}
