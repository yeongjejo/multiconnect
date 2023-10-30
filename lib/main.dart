import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:convert/convert.dart';


void main() {
  runApp(MaterialApp(

    debugShowCheckedModeBanner: false,
    initialRoute: '/main',
    routes: {
      '/main' : (BuildContext context) => const MainScreen(),
    },
  ));
}

class MainScreen extends StatefulWidget {

  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();

  static List<int> _fromString(String input) {
    input = _removeNonHexCharacters(input);
    final bytes = hex.decode(input);

    if (bytes.length != 16) {
      throw const FormatException("The format is invalid");
    }

    return bytes;
  }

  static String _removeNonHexCharacters(String sourceString) {
    return String.fromCharCodes(sourceString.runes.where((r) =>
    (r >= 48 && r <= 57) // characters 0 to 9
        ||
        (r >= 65 && r <= 70) // characters A to F
        ||
        (r >= 97 && r <= 102) // characters a to f
    ));
  }


}

class _MainScreenState extends State<MainScreen> {
  final Uuid uuid = Uuid(MainScreen._fromString("00003559-0000-1000-8000-00805F9B34FB")); // uuid

  final flutterReactiveBle = FlutterReactiveBle();

  double rssi = -100.0;
  String? maxCloberID;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Text("테스트 중입니다."),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    startScanning();
  }

  void startScanning() {

    debugPrint('여기 입니다요');
    int scanStartTime = DateTime.now().millisecondsSinceEpoch;
    Map<Uint8List, List<int>> cloberMap = {};

    try {
      flutterReactiveBle.scanForDevices(withServices: [uuid], scanMode: ScanMode.lowLatency).listen((device) {
        Uint8List cType= Uint8List(1); // 출입 클로버 확인 (1이면 출입 클로버)
        Uint8List cID = Uint8List(4); // 클로버 아이디
        Uint8List cKey = Uint8List(2); // 클로버 키

        int nowTime = DateTime.now().millisecondsSinceEpoch; // 스캔 시간 저장


        // 출입 클로버 판별
        if(device.manufacturerData.length >= 21 && device.manufacturerData[4] == 1) {
          // 클로버 ID 저장
          cID[0] = device.manufacturerData[6];
          cID[1] = device.manufacturerData[7];
          cID[2] = device.manufacturerData[8];
          cID[3] = device.manufacturerData[9];

          if(nowTime - scanStartTime <= 1000) {

            // debugPrint("time : $scanStartTime");
            // 클로버 타입 저장 (device.manufacturerData[4])
            cType[0] = 1;

            // 클로버 키 저장
            cKey[0] = device.manufacturerData[10];
            cKey[1] = device.manufacturerData[11];


            // 클러버 rssi 저장
            if (cloberMap[cID] == null) {
              cloberMap[cID] = [device.rssi];
            } else {
              cloberMap[cID]?.add(device.rssi);
            }


            // debugPrint('cid : $cID');
            // debugPrint('cid : ${device.id}');
            // debugPrint('serviceID : ${device.serviceUuids}');
            // debugPrint('serviceData : ${device.serviceData}');
            // debugPrint('last cid : ${cID.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}');

          } else {
            double maxRssi = -100.0;
            Uint8List? maxClober;

            // 1초간 rssi 신호가 높은 클로버 id 구하기
            cloberMap.forEach((key, value) {
              double rssiAvg = average(value);

              if(rssiAvg >= maxRssi) {
                maxRssi = rssiAvg; // 최대 rssi 저장
                maxClober = cID;  // 클로버 아이디 저장
              }
            });

            // 모션 센서가 동작하고 rssi 평균이 범위 이상 인지 판별
            if (-75.0 <= maxRssi && maxClober != null) {
              rssi = maxRssi;
              maxCloberID = maxClober!.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
            } else {
              rssi = -100.0;
              maxCloberID = null;
            }

            scanStartTime = nowTime;
            cloberMap.clear();
            cloberMap[cID] = [device.rssi];
          }

          // maxCloberID와 현재 스캔된 clober ID가 동일한 경우
          if(maxCloberID != null && device.manufacturerData[10] != 0 && maxCloberID == cID.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join() && device.connectable.name == 'available') {

            debugPrint('여기 통과');
            startConnect(device); // 컨넥 시작
          }

        }


        // device.id






        //code for handling results

      }, onError: (Object error) {
        // Handle a possible error
      });
    } catch (e) {
      debugPrint("err : $e");
    }

  }

  void startConnect(DiscoveredDevice device) {
    // debugPrint('컨넥 상태?11111 : ${device.connectable}');
    flutterReactiveBle.connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {uuid: [uuid]},
      connectionTimeout: const Duration(seconds: 1),
    ).listen((connectionState) {
      debugPrint('컨넥 성공했다ㅏ다ㅏㅏ');

      // debugPrint('컨넥 상태?2222 : ${device.connectable}');
      debugPrint('컨넥 상태?3333 : ${connectionState.connectionState}');

      Map<Uuid, Uint8List> test = device.serviceData;
      debugPrint('test : ${device.manufacturerData}');
      test.forEach((key, value) {
        debugPrint('key: ${key}');
        debugPrint('value : ${value}');
      });


      startService(device);


      // Handle connection state updates
    }, onError: (Object error) {

      debugPrint('컨넥 실패');
      // Handle a possible error
    });
  }


  // 리스트 평균 (rssi 평균)
  double average(List<int> numbers) {
    if (numbers.isEmpty) {
      return 0.0; // 빈 리스트의 경우 0.0을 반환하거나 원하는 기본값을 사용할 수 있습니다.
    }

    int sum = numbers.reduce((value, element) => value + element);
    return sum / numbers.length.toDouble();
  }



  Future<void> startService(DiscoveredDevice device) async {
    await flutterReactiveBle.discoverAllServices(device.id);
    var services = await flutterReactiveBle.getDiscoveredServices(device.id);
    debugPrint("뭐가 찍히나 : $services");

    for(var service in services) {
      List<int> listenValue;

      // 목표 서비스가 아니면 continue
      List<String> temp = service.id.toString().split("-");
      if (temp[0] == "00003559") {
        debugPrint("목표 Service : $service");
      } else {
        continue;
      }

      List<Characteristic>  characteristics = service.characteristics;
      for(Characteristic c in characteristics) {
        List<String> temp2 = c.id.toString().split("-");

        if (temp2[0] == "00000002") {
          c.isWritableWithoutResponse;
        }
      }

      debugPrint('서비스요 : $service');
      debugPrint('서비스요 : ${service.id}');
      debugPrint('characteristics : $characteristics');
    }
  }
}


