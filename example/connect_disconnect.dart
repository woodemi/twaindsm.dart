import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi;
import 'package:twaindsm/twaindsm.dart';
import 'package:twaindsm/struct.dart';
import 'package:win32/win32.dart';

final twainDsm = TwainDsm(DynamicLibrary.open(
    '${Directory.current.path}/twaindsm/TWAINDSM-2.4.3.dll'));

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
  // FIXME sizeOf<TW_ENTRYPOINT>() = 48;
  entryPointPtr.ref.Size = 44;
  var entryPoint = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_ENTRYPOINT, MSG_GET, entryPointPtr.cast());
  if (entryPoint != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_ENTRYPOINT / MSG_GET Failed: $entryPoint');
    return false;
  }
  return true;
}

void operateDS(Pointer<TW_IDENTITY> myInfoPtr) {
  var dataSource = TWIdentity();

  try {
    // getFirstSource(myInfo.pointer);

    dataSource.Id = 1;
    var version = dataSource.Version;
    version.MajorNum = 2;
    version.MinorNum = 4;
    version.Language = 2;
    version.Country = 1;
    version.Info = '2.4.0 sample release 64bit';
    dataSource.ProtocolMajor = 2;
    dataSource.ProtocolMinor = 4;
    dataSource.SupportedGroups = 0x40000003;
    dataSource.Manufacturer = 'TWAIN Working Group';
    dataSource.ProductFamily = 'Software Scan';
    dataSource.ProductName = 'TWAIN2 Software Scanner';

    if (!loadDS(myInfoPtr, dataSource.pointer)) {
      return;
    }
    print('loadDS success');

    if (!unloadDS(myInfoPtr, dataSource.pointer)) {
      return;
    }
    print('unloadDS success');
  } finally {
    dataSource.dispose();
  }
}

void getFirstSource(
  Pointer<TW_IDENTITY> myInfoPtr,
) {
  var source = TWIdentity();
  try {
    var getFirst = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
        DAT_IDENTITY, MSG_GETFIRST, source.pointer.cast());
    if (getFirst == TWRC_ENDOFLIST) {
      print('No source found');
      return;
    } else if (getFirst != TWRC_SUCCESS) {
      print('DG_CONTROL / DAT_IDENTITY / MSG_GETFIRST Failed: $getFirst');
      return;
    }
    print('source $source');
  } finally {
    source.dispose();
  }
}

bool loadDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
) {
  var openDS = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_ENTRYPOINT, MSG_OPENDS, dataSourcePtr.cast());
  if (openDS != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_ENTRYPOINT / MSG_OPENDS Failed: $openDS');
    return false;
  }
  return true;
}

bool unloadDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
) {
  var closeDS = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_ENTRYPOINT, MSG_CLOSEDS, dataSourcePtr.cast());
  if (closeDS != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_ENTRYPOINT / MSG_CLOSEDS Failed: $closeDS');
    return false;
  }
  return true;
}