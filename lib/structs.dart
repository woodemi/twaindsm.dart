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