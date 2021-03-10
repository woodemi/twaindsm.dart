import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:twaindsm/structs.dart';
import 'package:twaindsm/twaindsm.dart';
import 'package:twaindsm/utils.dart';
import 'package:win32/win32.dart';

final bool kIsX64 = sizeOf<Pointer>() == 8;

final twainDsm = TwainDsm(DynamicLibrary.open(kIsX64
    ? '${Directory.current.path}/twaindsm/TWAINDSM64-2.4.3.dll'
    : '${Directory.current.path}/twaindsm/TWAINDSM32-2.4.3.dll'));

void main(List<String> arguments) {
  var myInfoPtr = calloc<TW_IDENTITY>();
  var consolePtr = calloc<Int32>();
  var entryPointPtr = calloc<TW_ENTRYPOINT>();

  fillMyInfo(myInfoPtr.ref);
  consolePtr.value = GetConsoleWindow();

  try {
    if (!connectDSM(myInfoPtr, consolePtr)) {
      return;
    }
    print('connectDSM success');

    if (myInfoPtr.ref.SupportedGroups & DF_DSM2 == DF_DSM2) {
      if (!getEntryPoint(myInfoPtr, entryPointPtr)) {
        return;
      }
      print('getEntryPoint success');
    }

    var dataSourceList = iterateDataSource(myInfoPtr);
    try {
      dataSourceList?.forEach((e) {
        print('TW_IDENTITY ${e.ref.toMap()}');
        print('Manufacturer ${e.ref.getManufacturer()}');
        print('ProductFamily ${e.ref.getProductFamily()}');
        print('ProductName ${e.ref.getProductName()}');
      });
    } finally {
      dataSourceList?.forEach((e) => calloc.free(e));
    }

    if (!disconnectDSM(myInfoPtr, consolePtr)) {
      return;
    }
    print('disconnectDSM success');
  } finally {
    calloc.free(myInfoPtr);
    calloc.free(consolePtr);
    calloc.free(entryPointPtr);
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

bool connectDSM(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<Int32> parentPtr,
) {
  var connect = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL, DAT_PARENT,
      MSG_OPENDSM, parentPtr.cast());
  if (connect != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_PARENT / MSG_OPENDSM Failed: $connect');
    return false;
  }
  return true;
}

bool disconnectDSM(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<Int32> parentPtr,
) {
  var disconnect = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_PARENT, MSG_CLOSEDSM, parentPtr.cast());
  if (disconnect != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_PARENT / MSG_CLOSEDSM Failed: $disconnect');
    return false;
  }
  return true;
}

bool getEntryPoint(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_ENTRYPOINT> entryPointPtr,
) {
  entryPointPtr.ref.Size = sizeOf<TW_ENTRYPOINT>();
  var entryPoint = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_ENTRYPOINT, MSG_GET, entryPointPtr.cast());
  if (entryPoint != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_ENTRYPOINT / MSG_GET Failed: $entryPoint');
    return false;
  }
  return true;
}

List<Pointer<TW_IDENTITY>>? iterateDataSource(Pointer<TW_IDENTITY> myInfoPtr) {
  var dataSource = calloc<TW_IDENTITY>();
  var getFirst = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_IDENTITY, MSG_GETFIRST, dataSource.cast());
  if (getFirst == TWRC_ENDOFLIST) {
    calloc.free(dataSource);
    return [];
  } else if (getFirst != TWRC_SUCCESS) {
    var twcc = twainDsm.getConditionCodeString(dataSource);
    print('DG_CONTROL / DAT_IDENTITY / MSG_GETNEXT Failed: $twcc');
    calloc.free(dataSource);
    return null;
  }
  var res = [dataSource];

  int getNext;
  do {
    dataSource = calloc<TW_IDENTITY>();
    getNext = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_IDENTITY, MSG_GETNEXT, dataSource.cast());
    if (getNext == TWRC_SUCCESS) {
      res.add(dataSource);
    } else if (getNext == TWRC_ENDOFLIST) {
      calloc.free(dataSource);
      return res;
    } else if (getNext == TWRC_FAILURE) {
      var twcc = twainDsm.getConditionCodeString(dataSource);
      print('DG_CONTROL / DAT_IDENTITY / MSG_GETNEXT Failed: $twcc');
      calloc.free(dataSource);
    }
  } while (getNext == TWRC_SUCCESS);

  return res;
}