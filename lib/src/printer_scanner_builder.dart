import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_printer_bloc/pos_printer_bloc.dart';
import 'package:validators/validators.dart';

class PrinterScannerBuilder extends StatefulWidget {
  final List printerTypes;

  PrinterScannerBuilder({this.printerTypes});

  @override
  State<StatefulWidget> createState() => PrinterScannerBuilderState();
}

class PrinterScannerBuilderState extends State<PrinterScannerBuilder> {
  PrinterBloc _printerBloc;
  PrinterScanBloc _printerScanBloc;

  @override
  void initState() {
    _printerBloc = BlocProvider.of<PrinterBloc>(context);
    _printerScanBloc = PrinterScanBloc(_printerBloc.printerManager);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // The star printer makes the phone freeze
      _printerScanBloc.add(PrinterScanStart(types: widget.printerTypes));
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        onRefresh: () async =>
            _printerScanBloc.add(PrinterScanStart(types: widget.printerTypes)),
        child: BlocBuilder<PrinterScanBloc, PrinterScanState>(
            cubit: _printerScanBloc,
            builder: (context, state) {
              return Column(children: [
                state.scanning ? LinearProgressIndicator() : SizedBox(),
                ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.printers?.length ?? 0,
                    itemBuilder: (context, i) {
                      final printer = state.printers[i];
                      return ListTile(
                          title: Text(printer.name),
                          onLongPress: () async {
                            _printerBloc.add(PrinterConnect(state.printers[i]));
                            //                    _printerBloc.add(PrintTicket(await _printerBloc.testTicket()));
                          },
                          onTap: () async {
                            _printerBloc.add(PrinterConnect(state.printers[i]));
                            Navigator.of(context).pop();
                          },
                          subtitle: Text(printer.address),
                          trailing: BlocBuilder<PrinterBloc, PrinterState>(
                              cubit: _printerBloc,
                              builder: (context, state) {
                                return printer.address == state.printer?.address
                                    ? IconButton(
                                    icon: Icon(Icons.check_box),
                                    onPressed: () =>
                                        _printerBloc.add(PrinterDeselect()))
                                    : SizedBox();
                              }));
                    }),
              ] + (widget.printerTypes.contains(NetworkPrinter) ? [ListTile(
                title: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                  ),
                  onFieldSubmitted: (text) {
                    _printerScanBloc.add(PrinterScanFound(NetworkPrinter(
                      address: text,
                      name: text
                    )));
                  },
                  validator: (text) => isIP(text, 4) ? null : 'Please enter a valid ip address',
                ),
              )] : []));
            })
    );
  }

  @override
  void dispose() {
    _printerScanBloc?.close();
    super.dispose();
  }
}
