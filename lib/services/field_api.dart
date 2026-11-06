import '../models/field_model.dart';
import 'local_app_data_service.dart';

class FieldService {
  Future<List<FieldModel>> getFields() async {
    return LocalAppDataService.fields;
  }
}
