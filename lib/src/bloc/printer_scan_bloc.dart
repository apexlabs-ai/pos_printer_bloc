import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:flutter_star_prnt/enums.dart';
import 'package:flutter_star_prnt/flutter_star_prnt.dart';

import '../printer.dart';

class PrinterScanState extends Equatable  {
  final bool scanning;
  final List<Printer> printers;

  PrinterScanState({this.printers = const [], this.scanning=false});

  @override
  List<Object> get props => [printers, scanning];

  @override
  String toString() => "$runtimeType: { found ${printers?.length ?? 0} printers, and ${scanning ? 'scanning' : 'not scanning' }";
}

abstract class PrinterScanEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class PrinterScanStart extends PrinterScanEvent {
  final List types;
  PrinterScanStart({this.types = const [BluetoothPrinter, StarPrinter]});
}

class PrinterScanStop extends PrinterScanEvent {}

class PrinterScanFound extends PrinterScanEvent {
  final Printer printer;
  PrinterScanFound([this.printer]);

  @override
  List<Object> get props => [printer];
}

class PrinterScanBloc extends Bloc <PrinterScanEvent, PrinterScanState> {
  static const kSearchTimeOut = Duration(seconds: 5);
  StreamSubscription _scanSubscription;
  StreamSubscription _scanStatusSubscription;

  final PrinterBluetoothManager _printerManager;

  PrinterScanBloc(this._printerManager) {
    _scanSubscription = _printerManager.scanResults.listen((List <PrinterBluetooth>devices) {
      for (PrinterBluetooth device in devices) {
        add(PrinterScanFound(BluetoothPrinter(BluetoothDevice()
          ..address = device.address
          ..type = device.type
          ..name = device.name)));
      }
    });
    _scanStatusSubscription = _printerManager.isScanningStream.listen((isScanning) {
      if(!isScanning) {
        add(PrinterScanFound());
      }
    });
  }

  @override
  PrinterScanState get initialState => PrinterScanState();

  @override
  Stream<PrinterScanState> mapEventToState(PrinterScanEvent event) async* {
    if (event is PrinterScanStart) {
      if(state.scanning) return;
      yield PrinterScanState(scanning: true);
      if(event.types.contains(BluetoothPrinter)) {
        _printerManager.startScan(kSearchTimeOut);
      }
      if(event.types.contains(StarPrinter)) {
        StarPrnt.portDiscovery(StarPortType.Bluetooth).then(
                (ports) =>
                ports.forEach((port) =>
                    add(PrinterScanFound(StarPrinter(port))))
        );
        if(!event.types.contains(BluetoothPrinter)) {
          add(PrinterScanFound());
        }
      }
    } else if(event is PrinterScanStop) {
      if(state.scanning) _printerManager.stopScan();
      yield PrinterScanState(printers: state.printers);
    } else if (event is PrinterScanFound) {
      if(event.printer == null) {
        yield PrinterScanState(printers: state.printers);
      } else {
        final alreadyFound = state.printers.firstWhere((printer) =>
        printer.address == event.printer.address, orElse: () => null);
        if (alreadyFound == null) {
          yield PrinterScanState(
              printers: state.printers + [event.printer],
              scanning: state.scanning);
        }
      }
    }
  }

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
    _scanStatusSubscription?.cancel();
    return super.close();
  }
}
