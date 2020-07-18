library pos_printer_bloc;

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';

abstract class Printer {
  String get name;
  String get address;
  int get type;

  @override
  String toString() => "$runtimeType: $name [$address]";
}

class BluetoothPrinter extends PrinterBluetooth implements Printer {
  BluetoothPrinter(BluetoothDevice device) : super(device);
}

class StarPrinter implements Printer {
  @override
  String get address => portInfo.portName;

  @override
  String get name => portInfo.modelName;

  @override
  int get type => null;

  final portInfo;

  StarPrinter(this.portInfo);
}

class NetworkPrinter implements Printer {
  final String name;
  final String address;
  final int type;

  NetworkPrinter({this.name, this.type = 9100, this.address});

  @override
  String toString() => "$runtimeType: $name [$address:$type]";
}
