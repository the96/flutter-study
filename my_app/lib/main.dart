import 'package:flutter/material.dart';

void main() {
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
        '/home': (BuildContext context) => new Home(),
        '/camera': (BuildContext context) => new CameraView(),
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

class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black12.withAlpha(50),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        color: Colors.blueGrey[100],
        child: const Center(
          child: Text('camera coming soon'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => {},
          tooltip: 'shutter',
          child: const Icon(Icons.camera)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
