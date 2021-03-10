import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:ffi/ffi.dart';

import 'twaindsm.dart';

abstract class _TWStruct<T extends NativeType> {
  late Pointer<Uint8> _pointer;

  _TWStruct() {
    _pointer = calloc<Uint8>(size);
  }

  void dispose() {
    calloc.free(_pointer);
  }

  int get size;

  Pointer<T> get pointer => _pointer.cast();

  Uint8List get _nativeList => _pointer.asTypedList(size);

  ByteData get _byteData => _nativeList.buffer.asByteData();

  String debugHex() => hex.encode(_nativeList);

  int _getUint8(int offset) => _byteData.getUint8(offset);

  void _setUint8(int offset, int i) => _byteData.setUint8(offset, i);

  int _getInt16(int offset) => _byteData.getInt16(offset, Endian.host);

  void _setInt16(int offset, int i) =>
      _byteData.setInt16(offset, i, Endian.host);
  
  int _getUint16(int offset) => _byteData.getUint16(offset, Endian.host);

  void _setUint16(int offset, int i) =>
      _byteData.setUint16(offset, i, Endian.host);

  int _getInt32(int offset) => _byteData.getInt32(offset, Endian.host);

  void _setInt32(int offset, int i) =>
      _byteData.setInt32(offset, i, Endian.host);

  int _getUint32(int offset) => _byteData.getUint32(offset, Endian.host);

  void _setUint32(int offset, int i) =>
      _byteData.setUint32(offset, i, Endian.host);

  String _getString(int offset, int maxLength) {
    var nativeString = _nativeList.sublist(offset, offset + 34);
    var strlen = nativeString.indexWhere((char) => char == 0);
    return utf8.decode(nativeString.sublist(0, strlen));
  }

  void _setString(int offset, String s, int maxLength) {
    _nativeList.setAll(offset, Uint8List(maxLength)); // zero-initialized
    _nativeList.setAll(offset, utf8.encode(s));
  }
}

// typedef struct {
//     #if defined(__APPLE__) /* cf: Mac version of TWAIN.h */
//         TW_MEMREF  Id;
//     #else
//         TW_UINT32  Id;
//     #endif
//     TW_VERSION 	   Version;
//     TW_UINT16  	   ProtocolMajor;
//     TW_UINT16  	   ProtocolMinor;
//     TW_UINT32  	   SupportedGroups;
//     TW_STR32   	   Manufacturer;
//     TW_STR32   	   ProductFamily;
//     TW_STR32   	   ProductName;
// } TW_IDENTITY, FAR * pTW_IDENTITY;
class TWIdentity extends _TWStruct<TW_IDENTITY> {
  // TODO https://github.com/dart-lang/sdk/issues/38158
  // sizeOf<TW_IDENTITY> = 160 != 4 + 42 + 2 + 2 + 4 + 34 + 34 + 34
  @override
  int get size => 4 + 42 + 2 + 2 + 4 + 34 + 34 + 34;

  /*----------------------------------------------------------------*/

  int get Id => _getUint32(0);

  set Id(int i) => _setUint32(0, i);

  /*----------------------------------------------------------------*/

  Pointer<TW_VERSION> get Version => Pointer.fromAddress(_pointer.address + 4);

  /*----------------------------------------------------------------*/

  static const _ProtocolMajorOffset = 4 + 42;

  int get ProtocolMajor => _getUint16(_ProtocolMajorOffset);

  set ProtocolMajor(int i) => _setUint16(_ProtocolMajorOffset, i);

  /*----------------------------------------------------------------*/

  static const _ProtocolMinorOffset = _ProtocolMajorOffset + 2;

  int get ProtocolMinor => _getUint16(_ProtocolMinorOffset);

  set ProtocolMinor(int i) => _setUint16(_ProtocolMinorOffset, i);

  /*----------------------------------------------------------------*/

  static const _SupportedGroupsOffset = _ProtocolMinorOffset + 2;

  int get SupportedGroups => _getUint32(_SupportedGroupsOffset);

  set SupportedGroups(int i) => _setUint32(_SupportedGroupsOffset, i);

  /*----------------------------------------------------------------*/

  static const _ManufacturerOffset = _SupportedGroupsOffset + 4;

  String get Manufacturer => _getString(_ManufacturerOffset, 34);

  set Manufacturer(String s) => _setString(_ManufacturerOffset, s, 34);

  /*----------------------------------------------------------------*/

  static const _ProductFamilyOffset = _ManufacturerOffset + 34;

  String get ProductFamily => _getString(_ProductFamilyOffset, 34);

  set ProductFamily(String s) => _setString(_ProductFamilyOffset, s, 34);

  /*----------------------------------------------------------------*/

  static const _ProductNameOffset = _ProductFamilyOffset + 34;

  String get ProductName => _getString(_ProductNameOffset, 34);

  set ProductName(String s) => _setString(_ProductNameOffset, s, 34);

  Map<String, Object> toMap() => {
    'Id': Id,
    'Version': Version.ref.toMap(),
    'ProtocolMajor': ProtocolMajor,
    'ProtocolMinor': ProtocolMinor,
    'SupportedGroups': SupportedGroups,
    'Manufacturer': Manufacturer,
    'ProductFamily': ProductFamily,
    'ProductName': ProductName,
  };

  @override
  String toString() {
    return toMap().toString();
  }
}

extension TWVersion on TW_VERSION {
  Map<String, dynamic> toMap() => {
    'MajorNum': MajorNum,
    'MinorNum': MinorNum,
    'Country': Country,
    'Language': Language,
    'Info': Info.getDartString(34),
  };

  String getInfo() => Info.getDartString(34);

  void setInfo(String s) => Info.setDartString(s, 34);
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