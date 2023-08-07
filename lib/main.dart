import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CameraApp(),
    );
  }
}


// 메인 화면(카메라로 촬영)
class CameraApp extends StatefulWidget {

  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  bool isPictureCapturing = false;
  double x = 0;
  double y = 0;

  @override
  void initState() {
    super.initState();
    controller = CameraController(_cameras[0], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.setFlashMode(FlashMode.off);
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            break;
          default:
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
        body: Center(
          child: Column(
            children: [
              const SizedBox(height: 29),
              Expanded(flex: 7,
                  child: CameraPreview(
                    controller,
                    child: GestureDetector(onTapDown: (TapDownDetails details) {
                      x = details.localPosition.dx;
                      y = details.localPosition.dy;

                      double fullWidth = MediaQuery.of(context).size.width;
                      double cameraHeight = fullWidth * controller.value.aspectRatio;

                      double xp = x / fullWidth;
                      double yp = y / cameraHeight;

                      Offset point = Offset(xp,yp);
                      controller.setFocusPoint(point);
                    },),
                  )
              ),
              Expanded(
                  flex: 1,
                  child: IconButton(
                      onPressed: !isPictureCapturing ? () async {
                        isPictureCapturing = true;
                        // 경로 생성
                        final path = join(
                            ( await getTemporaryDirectory() ).path,
                            '${DateTime.now()}.png'
                        );
                        // 사진 촬영
                        // 포커스 모드 고정 안하면 STATE_WAITING_FOCUS 뜨면서 엄청 오래걸림
                        controller.setFocusMode(FocusMode.locked);
                        XFile picture = await controller.takePicture();
                        controller.setFocusMode(FocusMode.auto);
                        // 사진 저장
                        picture.saveTo(path);
                        if (!mounted) return;
                        isPictureCapturing = false;
                        // 검사 화면으로 전환
                        Navigator.push(context,
                            MaterialPageRoute(
                                builder: ( context ) => ChkAndSend( imagePath: path )
                            )
                        );
                      } : null,
                      icon: Image.asset("assets/images/photo_capture.png")
                  )
              )
            ],
          ),
        )
    );
  }
}

// 촬영 후 확인 및 전송
class ChkAndSend extends StatefulWidget {
  final String imagePath;

  const ChkAndSend({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<ChkAndSend> createState() => _ChkAndSendState();
}

class _ChkAndSendState extends State<ChkAndSend> {
  var jsonResult = {};
  var time = "";
  var state = "";
  var carNumber = "";

  Future<Object> uploadImage() async {
    // 주소
    final uri = Uri.parse('http://121.137.148.133:5000/test');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', widget.imagePath));
    print("Image sent");
    var response = await request.send();
    if (response.statusCode == 200) {
      print("Image scanned successfully!");
      jsonResult = jsonDecode(await response.stream.bytesToString());
      print(jsonResult);
      time = jsonResult["time"];
      state = jsonResult["state"];
      carNumber = jsonResult["carnumber"];
      return response;
    } else {
      throw ('Image upload failed with status: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 29),
          SizedBox(
              height: MediaQuery.of(context).size.height*0.8,
              child: Image.file( File(widget.imagePath) , fit: BoxFit.fitHeight)
          ),
          Text(time,style: TextStyle(fontSize: 20)),
          Text(state,style: TextStyle(fontSize: 20)),
          Text(carNumber,style: TextStyle(fontSize: 20)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: () { Navigator.pop(context); },
                      child: const Text("다시 찍기",style: TextStyle(color: Colors.black)),
                    )
                ),
                const VerticalDivider(color: Color(0x676767FF),width: 2),
                Expanded(
                    child: TextButton(
                      onPressed: () async {
                        // 응답 받아 오는 동안 로딩 창 생성
                        showDialog(
                          context: context,
                          barrierDismissible: false, // 다이얼로그를 탭해도 닫히지 않도록 설정
                          builder: (context) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        );
                        uploadImage().then((response) {
                          Navigator.pop(context); // 로딩 다이얼로그 닫기
                          setState(() {});
                        }).catchError((error) {
                          Navigator.pop(context);
                          // 에러 처리 로직
                          print(error);
                        });
                      },
                      child: const Text("스캔 시작",style: TextStyle(color: Colors.black)),
                    )
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

