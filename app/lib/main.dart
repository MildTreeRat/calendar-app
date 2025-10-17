import 'package:flutter/material.dart';


void main() => runApp(const MyApp());


class MyApp extends StatelessWidget {
const MyApp({super.key});
@override
Widget build(BuildContext context) {
return MaterialApp(
title: 'Calendar MVP',
theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
home: const HomePage(),
);
}
}


class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
int taps = 0;
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text('Calendar Shell')),
body: Center(child: Text('Hello! taps=$taps')),
floatingActionButton: FloatingActionButton(
onPressed: () => setState(() => taps++),
child: const Icon(Icons.add),
),
);
}
}