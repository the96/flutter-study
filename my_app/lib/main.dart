import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image/image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';

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
      _zoomLevel = 1.0;
      _currentMaxZoomLevel = 12.01; // getMaxZoomLevelで得られる最大値を使うと写真が撮れなくなる
      _currentMinZoomLevel = await _controller!.getMinZoomLevel();
      await _controller!.setZoomLevel(_zoomLevel);
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
    double focus_x = dx / size.width;
    double focus_y = dy / size.height;
    if (focus_x < 0 || focus_x > 1 || focus_y < 0 || focus_y > 1) {
      print('out of range: focus');
      return;
    }
    await _controller!.setFocusMode(FocusMode.locked);
    await _controller!.setFocusPoint(Offset(focus_x, focus_y));
  }

  void resetFocus() async {
    await _controller!.setFocusMode(FocusMode.auto);
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
    // final location = await fetchGeoLocation();

    // compositeImage.exif.data[TiffImage.TAG_EXIF_IFD] = 4;
    // compositeImage.exif.data[TiffImage.TAG_EXIF_IFD + 0x0001] = 'N';
    // compositeImage.exif.data[TiffImage.TAG_EXIF_IFD + 0x0002] =
    //     location.latitude;
    // compositeImage.exif.data[TiffImage.TAG_EXIF_IFD + 0x0003] = 'E';
    // compositeImage.exif.data[TiffImage.TAG_EXIF_IFD + 0x0004] =
    //     location.longitude;

    final path = await ImageGallerySaver.saveImage(
      Uint8List.fromList(encodeJpg(compositeImage)),
      isReturnImagePathOfIOS: true,
    );

    // await File(path).writeAsBytes(encodePng(compositeImage));

    // print(path['filePath']);

    // final ImagePicker _picker = ImagePicker();
    // final XFile? pick_image =
    //     await _picker.pickImage(source: ImageSource.gallery);

    // print(pick_image!.path);

    // final exif = await Exif.fromPath(pick_image!.path);
    // print(exif);
    // final orig_attributes = await exif.getAttributes();
    // print(orig_attributes?.length);
    // orig_attributes?.forEach((key, value) {
    //   print('${key}: ${value}');
    // });

    // try {
    //   await exif.writeAttribute('DateTimeOriginal', '2020:01:01 00:00:00');
    //   await exif.writeAttributes({
    //     'GPSLatitude': location.latitude,
    //     'GPSLatitudeRef': 'N',
    //     'GPSLongitude': location.longitude,
    //     'GPSLongitudeRef': 'E',
    //   });
    // } catch (e, s) {
    //   print(e);
    //   print(s);
    // }
    // final attributes = await exif.getAttributes();
    // print('after');
    // print(attributes?.length);
    // attributes?.forEach((key, value) {
    //   print('${key}: ${value}');
    // });

    // await exif.close();
  }

  // Future<Position> fetchGeoLocation() async {
  //   bool serviceEnabled;
  //   LocationPermission permission;

  //   serviceEnabled = await Geolocator.isLocationServiceEnabled();
  //   if (!serviceEnabled) {
  //     return Future.error('Location services are disabled.');
  //   }

  //   permission = await Geolocator.checkPermission();
  //   if (permission == LocationPermission.denied) {
  //     permission = await Geolocator.requestPermission();
  //     if (permission == LocationPermission.denied) {
  //       return Future.error('Location permissions are denied');
  //     }
  //   }

  //   if (permission == LocationPermission.deniedForever) {
  //     return Future.error(
  //         'Location permissions are permanently denied, we cannot request permissions.');
  //   }

  //   return await Geolocator.getCurrentPosition();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black12.withAlpha(50),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
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
          margin: EdgeInsets.only(bottom: 48),
          color: Colors.blueGrey[100],
          child: _cameraWidgetWithLoading(context),
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
          key: _overlayKey,
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
