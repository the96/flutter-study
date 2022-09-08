import 'package:flutter/material.dart';

void main() {
  runApp(const Center(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyApp();
}

class _MyApp extends State<MyApp> {
  int _count = 0;
  void _increment() {
    setState(() {
      _count += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 100,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: OutlinedButton(
          onPressed: () {
            print('pressed');
            _increment();
          },
          child: Text(
            '$_count',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}
