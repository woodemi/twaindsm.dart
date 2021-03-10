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
  var myInfoStruct = TWIdentity();
  var consolePtr = calloc<Int32>();
  var entryPointPtr = calloc<TW_ENTRYPOINT>();

  fillMyInfo(myInfoStruct);
  consolePtr.value = GetConsoleWindow();

  try {
    if (!connectDSM(myInfoStruct.pointer, consolePtr)) {
      return;
    }
    print('connectDSM success');

    if (myInfoStruct.SupportedGroups & DF_DSM2 == DF_DSM2) {
      if (!getEntryPoint(myInfoStruct.pointer, entryPointPtr)) {
        return;
      }
      print('getEntryPoint success');
    }

    operateDataSource(myInfoStruct.pointer);

    if (!disconnectDSM(myInfoStruct.pointer, consolePtr)) {
      return;
    }
    print('disconnectDSM success');
  } finally {
    myInfoStruct.dispose();
    calloc.free(consolePtr);
    calloc.free(entryPointPtr);
  }
}

void fillMyInfo(TWIdentity myInfo) {
  myInfo.Id = 0;
  var version = myInfo.Version.ref;
  version.MajorNum = 2;
  version.MinorNum = 0;
  version.Language = TWLG_ENGLISH_CANADIAN;
  version.Country = TWCY_CANADA;
  version.setInfo('2.0.9');
  myInfo.ProtocolMajor = 2;
  myInfo.ProtocolMinor = 4;
  myInfo.SupportedGroups = DF_APP2 | DG_IMAGE | DG_CONTROL;
  myInfo.Manufacturer = 'App\'s Manufacturer';
  myInfo.ProductFamily = 'App\'s Product Family';
  myInfo.ProductName = 'Specific App Product Name';
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

List<TWIdentity>? iterateDataSource(Pointer<TW_IDENTITY> myInfoPtr) {
  var dataSource = TWIdentity();
  var getFirst = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_IDENTITY, MSG_GETFIRST, dataSource.pointer.cast());
  if (getFirst == TWRC_ENDOFLIST) {
    dataSource.dispose();
    return [];
  } else if (getFirst != TWRC_SUCCESS) {
    var twcc = twainDsm.getConditionCodeString(dataSource.pointer);
    print('DG_CONTROL / DAT_IDENTITY / MSG_GETNEXT Failed: $twcc');
    dataSource.dispose();
    return null;
  }
  var res = [dataSource];

  int getNext;
  do {
    dataSource = TWIdentity();
    getNext = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_IDENTITY, MSG_GETNEXT, dataSource.pointer.cast());
    if (getNext == TWRC_SUCCESS) {
      res.add(dataSource);
    } else if (getNext == TWRC_ENDOFLIST) {
      dataSource.dispose();
      return res;
    } else if (getNext == TWRC_FAILURE) {
      var twcc = twainDsm.getConditionCodeString(dataSource.pointer);
      print('DG_CONTROL / DAT_IDENTITY / MSG_GETNEXT Failed: $twcc');
      dataSource.dispose();
    }
  } while (getNext == TWRC_SUCCESS);

  return res;
}

void operateDataSource(Pointer<TW_IDENTITY> myInfoPtr) {
  var dataSourceStructList = iterateDataSource(myInfoPtr);
  if (dataSourceStructList == null) return;

  try {
    var dataSourceStruct = dataSourceStructList[0];
    if (!loadDS(myInfoPtr, dataSourceStruct.pointer)) {
      return;
    }
    print('loadDS success');

    if (!unloadDS(myInfoPtr, dataSourceStruct.pointer)) {
      return;
    }
    print('unloadDS success');
  } finally {
    dataSourceStructList.forEach((e) => e.dispose());
  }
}

bool loadDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
) {
  var openDS = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_IDENTITY, MSG_OPENDS, dataSourcePtr.cast());
  if (openDS != TWRC_SUCCESS) {
    var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
    print('DG_CONTROL / DAT_IDENTITY / MSG_OPENDS Failed: $twcc');
    return false;
  }
  return true;
}

bool unloadDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
) {
  var closeDS = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_IDENTITY, MSG_CLOSEDS, dataSourcePtr.cast());
  if (closeDS != TWRC_SUCCESS) {
    var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
    print('DG_CONTROL / DAT_ENTRYPOINT / MSG_CLOSEDS Failed: $twcc');
    return false;
  }
  return true;
}