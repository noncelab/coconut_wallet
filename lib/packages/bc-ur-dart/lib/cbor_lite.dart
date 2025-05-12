import 'dart:typed_data';

enum Flag {
  none,
  requireMinimalEncoding,
}

class CBORTag {
  static const int majorUnsignedInteger = 0;
  static const int majorNegativeInteger = 1 << 5;
  static const int majorByteString = 2 << 5;
  static const int majorTextString = 3 << 5;
  static const int majorArray = 4 << 5;
  static const int majorMap = 5 << 5;
  static const int majorSemantic = 6 << 5;
  static const int majorFloatingPoint = 7 << 5;
  static const int majorSimple = 7 << 5;
  static const int majorMask = 0xe0;

  static const int minorLength1 = 24;
  static const int minorLength2 = 25;
  static const int minorLength4 = 26;
  static const int minorLength8 = 27;

  static const int minorFalse = 20;
  static const int minorTrue = 21;
  static const int minorNull = 22;
  static const int minorUndefined = 23;
  static const int minorHalfFloat = 25;
  static const int minorSingleFloat = 26;
  static const int minorDoubleFloat = 27;

  static const int minorDateTime = 0;
  static const int minorEpochDateTime = 1;
  static const int minorPositiveBignum = 2;
  static const int minorNegativeBignum = 3;
  static const int minorDecimalFraction = 4;
  static const int minorBigFloat = 5;
  static const int minorConvertBase64Url = 21;
  static const int minorConvertBase64 = 22;
  static const int minorConvertBase16 = 23;
  static const int minorCborEncodedData = 24;
  static const int minorUri = 32;
  static const int minorBase64Url = 33;
  static const int minorBase64 = 34;
  static const int minorRegex = 35;
  static const int minorMimeMessage = 36;
  static const int minorSelfDescribeCbor = 55799;
  static const int minorMask = 0x1f;
  static const int undefined = majorSemantic + minorUndefined;
}

int getByteLength(int value) {
  if (value < 24) {
    return 0;
  }
  return (value.bitLength + 7) ~/ 8;
}

class CBOREncoder {
  final BytesBuilder _buffer = BytesBuilder();

  Uint8List getBytes() {
    return _buffer.toBytes();
  }

  int encodeTagAndAdditional(int tag, int additional) {
    _buffer.addByte(tag + additional);
    return 1;
  }

  int encodeTagAndValue(int tag, int value) {
    int length = getByteLength(value);

    if (length >= 5 && length <= 8) {
      encodeTagAndAdditional(tag, CBORTag.minorLength8);
      _buffer.add(Uint8List(8)..buffer.asByteData().setUint64(0, value, Endian.big));
    } else if (length == 3 || length == 4) {
      encodeTagAndAdditional(tag, CBORTag.minorLength4);
      _buffer.add(Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.big));
    } else if (length == 2) {
      encodeTagAndAdditional(tag, CBORTag.minorLength2);
      _buffer.add(Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.big));
    } else if (length == 1) {
      encodeTagAndAdditional(tag, CBORTag.minorLength1);
      _buffer.addByte(value);
    } else if (length == 0) {
      encodeTagAndAdditional(tag, value);
    } else {
      throw Exception("Unsupported byte length of $length for value in encodeTagAndValue()");
    }

    return 1 + length;
  }

  int encodeUnsigned(int value) {
    return encodeTagAndValue(CBORTag.majorUnsignedInteger, value);
  }

  int encodeNegative(int value) {
    return encodeTagAndValue(CBORTag.majorNegativeInteger, value);
  }

  int encodeInteger(int value) {
    return value >= 0 ? encodeUnsigned(value) : encodeNegative(-value - 1);
  }

  int encodeBool(bool value) {
    return encodeTagAndValue(CBORTag.majorSimple, value ? CBORTag.minorTrue : CBORTag.minorFalse);
  }

  int encodeBytes(Uint8List value) {
    int length = encodeTagAndValue(CBORTag.majorByteString, value.length);
    _buffer.add(value);
    return length + value.length;
  }

  int encodeEncodedBytesPrefix(int value) {
    return encodeTagAndValue(CBORTag.majorSemantic, CBORTag.minorCborEncodedData);
  }

  int encodeEncodedBytes(Uint8List value) {
    int length = encodeTagAndValue(CBORTag.majorSemantic, CBORTag.minorCborEncodedData);
    return length + encodeBytes(value);
  }

  int encodeText(String value) {
    Uint8List utf8Bytes = Uint8List.fromList(value.codeUnits);
    int length = encodeTagAndValue(CBORTag.majorTextString, utf8Bytes.length);
    _buffer.add(utf8Bytes);
    return length + utf8Bytes.length;
  }

  int encodeArraySize(int value) {
    return encodeTagAndValue(CBORTag.majorArray, value);
  }

  int encodeMapSize(int value) {
    return encodeTagAndValue(CBORTag.majorMap, value);
  }
}

class CBORDecoder {
  final Uint8List _buffer;
  int _position = 0;

  CBORDecoder(this._buffer);

  (int, int, int) decodeTagAndAdditional([Flag flag = Flag.none]) {
    if (_position == _buffer.length) {
      throw Exception("Not enough input");
    }
    int octet = _buffer[_position++];
    int tag = octet & CBORTag.majorMask;
    int additional = octet & CBORTag.minorMask;
    return (tag, additional, 1);
  }

  (int, int, int) decodeTagAndValue([Flag flag = Flag.none]) {
    if (_position == _buffer.length) {
      throw Exception("Not enough input");
    }

    var (tag, additional, length) = decodeTagAndAdditional(flag);
    if (additional < CBORTag.minorLength1) {
      return (tag, additional, length);
    }

    int value = 0;
    int bytesToRead = 0;

    switch (additional) {
      case CBORTag.minorLength8:
        bytesToRead = 8;
        break;
      case CBORTag.minorLength4:
        bytesToRead = 4;
        break;
      case CBORTag.minorLength2:
        bytesToRead = 2;
        break;
      case CBORTag.minorLength1:
        bytesToRead = 1;
        break;
      default:
        throw Exception("Bad additional value");
    }

    if (_buffer.length - _position < bytesToRead) {
      throw Exception("Not enough input");
    }

    ByteData byteData = ByteData.sublistView(_buffer, _position, _position + bytesToRead);
    _position += bytesToRead;

    switch (bytesToRead) {
      case 8:
        value = byteData.getUint64(0, Endian.big);
        break;
      case 4:
        value = byteData.getUint32(0, Endian.big);
        break;
      case 2:
        value = byteData.getUint16(0, Endian.big);
        break;
      case 1:
        value = byteData.getUint8(0);
        break;
    }

    if (flag == Flag.requireMinimalEncoding && value < 24) {
      throw Exception("Encoding not minimal");
    }

    return (tag, value, _position);
  }

  (int, int) decodeUnsigned([Flag flag = Flag.none]) {
    var (tag, value, length) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorUnsignedInteger) {
      throw Exception("Expected majorUnsignedInteger, but found $tag");
    }
    return (value, length);
  }

  (int, int) decodeNegative([Flag flag = Flag.none]) {
    var (tag, value, length) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorNegativeInteger) {
      throw Exception("Expected majorNegativeInteger, but found $tag");
    }
    return (value, length);
  }

  (int, int) decodeInteger([Flag flag = Flag.none]) {
    var (tag, value, length) = decodeTagAndValue(flag);
    if (tag == CBORTag.majorUnsignedInteger) {
      return (value, length);
    } else if (tag == CBORTag.majorNegativeInteger) {
      return (-1 - value, length);
    }
    throw Exception("Expected integer, but found $tag");
  }

  (bool, int) decodeBool([Flag flag = Flag.none]) {
    var (tag, value, length) = decodeTagAndValue(flag);
    if (tag == CBORTag.majorSimple) {
      if (value == CBORTag.minorTrue) {
        return (true, length);
      } else if (value == CBORTag.minorFalse) {
        return (false, length);
      }
    }
    throw Exception("Not a Boolean");
  }

  (Uint8List, int) decodeBytes([Flag flag = Flag.none]) {
    var (tag, byteLength, sizeLength) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorByteString) {
      throw Exception("Not a byteString");
    }

    if (_buffer.length - _position < byteLength) {
      throw Exception("Not enough input");
    }

    Uint8List value = Uint8List.sublistView(_buffer, _position, _position + byteLength);
    _position += byteLength;
    return (value, sizeLength + byteLength);
  }

  (int, int, int) decodeEncodedBytesPrefix([Flag flag = Flag.none]) {
    var (tag, value, length1) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorSemantic || value != CBORTag.minorCborEncodedData) {
      throw Exception("Not CBOR Encoded Data");
    }

    var (tag2, value2, length2) = decodeTagAndValue(flag);
    if (tag2 != CBORTag.majorByteString) {
      throw Exception("Not byteString");
    }

    return (tag2, value2, length1 + length2);
  }

  (Uint8List, int) decodeEncodedBytes([Flag flag = Flag.none]) {
    var (tag, minorTag, tagLength) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorSemantic || minorTag != CBORTag.minorCborEncodedData) {
      throw Exception("Not CBOR Encoded Data");
    }

    var (value, length) = decodeBytes(flag);
    return (value, tagLength + length);
  }

  (String, int) decodeText([Flag flag = Flag.none]) {
    var (tag, byteLength, sizeLength) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorTextString) {
      throw Exception("Not a textString");
    }

    if (_buffer.length - _position < byteLength) {
      throw Exception("Not enough input");
    }

    Uint8List utf8Bytes = Uint8List.sublistView(_buffer, _position, _position + byteLength);
    _position += byteLength;
    String value = String.fromCharCodes(utf8Bytes);
    return (value, sizeLength + byteLength);
  }

  (int, int) decodeArraySize([Flag flag = Flag.none]) {
    var (tag, value, length) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorArray) {
      throw Exception("Expected majorArray, but found $tag");
    }
    return (value, length);
  }

  (int, int) decodeMapSize([Flag flag = Flag.none]) {
    var (tag, value, length) = decodeTagAndValue(flag);
    if (tag != CBORTag.majorMap) {
      throw Exception("Expected majorMap, but found $tag");
    }
    return (value, length);
  }
}
