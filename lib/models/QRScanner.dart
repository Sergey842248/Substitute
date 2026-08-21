import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanner extends StatefulWidget {
  QRScanner({
    Key? key,
    required this.setData,
  }) : super(key: key);

  final Function(String?) setData;

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  MobileScannerController? controller;
  bool _hasPopped = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                if (_hasPopped) return;
                final barcode = capture.barcodes.first;
                if (barcode.rawValue != null) {
                  _hasPopped = true;
                  widget.setData(barcode.rawValue);
                  Navigator.pop(context);
                }
              },
            ),
            // infotext
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.1,
                ),
                child: Text(
                  'Scan the QR-Code from another user',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // cancelbutton
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.1,
                ),
                height: MediaQuery.of(context).size.height * 0.08,
                width: MediaQuery.of(context).size.height * 0.08,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(100)),
                      color: Theme.of(context).primaryColor,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.close,
                        color:
                            Theme.of(context).primaryColor.computeLuminance() >
                                    0.5
                                ? Colors.black
                                : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
