import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:twaindsm/twaindsm.dart';

final bool kIsX64 = sizeOf<Pointer>() == 8;

final twainDsm = TwainDsm(DynamicLibrary.open(kIsX64
    ? '${Directory.current.path}/twaindsm/TWAINDSM64-2.4.3.dll'
    : '${Directory.current.path}/twaindsm/TWAINDSM32-2.4.3.dll'));

void main(List<String> arguments) {
  var identityPtr = malloc<Uint8>(156);
  var parentPtr = calloc<Int32>();

  try {
    var connect = twainDsm.DSM_Entry(identityPtr.cast(), nullptr, DG_CONTROL,
        DAT_PARENT, MSG_OPENDSM, parentPtr.cast<Void>());
    if (connect != TWRC_SUCCESS) {
      print('DG_CONTROL / DAT_PARENT / MSG_OPENDSM Failed: $connect\n');
      return;
    }
    print('connect success');

    var disconnect = twainDsm.DSM_Entry(identityPtr.cast(), nullptr, DG_CONTROL,
        DAT_PARENT, MSG_CLOSEDSM, parentPtr.cast<Void>());
    if (disconnect != TWRC_SUCCESS) {
      print('DG_CONTROL / DAT_PARENT / MSG_CLOSEDSM Failed: $disconnect\n');
      return;
    }
    print('disconnect success');
  } finally {
    malloc.free(identityPtr);
    calloc.free(parentPtr);
  }
}
