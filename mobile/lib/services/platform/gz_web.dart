import 'package:archive/archive.dart';

List<int> gunzip(List<int> b) => GZipDecoder().decodeBytes(b);
