import '../../domain/repositories/on_device_llm_repository.dart';
import '../datasources/ai/on_device_llm_datasource.dart';

class OnDeviceLlmRepositoryImpl implements OnDeviceLlmRepository {
  OnDeviceLlmRepositoryImpl(this._datasource);

  final OnDeviceLlmDatasource _datasource;

  @override
  Future<bool> isModelReady() => _datasource.isModelReady();

  @override
  Future<void> installModel({void Function(double progress)? onProgress}) {
    return _datasource.installModel(onProgress: onProgress);
  }

  @override
  Future<void> uninstallModel() => _datasource.uninstallModel();

  @override
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  }) {
    return _datasource.complete(
      systemInstruction: systemInstruction,
      userMessage: userMessage,
      maxOutputTokens: maxOutputTokens,
    );
  }
}
