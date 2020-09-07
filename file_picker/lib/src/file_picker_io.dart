import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'file_picker_result.dart';

const MethodChannel _channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
const EventChannel _eventChannel = EventChannel('miguelruivo.flutter.plugins.filepickerevent');

/// An implementation of [FilePicker] that uses method channels.
class FilePickerIO extends FilePicker {
  static const String _tag = 'MethodChannelFilePicker';
  static StreamSubscription _eventSubscription;

  @override
  Future<FilePickerResult> pickFiles({
    FileType type = FileType.any,
    List<String> allowedExtensions,
    Function(FilePickerStatus) onFileLoading,
    bool allowCompression,
    bool allowMultiple = false,
  }) =>
      _getPath(type, allowMultiple, allowCompression, allowedExtensions, onFileLoading);

  @override
  Future<bool> clearTemporaryFiles() async => _channel.invokeMethod<bool>('clear');

  @override
  Future<PlatformFile> getDirectoryPath() async {
    try {
      String result = await _channel.invokeMethod('dir', {});
      if (result != null) {
        return PlatformFile(path: result, isDirectory: true);
      }
    } on PlatformException catch (ex) {
      if (ex.code == "unknown_path") {
        print(
            '[$_tag] Could not resolve directory path. Maybe it\'s a protected one or unsupported (such as Downloads folder). If you are on Android, make sure that you are on SDK 21 or above.');
      }
    }
    return null;
  }

  Future<FilePickerResult> _getPath(
    FileType fileType,
    bool allowMultipleSelection,
    bool allowCompression,
    List<String> allowedExtensions,
    Function(FilePickerStatus) onFileLoading,
  ) async {
    final String type = describeEnum(fileType);
    if (type != 'custom' && (allowedExtensions?.isNotEmpty ?? false)) {
      throw Exception('If you are using a custom extension filter, please use the FileType.custom instead.');
    }
    try {
      _eventSubscription?.cancel();
      if (onFileLoading != null) {
        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
              (data) => onFileLoading((data as bool) ? FilePickerStatus.picking : FilePickerStatus.done),
              onError: (error) => throw Exception(error),
            );
      }

      final List<String> result = await _channel.invokeListMethod(type, {
        'allowMultipleSelection': allowMultipleSelection,
        'allowedExtensions': allowedExtensions,
        'allowCompression': allowCompression,
      });

      if (result == null) {
        return null;
      }

      return FilePickerResult(result.map((file) => PlatformFile(name: file.split('/').last, path: file)).toList());
    } on PlatformException catch (e) {
      print('[$_tag] Platform exception: $e');
      rethrow;
    } catch (e) {
      print('[$_tag] Unsupported operation. Method not found. The exception thrown was: $e');
      rethrow;
    }
  }
}
