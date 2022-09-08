import 'package:flutter/material.dart';

void main() {
  runApp(const Center(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(title: const Text("MaterialApp"), actions: const []),
          body: Column(children: [
            const Padding(padding: EdgeInsets.only(top: 50)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Padding(padding: EdgeInsets.only(right: 50)),
              OutlinedButton(
                onPressed: () {},
                child: const Text('hello'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('world'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('column'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('and row'),
              ),
              const Padding(padding: EdgeInsets.only(left: 50)),
            ])
          ])),
    );
  }
}
