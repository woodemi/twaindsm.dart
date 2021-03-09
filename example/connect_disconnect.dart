import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;
import 'package:twaindsm/gdi32.dart';
import 'package:twaindsm/twaindsm.dart';
import 'package:twaindsm/struct.dart';
import 'package:twaindsm/user32.dart';
import 'package:win32/win32.dart';

final user32 = User32(DynamicLibrary.open('user32.dll'));

final twainDsm = TwainDsm(DynamicLibrary.open(
    // '${Directory.current.path}/twaindsm/TWAINDSM64-2.4.3.dll'));
    '${Directory.current.path}/twaindsm/TWAINDSM32-2.4.3.dll'));
    // 'C:\\Windows\\System32\\TWAINDSM.dll'));
    // 'C:\\Windows\\SysWOW64\\TWAINDSM.dll'));

void main(List<String> arguments) {
  var myInfoStruct = TWIdentity();
  var consolePtr = ffi.allocate<Int32>();
  var entryPointPtr = ffi.allocate<pTW_ENTRYPOINT>();

  fillIdentity(myInfoStruct);
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

    operateDS(myInfoStruct.pointer, entryPointPtr);

    if (!disconnectDSM(myInfoStruct.pointer, consolePtr)) {
      return;
    }
    print('disconnectDSM success');
  } finally {
    myInfoStruct.dispose();
    ffi.free(consolePtr);
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
  Pointer<pTW_IDENTITY> myInfoPtr,
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
  Pointer<pTW_IDENTITY> myInfoPtr,
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
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_ENTRYPOINT> entryPointPtr,
) {
  entryPointPtr.ref.Size = sizeOf<pTW_ENTRYPOINT>();
  var entryPoint = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_ENTRYPOINT, MSG_GET, entryPointPtr.cast());
  if (entryPoint != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_ENTRYPOINT / MSG_GET Failed: $entryPoint');
    return false;
  }
  return true;
}

void operateDS(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_ENTRYPOINT> entryPointPtr,
) {
  var dataSourceStructList = iterateDataSource(myInfoPtr);
  try {
    var dataSourceStruct = dataSourceStructList[2];
    if (!loadDS(myInfoPtr, dataSourceStruct.pointer)) {
      return;
    }
    print('loadDS success');

    opDS(myInfoPtr, dataSourceStruct.pointer, entryPointPtr);

    if (!unloadDS(myInfoPtr, dataSourceStruct.pointer)) {
      return;
    }
    print('unloadDS success');
  } finally {
    dataSourceStructList.forEach((e) => e.dispose());
  }
}

void opDS(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
  Pointer<pTW_ENTRYPOINT> entryPointPtr,
) {
  if (!enableDS(myInfoPtr, dataSourcePtr, user32.GetDesktopWindow())) {
    return;
  }
  print('enableDS success');
  
  var dsMessage = pollTWMessage(myInfoPtr, dataSourcePtr);
  
  if (dsMessage == MSG_XFERREADY) {
    var xferMechPtr = allocateCAP(myInfoPtr, dataSourcePtr, ICAP_XFERMECH);

    // startScan(dataSourcePtr, xferMechPtr);
    var xferMechValue = getCurrent(xferMechPtr, entryPointPtr);
    switch (xferMechValue) {
      case TWSX_NATIVE:
        initiateTransfer_Native(myInfoPtr, dataSourcePtr, entryPointPtr);
        break;
    }

    entryPointPtr.memFree(xferMechPtr.ref.hContainer);
    ffi.free(xferMechPtr);
  }
  
  disableDS(myInfoPtr, dataSourcePtr);
}

int pollTWMessage(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
) {
  var msgPtr = ffi.allocate<MSG>();
  var eventPtr = ffi.allocate<pTW_EVENT>();
  var dsMessage = MSG_NULL;
  while (dsMessage == MSG_NULL) {
    if (GetMessage(msgPtr, 0, 0, 0) != TRUE) {
      break; // WM_QUIT
    }
  
    eventPtr.ref.pEvent = msgPtr.cast();
    eventPtr.ref.TWMessage = MSG_NULL;
    var processEvent = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_EVENT, MSG_PROCESSEVENT, eventPtr.cast());
    if (processEvent != TWRC_DSEVENT) {
      TranslateMessage(msgPtr);
      DispatchMessage(msgPtr);
      continue;
    }
  
    switch (eventPtr.ref.TWMessage) {
      case MSG_XFERREADY:
      case MSG_CLOSEDSREQ:
      case MSG_CLOSEDSOK:
      case MSG_NULL:
        dsMessage = eventPtr.ref.TWMessage;
        break;
      default:
        print('Unknown message in MSG_PROCESSEVENT loop');
        break;
    }
  }
  ffi.free(eventPtr);
  ffi.free(msgPtr);
  return dsMessage;
}

List<TWIdentity> iterateDataSource(Pointer<pTW_IDENTITY> myInfoPtr) {
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
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
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
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
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

Pointer<pTW_CAPABILITY> allocateCAP(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
  int cap,
) {
  var capability = ffi.allocate<pTW_CAPABILITY>();
  capability.ref.Cap = cap;
  capability.ref.ConType = TWON_DONTCARE16;
  var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_CAPABILITY, MSG_GET, capability.cast());
  if (twrc != TWRC_SUCCESS) {
    var twcc = describeConditionCode(getTWCC(dataSourcePtr));
    print('Failed to get the capability: [${capability.ref.Cap}], $twcc');
    ffi.free(capability);
    return null;
  }
  return capability;
}

bool enableDS(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
  Pointer<HWND> windowsPtr,
) {
  var userInterfacePtr = ffi.allocate<pTW_USERINTERFACE>();
  try {
    userInterfacePtr.ref.ShowUI = FALSE;
    userInterfacePtr.ref.ModalUI = TRUE;
    userInterfacePtr.ref.hParent = windowsPtr.cast();
    var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_USERINTERFACE, MSG_ENABLEDS, userInterfacePtr.cast());
    if (twrc != TWRC_SUCCESS && twrc != TWRC_CHECKSTATUS) {
      var twcc = describeConditionCode(getTWCC(dataSourcePtr));
      print('Cannot enable source $twcc');
      return false;
    }
    return true;
  } finally {
    ffi.free(userInterfacePtr);
  }
}

void disableDS(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
) {
  var userInterfacePtr = ffi.allocate<pTW_USERINTERFACE>();
  try {
    var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_USERINTERFACE, MSG_ENABLEDS, userInterfacePtr.cast());
    if (twrc != TWRC_SUCCESS) {
      var twcc = describeConditionCode(getTWCC(dataSourcePtr));
      print('Cannot disable source $twcc');
    }
  } finally {
    ffi.free(userInterfacePtr);
  }
}

void initiateTransfer_Native(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
  Pointer<pTW_ENTRYPOINT> entryPointPtr,
) {
  print('initiateTransfer_Native');

  var imageInfoStruct = TWImageInfo();
  var containerRefPtr = ffi.allocate<Pointer<Void>>();

  var pendingXfers = true;
  var xferNum = 0;
  while (pendingXfers) {
    xferNum++;
    if (!updateIMAGEINFO(myInfoPtr, dataSourcePtr, imageInfoStruct.pointer)) {
      break;
    }
    print('imageInfoStruct $imageInfoStruct');

    var getNativeXfer = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_IMAGE, DAT_IMAGENATIVEXFER, MSG_GET, containerRefPtr.cast());
    print('getNativeXfer $getNativeXfer');
    if (getNativeXfer == TWRC_CANCEL) {
      var twcc = describeConditionCode(getTWCC(dataSourcePtr));
      print('Canceled transfer image $twcc');
      break;
    } else if (getNativeXfer == TWRC_FAILURE) {
      var twcc = describeConditionCode(getTWCC(dataSourcePtr));
      print('Failed to transfer image $twcc');
      break;
    } else if (getNativeXfer != TWRC_XFERDONE) {
      continue;
    }
    
    var containerPtr = containerRefPtr.value;
    var infoHeaderPtr = entryPointPtr.memLock(containerPtr).cast<BITMAPINFOHEADER>();
    try {
      if (infoHeaderPtr == nullptr) {
        break;
      }
      var ref = infoHeaderPtr.ref;
      print('${ref.biSize}, ${ref.biWidth}, ${ref.biHeight}');
      print('${ref.biPlanes}, ${ref.biBitCount}, ${ref.biCompression}');
      print('${ref.biXPelsPerMeter}, ${ref.biYPelsPerMeter}, ${ref.biClrUsed}, ${ref.biClrImportant}');
      if (infoHeaderPtr.getPaletteSize() == null) {
        break;
      }
      saveToFile(infoHeaderPtr, 'FROM_SCANNER_${xferNum.toString().padLeft(6, '0')}.bmp');
    } finally {
      entryPointPtr.memUnlock(containerPtr);
      entryPointPtr.memFree(containerPtr);
    }

    // TODO updateEXTIMAGEINFO();

    var pendingXfersPtr = ffi.allocate<pTW_PENDINGXFERS>();
    var getPendingXfers = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_PENDINGXFERS, MSG_ENDXFER, pendingXfersPtr.cast());
    if (getPendingXfers == TWRC_SUCCESS) {
      print('app: Remaining images to transfer: ${pendingXfersPtr.ref.Count}');
      pendingXfers = pendingXfersPtr.ref.Count > 0;
    } else {
      var twcc = describeConditionCode(getTWCC(dataSourcePtr));
      print('Failed to properly end the transfer $twcc');
      pendingXfers = false;
    }
  }

  if (pendingXfers) {
    DoAbortXfer();
  }

  imageInfoStruct.dispose();
  ffi.free(containerRefPtr);

  print('app: DONE!');
}

bool updateIMAGEINFO(
  Pointer<pTW_IDENTITY> myInfoPtr,
  Pointer<pTW_IDENTITY> dataSourcePtr,
  Pointer<pTW_IMAGEINFO> imageInfoPtr,
) {
  var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_IMAGE, DAT_IMAGEINFO, MSG_GET, imageInfoPtr.cast());
  if (twrc != TWRC_SUCCESS) {
    var twcc = describeConditionCode(getTWCC(dataSourcePtr));
    print('Error while trying to get the image information! $twcc');
    return false;
  }
  return true;
}

void saveToFile(Pointer<BITMAPINFOHEADER> infoHeaderPtr, String path) {
  var imageOffset = sizeOf<BITMAPINFOHEADER>() + sizeOf<RGBQUAD>() * infoHeaderPtr.getPaletteSize();
  print('imageOffset $imageOffset');

  if (infoHeaderPtr.ref.biSizeImage == 0) {
    print('TODO biSizeImage');
  }
  var contentSize = imageOffset + infoHeaderPtr.ref.biSizeImage;
  print('contentSize $contentSize');

  var fileHeaderPtr = TWBitmapFileHeader();
  fileHeaderPtr.bfType = 0x4d42; // 'MB'
  fileHeaderPtr.bfSize = TWBitmapFileHeader.SIZE + contentSize;
  fileHeaderPtr.bfOffBits = TWBitmapFileHeader.SIZE + imageOffset;

  var file = File(path);
  file.writeAsBytesSync(fileHeaderPtr.pointer.cast<Uint8>().asTypedList(TWBitmapFileHeader.SIZE));
  file.writeAsBytesSync(infoHeaderPtr.cast<Uint8>().asTypedList(contentSize), mode: FileMode.append);
}

void DoAbortXfer() {
  // TODO
}

int getCurrent(
  Pointer<pTW_CAPABILITY> cap,
  Pointer<pTW_ENTRYPOINT> entryPointPtr,
) {
  if (cap.ref.hContainer == nullptr) {
    return null;
  }

  var containerPtr = entryPointPtr.memLock(cap.ref.hContainer);
  try {
    if (cap.ref.ConType == TWON_ENUMERATION) {
      var enumerationPtr = TWEnumeration.fromAddress(containerPtr.address);
      var itemListPtr = Pointer.fromAddress(enumerationPtr.getItemListAddress());
      switch (enumerationPtr.ItemType) {
        case TWTY_INT32:
          return itemListPtr.cast<Int32>()[enumerationPtr.CurrentIndex];
        case TWTY_UINT32:
          return itemListPtr.cast<Uint32>()[enumerationPtr.CurrentIndex];
        case TWTY_INT16:
          return itemListPtr.cast<Int16>()[enumerationPtr.CurrentIndex];
        case TWTY_UINT16:
          return itemListPtr.cast<Uint16>()[enumerationPtr.CurrentIndex];
        case TWTY_INT8:
          return itemListPtr.cast<Int8>()[enumerationPtr.CurrentIndex];
        case TWTY_UINT8:
          return itemListPtr.cast<Uint8>()[enumerationPtr.CurrentIndex];
        case TWTY_BOOL:
          return itemListPtr.cast<Uint16>()[enumerationPtr.CurrentIndex];
      }
    } else if (cap.ref.ConType == TWON_ONEVALUE) {

    } else if (cap.ref.ConType == TWON_RANGE) {

    }
    return null;
  } finally {
    entryPointPtr.memUnlock(cap.ref.hContainer);    
  }

}

int getTWCC(Pointer<pTW_IDENTITY> dataSourcePtr) {
  var statusPtr = ffi.allocate<pTW_STATUS>();
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

extension TWEntryPointPointer on Pointer<pTW_ENTRYPOINT> {
  Pointer<Void> Function(int) get memAllocate => ref.DSM_MemAllocate.asFunction();

  void Function(Pointer<Void>) get memFree => ref.DSM_MemFree.asFunction();

  Pointer<Void> Function(Pointer<Void>) get memLock => ref.DSM_MemLock.asFunction();

  void Function(Pointer<Void>) get memUnlock => ref.DSM_MemUnlock.asFunction();
}

extension BitmapInfoHeaderPointer on Pointer<BITMAPINFOHEADER> {
  int getPaletteSize() {
    print('ref.biBitCount ${ref.biBitCount}');
    switch (ref.biBitCount) {
      case 1:
        return 2;
      case 8:
        return 256;
      case 24:
        return 0;
      default:
        return null;
    }
  }
}