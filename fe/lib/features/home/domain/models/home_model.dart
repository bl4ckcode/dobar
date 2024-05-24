import 'package:json_annotation/json_annotation.dart';

/*part 'home_model.g.dart';*/

@JsonSerializable(fieldRename: FieldRename.snake)
class HomeModel {
  List<String> restaurants;
  String? title;

  HomeModel({required this.restaurants, this.title});

  /*factory HomeModel.fromJson(json) => _$HomeModelFromJson(json);

  toJson() => _$HomeModelToJson(this);

  static List<HomeModel> fromJsonList(List? json) {
    return json?.map((e) => HomeModel.fromJson(e)).toList() ?? [];
  }*/
}

