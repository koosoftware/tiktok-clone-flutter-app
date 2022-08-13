import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tiktokclone/video.dart';
import 'package:video_compress/video_compress.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tik Tok Clone App',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Tik Tok Clone App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> _mVideoUrlList = [];
  late Controller _mSwipeController;

  @override
  initState() {
    initStateAsync();

    _mSwipeController = Controller()
      ..addListener((event) {
        _handleCallbackEvent(event.direction, event.success, event.pageNo);
      });

    // controller.jumpToPosition(4);
    super.initState();
  }

  void initStateAsync() async {
    final videoBucket = FirebaseStorage.instanceFor(
      bucket: "gs://tiktokclone1234.appspot.com",
    );

    final videoBucketRef = videoBucket.ref();
    ListResult listResult = await videoBucketRef.listAll();
    List<String> videoUrlList = [];
    for (var item in listResult.items) {
      String videoUrl = await item.getDownloadURL();
      videoUrlList.add(videoUrl);
    }
    setState(() {
      _mVideoUrlList = videoUrlList;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleCallbackEvent(ScrollDirection direction, ScrollSuccess success,
      int? currentPageIndex) {}

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: _mVideoUrlList.isNotEmpty
          ? TikTokStyleFullPageScroller(
              contentSize: _mVideoUrlList.length,
              swipePositionThreshold: 0.2,
              // ^ the fraction of the screen needed to scroll
              swipeVelocityThreshold: 2000,
              // ^ the velocity threshold for smaller scrolls
              animationDuration: const Duration(milliseconds: 400),
              // ^ how long the animation will take
              controller: _mSwipeController,
              // ^ registering our own function to listen to page changes
              builder: (BuildContext context, int index) {
                return Video(
                  key: Key(index.toString()),
                  videoUrl: _mVideoUrlList[index],
                );
              },
            )
          : Container(
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ImagePicker _picker = ImagePicker();
          final XFile? video = await _picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(
              seconds: 60,
            ),
          );

          if (video != null) {
            final videoBucket = FirebaseStorage.instanceFor(
                bucket: "gs://tiktokclone1234.appspot.com");

            int timestamp = DateTime.now().millisecondsSinceEpoch;

            String videoFilename = timestamp.toString() + ".mp4";

            final videoBucketRef = videoBucket.ref();
            final videoFileRef = videoBucketRef.child("/" + videoFilename);

            Uint8List finalVideoData;
            UploadTask? uploadTask;
            MediaInfo mediaInfo = await VideoCompress.getMediaInfo(video.path);
            if (mediaInfo.duration != null) {
              int durationSec = (mediaInfo.duration! / 1000).ceil();

              MediaInfo? finalMediaInfo = await VideoCompress.compressVideo(
                video.path,
                startTime: 0,
                // duration is actually endtime
                duration: durationSec > 60 ? durationSec - 60 : 0,
                quality: VideoQuality.LowQuality,
              );
              if (finalMediaInfo != null && finalMediaInfo.file != null) {
                finalVideoData = await finalMediaInfo.file!.readAsBytes();

                uploadTask = videoFileRef.putData(
                  finalVideoData,
                  SettableMetadata(
                    contentType: "video/mp4",
                  ),
                );

                uploadTask.snapshotEvents.listen((taskSnapshot) async {
                  switch (taskSnapshot.state) {
                    case TaskState.running:
                      final _value = (taskSnapshot.bytesTransferred /
                          taskSnapshot.totalBytes);
                      final percentage = (_value * 100).ceil().toString();
                      break;
                    case TaskState.paused:
                      return;
                    case TaskState.success:
                      break;
                    case TaskState.canceled:
                      return;
                    case TaskState.error:
                      return;
                  }
                });
              }
            }
          }
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
