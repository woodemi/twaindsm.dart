import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:twaindsm/structs.dart';
import 'package:twaindsm/twaindsm.dart';

final bool kIsX64 = sizeOf<Pointer>() == 8;

final twainDsm = TwainDsm(DynamicLibrary.open(kIsX64
    ? '${Directory.current.path}/twaindsm/TWAINDSM64-2.4.3.dll'
    : '${Directory.current.path}/twaindsm/TWAINDSM32-2.4.3.dll'));

void main(List<String> arguments) {
  var myInfoPtr = calloc<TW_IDENTITY>();
  var parentPtr = calloc<Int32>();

  fillMyInfo(myInfoPtr.ref);

  try {
    var connect = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_PARENT, MSG_OPENDSM, parentPtr.cast<Void>());
    if (connect != TWRC_SUCCESS) {
      print('DG_CONTROL / DAT_PARENT / MSG_OPENDSM Failed: $connect\n');
      return;
    }
    print('connect success');

    var disconnect = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_PARENT, MSG_CLOSEDSM, parentPtr.cast<Void>());
    if (disconnect != TWRC_SUCCESS) {
      print('DG_CONTROL / DAT_PARENT / MSG_CLOSEDSM Failed: $disconnect\n');
      return;
    }
    print('disconnect success');
  } finally {
    calloc.free(myInfoPtr);
    calloc.free(parentPtr);
  }
}

void fillMyInfo(TW_IDENTITY myInfo) {
  myInfo.Id = 0;
  var version = myInfo.Version;
  version.MajorNum = 2;
  version.MinorNum = 0;
  version.Language = TWLG_ENGLISH_CANADIAN;
  version.Country = TWCY_CANADA;
  version.setInfo('2.0.9');
  myInfo.ProtocolMajor = 2;
  myInfo.ProtocolMinor = 4;
  myInfo.SupportedGroups = DF_APP2 | DG_IMAGE | DG_CONTROL;
  myInfo.setManufacturer('App\'s Manufacturer');
  myInfo.setProductFamily('App\'s Product Family');
  myInfo.setProductName('Specific App Product Name');
}