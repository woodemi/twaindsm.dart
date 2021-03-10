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
  var consolePtr = Pointer.fromAddress(GetConsoleWindow());
  var entryPointPtr = calloc<TW_ENTRYPOINT>();

  fillMyInfo(myInfoPtr.ref);

  try {
    if (!connectDSM(myInfoPtr, consolePtr.cast())) {
      return;
    }
    print('connectDSM success');

    if (myInfoPtr.ref.SupportedGroups & DF_DSM2 == DF_DSM2) {
      if (!getEntryPoint(myInfoPtr, entryPointPtr)) {
        return;
      }
      print('getEntryPoint success');
    }

    operateDataSource(myInfoPtr, entryPointPtr);

    if (!disconnectDSM(myInfoPtr, consolePtr.cast())) {
      return;
    }
    print('disconnectDSM success');
  } finally {
    calloc.free(myInfoPtr);
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
  Pointer<Void> parentPtr,
) {
  var connect = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL, DAT_PARENT,
      MSG_OPENDSM, parentPtr);
  if (connect != TWRC_SUCCESS) {
    print('DG_CONTROL / DAT_PARENT / MSG_OPENDSM Failed: $connect');
    return false;
  }
  return true;
}

bool disconnectDSM(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<Void> parentPtr,
) {
  var disconnect = twainDsm.DSM_Entry(myInfoPtr, nullptr, DG_CONTROL,
      DAT_PARENT, MSG_CLOSEDSM, parentPtr);
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

void operateDataSource(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_ENTRYPOINT> entryPointPtr,
) {
  var dataSourceList = iterateDataSource(myInfoPtr);
  if (dataSourceList == null || dataSourceList.isEmpty) {
    print('dataSourceList is null or emtpy');
    return;
  }

  try {
    var dataSource = dataSourceList[0];
    if (!loadDS(myInfoPtr, dataSource)) {
      return;
    }
    print('loadDS success');

    opDS(myInfoPtr, dataSource, entryPointPtr);

    if (!unloadDS(myInfoPtr, dataSource)) {
      return;
    }
    print('unloadDS success');
  } finally {
    dataSourceList.forEach((e) => calloc.free(e));
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

void opDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
  Pointer<TW_ENTRYPOINT> entryPointPtr,
) {
  if (!enableDS(myInfoPtr, dataSourcePtr, GetDesktopWindow())) {
    return;
  }
  print('enableDS success');

  var dsMessage = pollTWMessage(myInfoPtr, dataSourcePtr);

  if (dsMessage == MSG_XFERREADY) {
    var xferMechPtr = calloc<TW_CAPABILITY>();
    if (getCapability(myInfoPtr, dataSourcePtr, ICAP_XFERMECH, xferMechPtr)) {
      // startScan(dataSourcePtr, xferMechPtr);
      var xferMechCurrent = getCurrent(xferMechPtr, entryPointPtr);
      switch (xferMechCurrent) {
        case TWSX_NATIVE:
          initiateTransfer_Native(myInfoPtr, dataSourcePtr, entryPointPtr);
          break;
      }
      entryPointPtr.ref.memFree(xferMechPtr.ref.hContainer);
    }
    calloc.free(xferMechPtr);
  }

  if (!disableDS(myInfoPtr, dataSourcePtr)) {
    return;
  }
  print('disableDS success');
}

bool enableDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
  int hwnd,
) {
  var userInterfacePtr = calloc<TW_USERINTERFACE>();
  try {
    userInterfacePtr.ref.ShowUI = FALSE;
    userInterfacePtr.ref.ModalUI = TRUE;
    userInterfacePtr.ref.hParent = Pointer.fromAddress(hwnd);
    var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_USERINTERFACE, MSG_ENABLEDS, userInterfacePtr.cast());
    if (twrc != TWRC_SUCCESS && twrc != TWRC_CHECKSTATUS) {
      var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
      print('Cannot enable source $twcc');
      return false;
    }
    return true;
  } finally {
    calloc.free(userInterfacePtr);
  }
}

bool disableDS(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
) {
  var userInterfacePtr = calloc<TW_USERINTERFACE>();
  try {
    var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_USERINTERFACE, MSG_DISABLEDS, userInterfacePtr.cast());
    if (twrc != TWRC_SUCCESS) {
      var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
      print('Cannot disable source $twcc');
      return false;
    }
    return true;
  } finally {
    calloc.free(userInterfacePtr);
  }
}

int pollTWMessage(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
) {
  var msgPtr = calloc<MSG>();
  var eventPtr = calloc<TW_EVENT>();
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
  calloc.free(eventPtr);
  calloc.free(msgPtr);
  return dsMessage;
}

bool getCapability(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
  int cap,
  Pointer<TW_CAPABILITY> capabilityPtr,
) {
  capabilityPtr.ref.Cap = cap;
  capabilityPtr.ref.ConType = TWON_DONTCARE16;
  var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_CAPABILITY, MSG_GET, capabilityPtr.cast());
  if (twrc != TWRC_SUCCESS) {
    var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
    print('Failed to get the capability: [$cap], $twcc');
    return false;
  }
  return true;
}

int? getCurrent(
  Pointer<TW_CAPABILITY> capabilityPtr,
  Pointer<TW_ENTRYPOINT> entryPointPtr,
) {
  if (capabilityPtr.ref.hContainer == nullptr) {
    return null;
  }

  var containerPtr = entryPointPtr.ref.memLock(capabilityPtr.ref.hContainer);
  try {
    if (capabilityPtr.ref.ConType == TWON_ENUMERATION) {
      var enumerationPtr = containerPtr.cast<TW_ENUMERATION>();
      var itemListPtr = Pointer.fromAddress(enumerationPtr.itemListAddress);
      var enumeration = enumerationPtr.ref;
      switch (enumeration.ItemType) {
        case TWTY_INT8:
          return itemListPtr.cast<Int8>()[enumeration.CurrentIndex];
        case TWTY_INT16:
          return itemListPtr.cast<Int16>()[enumeration.CurrentIndex];
        case TWTY_INT32:
          return itemListPtr.cast<Int32>()[enumeration.CurrentIndex];
        case TWTY_UINT8:
          return itemListPtr.cast<Uint8>()[enumeration.CurrentIndex];
        case TWTY_UINT16:
          return itemListPtr.cast<Uint16>()[enumeration.CurrentIndex];
        case TWTY_UINT32:
          return itemListPtr.cast<Uint32>()[enumeration.CurrentIndex];
        case TWTY_BOOL:
          return itemListPtr.cast<Uint16>()[enumeration.CurrentIndex];
      }
    } else if (capabilityPtr.ref.ConType == TWON_ONEVALUE) {
      // TODO
    } else if (capabilityPtr.ref.ConType == TWON_RANGE) {
      // TODO
    }
    return null;
  } finally {
    entryPointPtr.ref.memUnlock(capabilityPtr.ref.hContainer);    
  }
}

void initiateTransfer_Native(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
  Pointer<TW_ENTRYPOINT> entryPointPtr,
) {
  print('initiateTransfer_Native');

  var imageInfoPtr = calloc<TW_IMAGEINFO>();
  var containerRefPtr = calloc<Pointer<Void>>();

  var pendingXfers = true;
  var xferNum = 0;
  while (pendingXfers) {
    xferNum++;
    if (!updateImageInfo(myInfoPtr, dataSourcePtr, imageInfoPtr)) {
      break;
    }
    print('imageInfo ${imageInfoPtr.ref.toMap()}');

    var getNativeXfer = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_IMAGE, DAT_IMAGENATIVEXFER, MSG_GET, containerRefPtr.cast());
    if (getNativeXfer == TWRC_CANCEL) {
      var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
      print('Canceled transfer image $twcc');
      break;
    } else if (getNativeXfer == TWRC_FAILURE) {
      var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
      print('Failed to transfer image $twcc');
      break;
    } else if (getNativeXfer != TWRC_XFERDONE) {
      continue;
    }
    
    var containerPtr = containerRefPtr.value;
    var infoHeaderPtr = entryPointPtr.ref.memLock(containerPtr).cast<BITMAPINFOHEADER>();
    try {
      if (infoHeaderPtr == nullptr || infoHeaderPtr.ref.paletteSize == null) {
        break;
      }
      saveToFile(infoHeaderPtr, 'FROM_SCANNER_${xferNum.toString().padLeft(6, '0')}.bmp');
    } finally {
      entryPointPtr.ref.memUnlock(containerPtr);
      entryPointPtr.ref.memFree(containerPtr);
    }

    // TODO updateEXTIMAGEINFO();

    var pendingXfersPtr = calloc<TW_PENDINGXFERS>();
    var getPendingXfers = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_CONTROL, DAT_PENDINGXFERS, MSG_ENDXFER, pendingXfersPtr.cast());
    if (getPendingXfers == TWRC_SUCCESS) {
      print('app: Remaining images to transfer: ${pendingXfersPtr.ref.Count}');
      pendingXfers = pendingXfersPtr.ref.Count > 0;
    } else {
      var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
      print('Failed to properly end the transfer $twcc');
      pendingXfers = false;
    }
  }

  if (pendingXfers) {
    // TODO DoAbortXfer();
  }

  calloc.free(imageInfoPtr);
  calloc.free(containerRefPtr);

  print('app: DONE!');
}

bool updateImageInfo(
  Pointer<TW_IDENTITY> myInfoPtr,
  Pointer<TW_IDENTITY> dataSourcePtr,
  Pointer<TW_IMAGEINFO> imageInfoPtr,
) {
  var twrc = twainDsm.DSM_Entry(myInfoPtr, dataSourcePtr, DG_IMAGE, DAT_IMAGEINFO, MSG_GET, imageInfoPtr.cast());
  if (twrc != TWRC_SUCCESS) {
    var twcc = twainDsm.getConditionCodeString(dataSourcePtr);
    print('Error while trying to get the image information! $twcc');
    return false;
  }
  return true;
}

void saveToFile(Pointer<BITMAPINFOHEADER> infoHeaderPtr, String path) {
  var imageOffset = sizeOf<BITMAPINFOHEADER>() + sizeOf<RGBQUAD>() * infoHeaderPtr.ref.paletteSize!;
  print('imageOffset $imageOffset');

  if (infoHeaderPtr.ref.biSizeImage == 0) {
    throw 'TODO biSizeImage';
  }
  var contentSize = imageOffset + infoHeaderPtr.ref.biSizeImage;
  print('contentSize $contentSize');

  var fileHeaderPtr = calloc<BITMAPFILEHEADER>();
  fileHeaderPtr.ref.bfType = 0x4d42; // 'MB'
  fileHeaderPtr.ref.bfSize = sizeOf<BITMAPFILEHEADER>() + contentSize;
  fileHeaderPtr.ref.bfOffBits = sizeOf<BITMAPFILEHEADER>() + imageOffset;

  var file = File(path);
  file.writeAsBytesSync(fileHeaderPtr.cast<Uint8>().asTypedList(sizeOf<BITMAPFILEHEADER>()));
  file.writeAsBytesSync(infoHeaderPtr.cast<Uint8>().asTypedList(contentSize), mode: FileMode.append);
}

extension BitmapInfoHeader on BITMAPINFOHEADER {
  int? get paletteSize {
    switch (biBitCount) {
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