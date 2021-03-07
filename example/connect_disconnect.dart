import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi;
import 'package:twaindsm/twaindsm.dart';
import 'package:twaindsm/struct.dart';
import 'package:win32/win32.dart';

final twainDsm = TwainDsm(DynamicLibrary.open(
    // '${Directory.current.path}/twaindsm/TWAINDSM64-2.4.3.dll'));
    '${Directory.current.path}/twaindsm/TWAINDSM32-2.4.3.dll'));
    // 'C:\\Windows\\System32\\TWAINDSM.dll'));
    // 'C:\\Windows\\SysWOW64\\TWAINDSM.dll'));

void main(List<String> arguments) {
  var myInfo = TWIdentity();
  var parentPtr = ffi.allocate<Int32>();
  var entryPointPtr = ffi.allocate<TW_ENTRYPOINT>();

  fillIdentity(myInfo);
  parentPtr.value = GetConsoleWindow();

  try {
    if (!connectDSM(myInfo.pointer, parentPtr)) {
      return;
    }
    print('connectDSM success');

    if (myInfo.SupportedGroups & DF_DSM2 == DF_DSM2) {
      if (!getEntryPoint(myInfo.pointer, entryPointPtr)) {
        return;
      }
      print('getEntryPoint success');
    }

    operateDS(myInfo.pointer);

    if (!disconnectDSM(myInfo.pointer, parentPtr)) {
      return;
    }
    print('disconnectDSM success');
  } finally {
    myInfo.dispose();
    ffi.free(parentPtr);
    ffi.free(entryPointPtr);
  }
}

void fillIdentity(TWIdentity myInfo) {
  myInfo.Id = 0;
  var version = myInfo.Version;
  version.MajorNum = 2;
  version.MinorNum = 0;
  version.Language = TWLG_ENGLISH_CANADIAN;
  version.Country = TWCY_CANADA;
  version.Info = '2.0.9';
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

void operateDS(Pointer<TW_IDENTITY> myInfoPtr) {
  var dataSourceList = iterateDataSource(myInfoPtr);
  try {
    var dataSource = dataSourceList[2];
    if (!loadDS(myInfoPtr, dataSource.pointer)) {
      return;
    }
    print('loadDS success');

    if (!unloadDS(myInfoPtr, dataSource.pointer)) {
      return;
    }
    print('unloadDS success');
  } finally {
    dataSourceList.forEach((e) => e.dispose());
  }
}

List<TWIdentity> iterateDataSource(Pointer<TW_IDENTITY> myInfoPtr) {
  var dataSource = TWIdentity();
  var getFirst = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_IDENTITY, MSG_GETFIRST, dataSource.pointer.cast());
  if (getFirst == TWRC_ENDOFLIST) {
    dataSource.dispose();
    return [];
  } else if (getFirst != TWRC_SUCCESS) {
    var twcc = describeConditionCode(getTWCC(dataSource.pointer));
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
      var twcc = describeConditionCode(getTWCC(dataSource.pointer));
      print('DG_CONTROL / DAT_IDENTITY / MSG_GETNEXT Failed: $twcc');
      dataSource.dispose();
    }
  } while (getNext == TWRC_SUCCESS);

  return res;
}

bool loadDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
) {
  var openDS = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_IDENTITY, MSG_OPENDS, dataSourcePtr.cast());
  if (openDS != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_IDENTITY / MSG_OPENDS Failed: $openDS');
    var twcc = describeConditionCode(getTWCC(dataSourcePtr));
    print('twcc $twcc');
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
    print('DG_CONTROL / DAT_ENTRYPOINT / MSG_CLOSEDS Failed: $closeDS');
    var twcc = describeConditionCode(getTWCC(dataSourcePtr));
    print('twcc $twcc');
    return false;
  }
  return true;
}

int getTWCC(Pointer<TW_IDENTITY> dataSourcePtr) {
  var statusPtr = ffi.allocate<TW_STATUS>();
  try {
    var getStatus = twainDsm.DSM_Entry(dataSourcePtr, nullptr, DG_CONTROL,
        DAT_STATUS, MSG_GET, statusPtr.cast());
    return getStatus == TWRC_SUCCESS ? statusPtr.ref.ConditionCode : -1;
  } finally {
    ffi.free(statusPtr);
  }
}

String describeConditionCode(int twcc) {
  switch (twcc) {
    case TWCC_SUCCESS:
      return 'TWCC_SUCCESS';
    case TWCC_BUMMER:
      return 'TWCC_BUMMER';
    case TWCC_LOWMEMORY:
      return 'TWCC_LOWMEMORY';
    case TWCC_NODS:
      return 'TWCC_NODS';
    case TWCC_MAXCONNECTIONS:
      return 'TWCC_MAXCONNECTIONS';
    case TWCC_OPERATIONERROR:
      return 'TWCC_OPERATIONERROR';
    case TWCC_BADCAP:
      return 'TWCC_BADCAP';
    case TWCC_BADPROTOCOL:
      return 'TWCC_BADPROTOCOL';
    case TWCC_BADVALUE:
      return 'TWCC_BADVALUE';
    case TWCC_SEQERROR:
      return 'TWCC_SEQERROR';
    case TWCC_BADDEST:
      return 'TWCC_BADDEST';
    case TWCC_CAPUNSUPPORTED:
      return 'TWCC_CAPUNSUPPORTED';
    case TWCC_CAPBADOPERATION:
      return 'TWCC_CAPBADOPERATION';
    case TWCC_CAPSEQERROR:
      return 'TWCC_CAPSEQERROR';
    case TWCC_DENIED:
      return 'TWCC_DENIED';
    case TWCC_FILEEXISTS:
      return 'TWCC_FILEEXISTS';
    case TWCC_FILENOTFOUND:
      return 'TWCC_FILENOTFOUND';
    case TWCC_NOTEMPTY:
      return 'TWCC_NOTEMPTY';
    case TWCC_PAPERJAM:
      return 'TWCC_PAPERJAM';
    case TWCC_PAPERDOUBLEFEED:
      return 'TWCC_PAPERDOUBLEFEED';
    case TWCC_FILEWRITEERROR:
      return 'TWCC_FILEWRITEERROR';
    case TWCC_CHECKDEVICEONLINE:
      return 'TWCC_CHECKDEVICEONLINE';
    case TWCC_INTERLOCK:
      return 'TWCC_INTERLOCK';
    case TWCC_DAMAGEDCORNER:
      return 'TWCC_DAMAGEDCORNER';
    case TWCC_FOCUSERROR:
      return 'TWCC_FOCUSERROR';
    case TWCC_DOCTOOLIGHT:
      return 'TWCC_DOCTOOLIGHT';
    case TWCC_DOCTOODARK:
      return 'TWCC_DOCTOODARK';
    case TWCC_NOMEDIA:
      return 'TWCC_NOMEDIA';
    default:
      return 'ConditionCode $twcc';
  }
}
