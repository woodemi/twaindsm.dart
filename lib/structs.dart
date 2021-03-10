import 'dart:convert';
import 'dart:ffi';

import 'twaindsm.dart';

extension TWIdentity on TW_IDENTITY {
  String getManufacturer() => Manufacturer.getDartString(34);

  void setManufacturer(String s) => Manufacturer.setDartString(s, 34);

  String getProductFamily() => ProductFamily.getDartString(34);

  void setProductFamily(String s) => ProductFamily.setDartString(s, 34);

  String getProductName() => ProductName.getDartString(34);

  void setProductName(String s) => ProductName.setDartString(s, 34);

 Map<String, Object> toMap() => {
    'Id': Id,
    'Version': Version.toMap(),
    'ProtocolMajor': ProtocolMajor,
    'ProtocolMinor': ProtocolMinor,
    'SupportedGroups': SupportedGroups,
    'Manufacturer': Manufacturer,
    'ProductFamily': ProductFamily,
    'ProductName': ProductName,
  };
}

extension TWVersion on TW_VERSION {
  String getInfo() => Info.getDartString(34);

  void setInfo(String s) => Info.setDartString(s, 34);

  Map<String, Object> toMap() => {
    'MajorNum': MajorNum,
    'MinorNum': MinorNum,
    'Country': Country,
    'Language': Language,
    'Info': Info.getDartString(34),
  };
}

extension TWEntrypoint on TW_ENTRYPOINT {
  Pointer<Void> Function(int) get memAllocate => DSM_MemAllocate.asFunction();

  void Function(Pointer<Void>) get memFree => DSM_MemFree.asFunction();

  Pointer<Void> Function(Pointer<Void>) get memLock => DSM_MemLock.asFunction();

  void Function(Pointer<Void>) get memUnlock => DSM_MemUnlock.asFunction();
}

// FIXME: https://github.com/dart-lang/sdk/issues/45508
extension TWEnumerationPointer on Pointer<TW_ENUMERATION> {
  int get itemListAddress => address + 14;
}

extension TWImageInfo on TW_IMAGEINFO {
  Map<String, Object> toMap() => {
      'XResolution': {
        'Whole': XResolution.Whole,
        'Frac': XResolution.Frac,
      },
      'YResolution': {
        'Whole': YResolution.Whole,
        'Frac': YResolution.Frac,
      },
      'ImageWidth': ImageWidth,
      'ImageLength': ImageLength,
      'SamplesPerPixel': SamplesPerPixel,
      'BitsPerSample': spreadBitsPerSample(),
      'BitsPerPixel': BitsPerPixel,
      'Planar': Planar,
      'PixelType': PixelType,
      'Compression': Compression,
    };

  Iterable<int> spreadBitsPerSample() sync* {
    for (var i = 0; i < 8; i++) {
      yield BitsPerSample[i];
    }
  }
}

extension CharArray on Array<Int8> {
  String getDartString(int maxLength) {
    var list = <int>[];
    for (var i = 0; i < maxLength; i++) {
      if (this[i] != 0) list.add(this[i]);
    }
    return utf8.decode(list);
  }

  void setDartString(String s, int maxLength) {
    var list = utf8.encode(s);
    for (var i = 0; i < maxLength; i++) {
      this[i] = i < list.length ? list[i] : 0;
    }
  }
}