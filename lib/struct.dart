import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;
import 'package:twaindsm/twaindsm.dart';

abstract class _TWStruct<T extends Struct> {
  final Pointer<Uint8> _pointer;

  _TWStruct(int size) : _pointer = ffi.allocate<Uint8>(count: size);

  _TWStruct._fromAddress(int ptr) : _pointer = Pointer.fromAddress(ptr);

  void dispose() {
    ffi.free(_pointer);
  }

  int get size;

  Pointer<T> get pointer => _pointer.cast<T>();

  Uint8List get _nativeList => _pointer.asTypedList(size);

  ByteData get _byteData => _nativeList.buffer.asByteData();

  int _getUint16(int offset) => _byteData.getUint16(offset, Endian.host);

  void _setUint16(int offset, int i) => _byteData.setUint16(offset, i, Endian.host);

  int _getUint32(int offset) => _byteData.getUint32(offset, Endian.host);

  void _setUint32(int offset, int i) => _byteData.setUint32(offset, i, Endian.host);

  String _getString(int offset, int maxLength) {
    var nativeString = _nativeList.sublist(offset, offset + 34);
    var strlen = nativeString.indexWhere((char) => char == 0);
    return utf8.decode(nativeString.sublist(strlen));
  }

  void _setString(int offset, String s, int maxLength) {
    _nativeList.setAll(offset, Uint8List(maxLength)); // initially zero
    _nativeList.setAll(offset, utf8.encode(s));
  }
}

// struct TW_VERSION {
//    TW_UINT16  MajorNum;
//    TW_UINT16  MinorNum;
//    TW_UINT16  Language;
//    TW_UINT16  Country;
//    TW_STR32   Info;
// };
class TWVersion extends _TWStruct<TW_VERSION> {
  static const _size = 2 + 2 + 2 + 2 + 34;

  TWVersion._fromAddress(int ptr): super._fromAddress(ptr);

  @override
  void dispose() {
    throw 'Undisposable nested structure';
  }

  @override
  int get size => _size;

  int get MajorNum => _getUint16(0);

  set MajorNum(int i) => _setUint16(0, i);

  int get MinorNum => _getUint16(2);

  set MinorNum(int i) => _setUint16(2, i);

  int get Language => _getUint16(4);

  set Language(int i) => _setUint16(4, i);

  int get Country => _getUint16(6);

  set Country(int i) => _setUint16(6, i);

  static const _InfoOffset = 2 + 2 + 2 + 2;

  String get Info => _getString(_InfoOffset, 34);

  set Info(String s) => _setString(_InfoOffset, s, 34);
}

// struct TW_IDENTITY {
//     TW_UINT32  	   Id;
//     TW_VERSION 	   Version;
//     TW_UINT16  	   ProtocolMajor;
//     TW_UINT16  	   ProtocolMinor;
//     TW_UINT32  	   SupportedGroups;
//     TW_STR32   	   Manufacturer;
//     TW_STR32   	   ProductFamily;
//     TW_STR32   	   ProductName;
// };
class TWIdentity extends _TWStruct<TW_IDENTITY> {
  static const _size = 4 + TWVersion._size + 2 + 2 + 4 + 34 + 34 + 34;

  TWIdentity() : super(_size);

  @override
  int get size => _size;

  /*----------------------------------------------------------------*/

  int get Id => _getUint32(0);

  set Id(int i) => _setUint32(0, i);

  /*----------------------------------------------------------------*/

  TWVersion get Version => TWVersion._fromAddress(_pointer.address + 4);

  /*----------------------------------------------------------------*/

  static const _ProtocolMajorOffset = 4 + TWVersion._size;

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
}
