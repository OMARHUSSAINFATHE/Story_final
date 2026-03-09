import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'layout/statuse_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      builder: (_,child)=>MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Statuse Screen',
        home:StatusPage(),
      ) ,

    );
  }
}
 
