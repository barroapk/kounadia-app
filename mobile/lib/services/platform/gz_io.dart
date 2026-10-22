import 'dart:io';

List<int> gunzip(List<int> b) => gzip.decode(b);
