import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi;
import 'package:twaindsm/twaindsm.dart';

final twainDsm = TwainDsm(DynamicLibrary.open('${Directory.current.path}/twaindsm/TWAINDSM-2.4.3.dll'));

void main(List<String> arguments) {
  var identityPtr = ffi.allocate<pTW_IDENTITY>();
  var parentPtr = ffi.allocate<Int32>();

  try {
    var connect = twainDsm.DSM_Entry(identityPtr, nullptr, DG_CONTROL, DAT_PARENT, MSG_OPENDSM, parentPtr.cast<Void>());
    if (connect != TWRC_SUCCESS) {
      print('DG_CONTROL / DAT_PARENT / MSG_OPENDSM Failed: $connect\n');
      return;
    }
    print('connect success');

    var disconnect = twainDsm.DSM_Entry(identityPtr, nullptr, DG_CONTROL, DAT_PARENT, MSG_CLOSEDSM, parentPtr.cast<Void>());
    if (disconnect != TWRC_SUCCESS) {
      print('DG_CONTROL / DAT_PARENT / MSG_CLOSEDSM Failed: $disconnect\n');
      return;
    }
    print('disconnect success');
  } finally {
    ffi.free(identityPtr);
    ffi.free(parentPtr);
  }
}
