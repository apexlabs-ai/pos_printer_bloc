import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_star_prnt/flutter_star_prnt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pos_ticket_line.dart';
import '../printer.dart';


class PrinterState extends Equatable  {
  final bool busy;
  final Printer printer;

  bool get connected => printer != null;

  PrinterState({this.printer, this.busy=false});

  PrinterState toBusy() => PrinterState(printer: printer, busy: true);
  PrinterState toFree() => PrinterState(printer: printer, busy: false);

  @override
  List<Object> get props => [printer, busy];

  @override
  String toString() => "$runtimeType: { $printer, ${busy ? 'busy' : 'free' }";
}

abstract class PrinterEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class PrinterDeselect extends PrinterEvent {}

class PrinterConnect extends PrinterEvent {
  final Printer printer;

  PrinterConnect([this.printer]);

  @override
  List<Object> get props => [printer];
}


class PrintTicket extends PrinterEvent {
  final List <PosTicketLine> lines;
  PrintTicket(this.lines);

  @override
  List<Object> get props => [lines];
}

class PrintTest extends PrinterEvent {}

class PrinterBloc extends Bloc <PrinterEvent, PrinterState> {
  static const kSearchTimeOut = Duration(seconds: 5);

  static const kPrinterSharedPrefsKey = "aahi.sell.printer";
  final String printerSharedPrefsKey;
  static const kStarEmulation = 'StarLine';

  static final PrinterBluetoothManager _printerManager = PrinterBluetoothManager();
  
  PrinterBluetoothManager get printerManager => _printerManager;

  CapabilityProfile _capabilityProfile;
  
  @override
  PrinterState get initialState => PrinterState();

  PrinterBloc({this.printerSharedPrefsKey = kPrinterSharedPrefsKey});

  Future <Printer> _getStarPrinter([String portName]) async {
    for(var port in await StarPrnt.portDiscovery(StarPortType.All)) {
      if(portName == null || port.portName == portName) return StarPrinter(port);
    }
    return null;
  }

  Future <Printer> _connectPrinter({Printer printer, bool disconnect=false}) async {
    printer ??= state.printer;

    final prefs = await SharedPreferences.getInstance();
    if(disconnect) {
      prefs.remove(printerSharedPrefsKey);
      return null;
    }

    if(printer == null) {
      if (prefs.containsKey(printerSharedPrefsKey)) {
        final printerAddressName = prefs.getStringList(printerSharedPrefsKey);
        if(printerAddressName[0][0] == '*') {
          printer = await _getStarPrinter(printerAddressName[0].substring(1));
          if(printer == null) {
            prefs.remove(printerSharedPrefsKey);
          }
        }
      } else {
        // Try any star printer by default - this makes the app freeze up for a moment so don't do it
//        printer = await _getStarPrinter();
      }
    }

    if(printer is BluetoothPrinter) {
      _printerManager.selectPrinter(printer);
      prefs.setStringList(printerSharedPrefsKey, [printer?.address, printer?.name]);
      _capabilityProfile = await CapabilityProfile.load();
      return  printer;
    } else if(printer is StarPrinter) {
      final status = await StarPrnt.checkStatus(portName: printer.address, emulation: kStarEmulation);
      print(status);

      if(status['offline'] ?? true) {
        final connected = await StarPrnt.connect(portName: printer.address, emulation: kStarEmulation);
        if (connected != 'Success') {
          onError(connected, null);
          return null;
        }
      }
      prefs.setStringList(printerSharedPrefsKey, ['*' + printer?.address, printer?.name]);
      return printer;
    }

    return null;
  }

  @override
  Stream<PrinterState> mapEventToState(PrinterEvent event) async* {
    if (event is PrinterConnect) {
      yield state.toBusy();
      yield PrinterState(printer: await _connectPrinter(printer: event.printer));
    } else if (event is PrintTicket) {
      var printer = state.printer;
      yield state.toBusy();
      if(printer == null) {
        printer = await _connectPrinter();
        if(printer != null) yield PrinterState(printer: printer);
      }
      yield state.toFree();

      if(state.printer is BluetoothPrinter) {
        yield state.toBusy();
        final result = await _printerManager.printTicket(_ticketFromLines(
            PaperSize.mm58, _capabilityProfile,
            lines: event.lines));
        if (result != PosPrintResult.success) {
          yield PrinterState();
          add(PrinterConnect());
          onError(result.msg, null);
          return;
        }
      } else if(state.printer is StarPrinter) {
        yield state.toBusy();
        final result = await StarPrnt.print(
            portName: state.printer.address,
            emulation: 'StarGraphic',
            printCommands: _commandsFromLines(lines: event.lines)
        );
        if(result != 'Success') {
          onError(result, null);
          yield PrinterState();
          add(PrinterConnect());
          return;
        }
      }
      yield state.toFree();
    } else if (event is PrinterDeselect) {
      await _connectPrinter(disconnect: true);
      yield PrinterState();
    }
  }

  Ticket _ticketFromLines(PaperSize paperSize, CapabilityProfile profile, {List <PosTicketLine> lines}) {
    final ticket = Ticket(paperSize, profile);
    for(var line in lines) {
      if(line is PosTicketText) {
        ticket.text(line.text, styles: line.styles, linesAfter: line.linesAfter);
      } else if(line is PosTicketRow) {
        ticket.row(line.cols);
      } else if(line is PosTicketBeep) {
        ticket.beep(n: line.n, duration: line.duration);
      } else if(line is PostTicketReset) {
        ticket.reset();
      } else if(line is PosTicketCut) {
        ticket.cut(mode: line.mode);
      } else if(line is PosTicketHr) {
        ticket.hr();
      } else if(line is PosTicketDrawer) {
        ticket.drawer(pin: line.pin);
      } else if(line is PosTicketFeed) {
        ticket.feed(line.lines);
      } else if(line is PosTicketImage) {
        ticket.image(line.image, align: line.align);
      } else if(line is PosTicketBarcode) {
        ticket.barcode(line.barcode,
            width: line.width,
            height: line.height,
            font: line.font,
            textPos: line.textPos,
            align: line.align
        );
      } else if(line is PosTicketQrcode) {
        ticket.qrcode(line.text, align: line.align,
            size: line.size,
            cor: line.correction);
      } else {
        print("_ticketFromLines: unsupported line type ${line.runtimeType}");
      }
    }
    return ticket;
  }

  static const Map<PosAlign, StarAlignmentPosition> _starAlignment = {
    PosAlign.center: StarAlignmentPosition.Center,
    PosAlign.left: StarAlignmentPosition.Left,
    PosAlign.right: StarAlignmentPosition.Right
  };
  
  static const Map<PosCutMode, StarCutPaperAction> _starCutAction = {
    PosCutMode.full: StarCutPaperAction.FullCut,
    PosCutMode.partial: StarCutPaperAction.PartialCut
  };

  PrintCommands _commandsFromLines({List <PosTicketLine> lines}) {
    PrintCommands commands = PrintCommands();

    //    commands.appendEncoding(StarEncoding.UTF8);
    for(var line in lines) {
      if(line is PosTicketText) {
        commands.appendBitmapText(
            text: line.text,
            alignment:  _starAlignment[line.styles.align],
//            fontSize: line.styles.height.value,
//            width: line.styles.width.value
        );
      } else if(line is PosTicketCut) {
        commands.appendCutPaper(_starCutAction[line.mode]);
      } else if(line is PosTicketHr) {
        commands.appendBitmapText(text: '--------------------------------------');
      } else if(line is PosTicketFeed) {
        for (int i = 1; i < line.lines; i++) {
          commands.appendBitmapText(text: "\n\n");
        }
      } else {
        print("_commandsFromLines: unsupported line type ${line.runtimeType}");
      }
    }

    print(commands.getCommands());
    return commands;
  }
}
