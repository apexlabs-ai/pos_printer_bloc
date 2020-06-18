import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart';

abstract class PosTicketLine {}

class PosTicketText extends PosTicketLine {
  final PosStyles styles;
  final String text;
  final int linesAfter;
  PosTicketText(this.text, {this.styles = const PosStyles.defaults(), this.linesAfter = 1});
}

class PosTicketRow extends PosTicketLine {
  final List<PosColumn> cols;
  PosTicketRow(this.cols);
}

class PosTicketBeep extends PosTicketLine {
  final int n;
  final PosBeepDuration duration;
  PosTicketBeep({this.n = 1, this.duration = PosBeepDuration.beep450ms});
}
class PostTicketReset extends PosTicketLine {}

class PosTicketCut extends PosTicketLine {
  final PosCutMode mode;
  PosTicketCut({this.mode = PosCutMode.full});
}

class PosTicketHr extends PosTicketLine {}

class PosTicketFeed extends PosTicketLine {
  final int lines;
  PosTicketFeed({this.lines  = 1});
}

class PosTicketDrawer extends PosTicketLine {
  final PosDrawer pin;
  PosTicketDrawer({this.pin = PosDrawer.pin2});
}

class PosTicketImage extends PosTicketLine {
   final Image image;
   final PosAlign align;
   final bool highDensityHorizontal;
   final bool highDensityVertical;
   final PosImageFn imageFn;

   PosTicketImage(this.image, {
     this.align = PosAlign.center,
     this.highDensityHorizontal = true,
     this.highDensityVertical = true,
     this.imageFn = PosImageFn.bitImageRaster
   });
}

class PosTicketBarcode extends PosTicketLine {
  final Barcode barcode;
  final int width;
  final int height;
  final BarcodeFont font;
  final BarcodeText textPos;
  final PosAlign align;

  PosTicketBarcode(this.barcode, {
    this.width,
    this.height,
    this.font,
    this.textPos = BarcodeText.below,
    this.align = PosAlign.center,
  });
}


class PosTicketQrcode extends PosTicketLine {
  final String text;
  final QRSize size;
  final QRCorrection correction;
  final PosAlign align;

  PosTicketQrcode(this.text, {
    this.align = PosAlign.center,
    this.size = QRSize.Size4,
    this.correction = QRCorrection.L
  });
}
