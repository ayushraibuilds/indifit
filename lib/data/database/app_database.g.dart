// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoodItemsTable extends FoodItems
    with TableInfo<$FoodItemsTable, FoodItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameHindiMeta =
      const VerificationMeta('nameHindi');
  @override
  late final GeneratedColumn<String> nameHindi = GeneratedColumn<String>(
      'name_hindi', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _caloriesMeta =
      const VerificationMeta('calories');
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
      'calories', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _proteinGMeta =
      const VerificationMeta('proteinG');
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
      'protein_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _carbsGMeta = const VerificationMeta('carbsG');
  @override
  late final GeneratedColumn<double> carbsG = GeneratedColumn<double>(
      'carbs_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
      'fat_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fiberGMeta = const VerificationMeta('fiberG');
  @override
  late final GeneratedColumn<double> fiberG = GeneratedColumn<double>(
      'fiber_g', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _servingSizeMeta =
      const VerificationMeta('servingSize');
  @override
  late final GeneratedColumn<double> servingSize = GeneratedColumn<double>(
      'serving_size', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _servingUnitMeta =
      const VerificationMeta('servingUnit');
  @override
  late final GeneratedColumn<String> servingUnit = GeneratedColumn<String>(
      'serving_unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isCustomMeta =
      const VerificationMeta('isCustom');
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
      'is_custom', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_custom" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _regionPackMeta =
      const VerificationMeta('regionPack');
  @override
  late final GeneratedColumn<String> regionPack = GeneratedColumn<String>(
      'region_pack', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        nameHindi,
        calories,
        proteinG,
        carbsG,
        fatG,
        fiberG,
        servingSize,
        servingUnit,
        category,
        isCustom,
        brand,
        regionPack
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_items';
  @override
  VerificationContext validateIntegrity(Insertable<FoodItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_hindi')) {
      context.handle(_nameHindiMeta,
          nameHindi.isAcceptableOrUnknown(data['name_hindi']!, _nameHindiMeta));
    }
    if (data.containsKey('calories')) {
      context.handle(_caloriesMeta,
          calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta));
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(_proteinGMeta,
          proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta));
    } else if (isInserting) {
      context.missing(_proteinGMeta);
    }
    if (data.containsKey('carbs_g')) {
      context.handle(_carbsGMeta,
          carbsG.isAcceptableOrUnknown(data['carbs_g']!, _carbsGMeta));
    } else if (isInserting) {
      context.missing(_carbsGMeta);
    }
    if (data.containsKey('fat_g')) {
      context.handle(
          _fatGMeta, fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta));
    } else if (isInserting) {
      context.missing(_fatGMeta);
    }
    if (data.containsKey('fiber_g')) {
      context.handle(_fiberGMeta,
          fiberG.isAcceptableOrUnknown(data['fiber_g']!, _fiberGMeta));
    }
    if (data.containsKey('serving_size')) {
      context.handle(
          _servingSizeMeta,
          servingSize.isAcceptableOrUnknown(
              data['serving_size']!, _servingSizeMeta));
    } else if (isInserting) {
      context.missing(_servingSizeMeta);
    }
    if (data.containsKey('serving_unit')) {
      context.handle(
          _servingUnitMeta,
          servingUnit.isAcceptableOrUnknown(
              data['serving_unit']!, _servingUnitMeta));
    } else if (isInserting) {
      context.missing(_servingUnitMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('is_custom')) {
      context.handle(_isCustomMeta,
          isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    }
    if (data.containsKey('region_pack')) {
      context.handle(
          _regionPackMeta,
          regionPack.isAcceptableOrUnknown(
              data['region_pack']!, _regionPackMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      nameHindi: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_hindi']),
      calories: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calories'])!,
      proteinG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}protein_g'])!,
      carbsG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_g'])!,
      fatG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fat_g'])!,
      fiberG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fiber_g']),
      servingSize: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}serving_size'])!,
      servingUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serving_unit'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      isCustom: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_custom'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand']),
      regionPack: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}region_pack']),
    );
  }

  @override
  $FoodItemsTable createAlias(String alias) {
    return $FoodItemsTable(attachedDatabase, alias);
  }
}

class FoodItem extends DataClass implements Insertable<FoodItem> {
  final int id;
  final String name;
  final String? nameHindi;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? fiberG;
  final double servingSize;
  final String servingUnit;
  final String category;
  final bool isCustom;
  final String? brand;
  final String? regionPack;
  const FoodItem(
      {required this.id,
      required this.name,
      this.nameHindi,
      required this.calories,
      required this.proteinG,
      required this.carbsG,
      required this.fatG,
      this.fiberG,
      required this.servingSize,
      required this.servingUnit,
      required this.category,
      required this.isCustom,
      this.brand,
      this.regionPack});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nameHindi != null) {
      map['name_hindi'] = Variable<String>(nameHindi);
    }
    map['calories'] = Variable<int>(calories);
    map['protein_g'] = Variable<double>(proteinG);
    map['carbs_g'] = Variable<double>(carbsG);
    map['fat_g'] = Variable<double>(fatG);
    if (!nullToAbsent || fiberG != null) {
      map['fiber_g'] = Variable<double>(fiberG);
    }
    map['serving_size'] = Variable<double>(servingSize);
    map['serving_unit'] = Variable<String>(servingUnit);
    map['category'] = Variable<String>(category);
    map['is_custom'] = Variable<bool>(isCustom);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || regionPack != null) {
      map['region_pack'] = Variable<String>(regionPack);
    }
    return map;
  }

  FoodItemsCompanion toCompanion(bool nullToAbsent) {
    return FoodItemsCompanion(
      id: Value(id),
      name: Value(name),
      nameHindi: nameHindi == null && nullToAbsent
          ? const Value.absent()
          : Value(nameHindi),
      calories: Value(calories),
      proteinG: Value(proteinG),
      carbsG: Value(carbsG),
      fatG: Value(fatG),
      fiberG:
          fiberG == null && nullToAbsent ? const Value.absent() : Value(fiberG),
      servingSize: Value(servingSize),
      servingUnit: Value(servingUnit),
      category: Value(category),
      isCustom: Value(isCustom),
      brand:
          brand == null && nullToAbsent ? const Value.absent() : Value(brand),
      regionPack: regionPack == null && nullToAbsent
          ? const Value.absent()
          : Value(regionPack),
    );
  }

  factory FoodItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodItem(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameHindi: serializer.fromJson<String?>(json['nameHindi']),
      calories: serializer.fromJson<int>(json['calories']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      carbsG: serializer.fromJson<double>(json['carbsG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      fiberG: serializer.fromJson<double?>(json['fiberG']),
      servingSize: serializer.fromJson<double>(json['servingSize']),
      servingUnit: serializer.fromJson<String>(json['servingUnit']),
      category: serializer.fromJson<String>(json['category']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      brand: serializer.fromJson<String?>(json['brand']),
      regionPack: serializer.fromJson<String?>(json['regionPack']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'nameHindi': serializer.toJson<String?>(nameHindi),
      'calories': serializer.toJson<int>(calories),
      'proteinG': serializer.toJson<double>(proteinG),
      'carbsG': serializer.toJson<double>(carbsG),
      'fatG': serializer.toJson<double>(fatG),
      'fiberG': serializer.toJson<double?>(fiberG),
      'servingSize': serializer.toJson<double>(servingSize),
      'servingUnit': serializer.toJson<String>(servingUnit),
      'category': serializer.toJson<String>(category),
      'isCustom': serializer.toJson<bool>(isCustom),
      'brand': serializer.toJson<String?>(brand),
      'regionPack': serializer.toJson<String?>(regionPack),
    };
  }

  FoodItem copyWith(
          {int? id,
          String? name,
          Value<String?> nameHindi = const Value.absent(),
          int? calories,
          double? proteinG,
          double? carbsG,
          double? fatG,
          Value<double?> fiberG = const Value.absent(),
          double? servingSize,
          String? servingUnit,
          String? category,
          bool? isCustom,
          Value<String?> brand = const Value.absent(),
          Value<String?> regionPack = const Value.absent()}) =>
      FoodItem(
        id: id ?? this.id,
        name: name ?? this.name,
        nameHindi: nameHindi.present ? nameHindi.value : this.nameHindi,
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        fiberG: fiberG.present ? fiberG.value : this.fiberG,
        servingSize: servingSize ?? this.servingSize,
        servingUnit: servingUnit ?? this.servingUnit,
        category: category ?? this.category,
        isCustom: isCustom ?? this.isCustom,
        brand: brand.present ? brand.value : this.brand,
        regionPack: regionPack.present ? regionPack.value : this.regionPack,
      );
  FoodItem copyWithCompanion(FoodItemsCompanion data) {
    return FoodItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameHindi: data.nameHindi.present ? data.nameHindi.value : this.nameHindi,
      calories: data.calories.present ? data.calories.value : this.calories,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      carbsG: data.carbsG.present ? data.carbsG.value : this.carbsG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      fiberG: data.fiberG.present ? data.fiberG.value : this.fiberG,
      servingSize:
          data.servingSize.present ? data.servingSize.value : this.servingSize,
      servingUnit:
          data.servingUnit.present ? data.servingUnit.value : this.servingUnit,
      category: data.category.present ? data.category.value : this.category,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      brand: data.brand.present ? data.brand.value : this.brand,
      regionPack:
          data.regionPack.present ? data.regionPack.value : this.regionPack,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameHindi: $nameHindi, ')
          ..write('calories: $calories, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('fatG: $fatG, ')
          ..write('fiberG: $fiberG, ')
          ..write('servingSize: $servingSize, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('category: $category, ')
          ..write('isCustom: $isCustom, ')
          ..write('brand: $brand, ')
          ..write('regionPack: $regionPack')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      nameHindi,
      calories,
      proteinG,
      carbsG,
      fatG,
      fiberG,
      servingSize,
      servingUnit,
      category,
      isCustom,
      brand,
      regionPack);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameHindi == this.nameHindi &&
          other.calories == this.calories &&
          other.proteinG == this.proteinG &&
          other.carbsG == this.carbsG &&
          other.fatG == this.fatG &&
          other.fiberG == this.fiberG &&
          other.servingSize == this.servingSize &&
          other.servingUnit == this.servingUnit &&
          other.category == this.category &&
          other.isCustom == this.isCustom &&
          other.brand == this.brand &&
          other.regionPack == this.regionPack);
}

class FoodItemsCompanion extends UpdateCompanion<FoodItem> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> nameHindi;
  final Value<int> calories;
  final Value<double> proteinG;
  final Value<double> carbsG;
  final Value<double> fatG;
  final Value<double?> fiberG;
  final Value<double> servingSize;
  final Value<String> servingUnit;
  final Value<String> category;
  final Value<bool> isCustom;
  final Value<String?> brand;
  final Value<String?> regionPack;
  const FoodItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameHindi = const Value.absent(),
    this.calories = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.carbsG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.fiberG = const Value.absent(),
    this.servingSize = const Value.absent(),
    this.servingUnit = const Value.absent(),
    this.category = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.brand = const Value.absent(),
    this.regionPack = const Value.absent(),
  });
  FoodItemsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.nameHindi = const Value.absent(),
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    this.fiberG = const Value.absent(),
    required double servingSize,
    required String servingUnit,
    required String category,
    this.isCustom = const Value.absent(),
    this.brand = const Value.absent(),
    this.regionPack = const Value.absent(),
  })  : name = Value(name),
        calories = Value(calories),
        proteinG = Value(proteinG),
        carbsG = Value(carbsG),
        fatG = Value(fatG),
        servingSize = Value(servingSize),
        servingUnit = Value(servingUnit),
        category = Value(category);
  static Insertable<FoodItem> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? nameHindi,
    Expression<int>? calories,
    Expression<double>? proteinG,
    Expression<double>? carbsG,
    Expression<double>? fatG,
    Expression<double>? fiberG,
    Expression<double>? servingSize,
    Expression<String>? servingUnit,
    Expression<String>? category,
    Expression<bool>? isCustom,
    Expression<String>? brand,
    Expression<String>? regionPack,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameHindi != null) 'name_hindi': nameHindi,
      if (calories != null) 'calories': calories,
      if (proteinG != null) 'protein_g': proteinG,
      if (carbsG != null) 'carbs_g': carbsG,
      if (fatG != null) 'fat_g': fatG,
      if (fiberG != null) 'fiber_g': fiberG,
      if (servingSize != null) 'serving_size': servingSize,
      if (servingUnit != null) 'serving_unit': servingUnit,
      if (category != null) 'category': category,
      if (isCustom != null) 'is_custom': isCustom,
      if (brand != null) 'brand': brand,
      if (regionPack != null) 'region_pack': regionPack,
    });
  }

  FoodItemsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? nameHindi,
      Value<int>? calories,
      Value<double>? proteinG,
      Value<double>? carbsG,
      Value<double>? fatG,
      Value<double?>? fiberG,
      Value<double>? servingSize,
      Value<String>? servingUnit,
      Value<String>? category,
      Value<bool>? isCustom,
      Value<String?>? brand,
      Value<String?>? regionPack}) {
    return FoodItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameHindi: nameHindi ?? this.nameHindi,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      category: category ?? this.category,
      isCustom: isCustom ?? this.isCustom,
      brand: brand ?? this.brand,
      regionPack: regionPack ?? this.regionPack,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameHindi.present) {
      map['name_hindi'] = Variable<String>(nameHindi.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (carbsG.present) {
      map['carbs_g'] = Variable<double>(carbsG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (fiberG.present) {
      map['fiber_g'] = Variable<double>(fiberG.value);
    }
    if (servingSize.present) {
      map['serving_size'] = Variable<double>(servingSize.value);
    }
    if (servingUnit.present) {
      map['serving_unit'] = Variable<String>(servingUnit.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (regionPack.present) {
      map['region_pack'] = Variable<String>(regionPack.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameHindi: $nameHindi, ')
          ..write('calories: $calories, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('fatG: $fatG, ')
          ..write('fiberG: $fiberG, ')
          ..write('servingSize: $servingSize, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('category: $category, ')
          ..write('isCustom: $isCustom, ')
          ..write('brand: $brand, ')
          ..write('regionPack: $regionPack')
          ..write(')'))
        .toString();
  }
}

class $FoodLogsTable extends FoodLogs with TableInfo<$FoodLogsTable, FoodLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _foodItemIdMeta =
      const VerificationMeta('foodItemId');
  @override
  late final GeneratedColumn<int> foodItemId = GeneratedColumn<int>(
      'food_item_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES food_items (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _caloriesMeta =
      const VerificationMeta('calories');
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
      'calories', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _proteinGMeta =
      const VerificationMeta('proteinG');
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
      'protein_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _carbsGMeta = const VerificationMeta('carbsG');
  @override
  late final GeneratedColumn<double> carbsG = GeneratedColumn<double>(
      'carbs_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
      'fat_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _servingLoggedMeta =
      const VerificationMeta('servingLogged');
  @override
  late final GeneratedColumn<double> servingLogged = GeneratedColumn<double>(
      'serving_logged', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _servingUnitMeta =
      const VerificationMeta('servingUnit');
  @override
  late final GeneratedColumn<String> servingUnit = GeneratedColumn<String>(
      'serving_unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mealTypeMeta =
      const VerificationMeta('mealType');
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
      'meal_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _loggedAtMeta =
      const VerificationMeta('loggedAt');
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
      'logged_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _mealGroupIdMeta =
      const VerificationMeta('mealGroupId');
  @override
  late final GeneratedColumn<String> mealGroupId = GeneratedColumn<String>(
      'meal_group_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        foodItemId,
        name,
        calories,
        proteinG,
        carbsG,
        fatG,
        servingLogged,
        servingUnit,
        mealType,
        loggedAt,
        isSynced,
        mealGroupId,
        uuid
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_logs';
  @override
  VerificationContext validateIntegrity(Insertable<FoodLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('food_item_id')) {
      context.handle(
          _foodItemIdMeta,
          foodItemId.isAcceptableOrUnknown(
              data['food_item_id']!, _foodItemIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(_caloriesMeta,
          calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta));
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(_proteinGMeta,
          proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta));
    } else if (isInserting) {
      context.missing(_proteinGMeta);
    }
    if (data.containsKey('carbs_g')) {
      context.handle(_carbsGMeta,
          carbsG.isAcceptableOrUnknown(data['carbs_g']!, _carbsGMeta));
    } else if (isInserting) {
      context.missing(_carbsGMeta);
    }
    if (data.containsKey('fat_g')) {
      context.handle(
          _fatGMeta, fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta));
    } else if (isInserting) {
      context.missing(_fatGMeta);
    }
    if (data.containsKey('serving_logged')) {
      context.handle(
          _servingLoggedMeta,
          servingLogged.isAcceptableOrUnknown(
              data['serving_logged']!, _servingLoggedMeta));
    } else if (isInserting) {
      context.missing(_servingLoggedMeta);
    }
    if (data.containsKey('serving_unit')) {
      context.handle(
          _servingUnitMeta,
          servingUnit.isAcceptableOrUnknown(
              data['serving_unit']!, _servingUnitMeta));
    } else if (isInserting) {
      context.missing(_servingUnitMeta);
    }
    if (data.containsKey('meal_type')) {
      context.handle(_mealTypeMeta,
          mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta));
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(_loggedAtMeta,
          loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    if (data.containsKey('meal_group_id')) {
      context.handle(
          _mealGroupIdMeta,
          mealGroupId.isAcceptableOrUnknown(
              data['meal_group_id']!, _mealGroupIdMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      foodItemId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}food_item_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      calories: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calories'])!,
      proteinG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}protein_g'])!,
      carbsG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_g'])!,
      fatG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fat_g'])!,
      servingLogged: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}serving_logged'])!,
      servingUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serving_unit'])!,
      mealType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meal_type'])!,
      loggedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}logged_at'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
      mealGroupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meal_group_id']),
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid']),
    );
  }

  @override
  $FoodLogsTable createAlias(String alias) {
    return $FoodLogsTable(attachedDatabase, alias);
  }
}

class FoodLog extends DataClass implements Insertable<FoodLog> {
  final int id;
  final int? foodItemId;
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingLogged;
  final String servingUnit;
  final String mealType;
  final DateTime loggedAt;
  final bool isSynced;
  final String? mealGroupId;
  final String? uuid;
  const FoodLog(
      {required this.id,
      this.foodItemId,
      required this.name,
      required this.calories,
      required this.proteinG,
      required this.carbsG,
      required this.fatG,
      required this.servingLogged,
      required this.servingUnit,
      required this.mealType,
      required this.loggedAt,
      required this.isSynced,
      this.mealGroupId,
      this.uuid});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || foodItemId != null) {
      map['food_item_id'] = Variable<int>(foodItemId);
    }
    map['name'] = Variable<String>(name);
    map['calories'] = Variable<int>(calories);
    map['protein_g'] = Variable<double>(proteinG);
    map['carbs_g'] = Variable<double>(carbsG);
    map['fat_g'] = Variable<double>(fatG);
    map['serving_logged'] = Variable<double>(servingLogged);
    map['serving_unit'] = Variable<String>(servingUnit);
    map['meal_type'] = Variable<String>(mealType);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || mealGroupId != null) {
      map['meal_group_id'] = Variable<String>(mealGroupId);
    }
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    return map;
  }

  FoodLogsCompanion toCompanion(bool nullToAbsent) {
    return FoodLogsCompanion(
      id: Value(id),
      foodItemId: foodItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(foodItemId),
      name: Value(name),
      calories: Value(calories),
      proteinG: Value(proteinG),
      carbsG: Value(carbsG),
      fatG: Value(fatG),
      servingLogged: Value(servingLogged),
      servingUnit: Value(servingUnit),
      mealType: Value(mealType),
      loggedAt: Value(loggedAt),
      isSynced: Value(isSynced),
      mealGroupId: mealGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(mealGroupId),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
    );
  }

  factory FoodLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodLog(
      id: serializer.fromJson<int>(json['id']),
      foodItemId: serializer.fromJson<int?>(json['foodItemId']),
      name: serializer.fromJson<String>(json['name']),
      calories: serializer.fromJson<int>(json['calories']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      carbsG: serializer.fromJson<double>(json['carbsG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      servingLogged: serializer.fromJson<double>(json['servingLogged']),
      servingUnit: serializer.fromJson<String>(json['servingUnit']),
      mealType: serializer.fromJson<String>(json['mealType']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      mealGroupId: serializer.fromJson<String?>(json['mealGroupId']),
      uuid: serializer.fromJson<String?>(json['uuid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'foodItemId': serializer.toJson<int?>(foodItemId),
      'name': serializer.toJson<String>(name),
      'calories': serializer.toJson<int>(calories),
      'proteinG': serializer.toJson<double>(proteinG),
      'carbsG': serializer.toJson<double>(carbsG),
      'fatG': serializer.toJson<double>(fatG),
      'servingLogged': serializer.toJson<double>(servingLogged),
      'servingUnit': serializer.toJson<String>(servingUnit),
      'mealType': serializer.toJson<String>(mealType),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
      'mealGroupId': serializer.toJson<String?>(mealGroupId),
      'uuid': serializer.toJson<String?>(uuid),
    };
  }

  FoodLog copyWith(
          {int? id,
          Value<int?> foodItemId = const Value.absent(),
          String? name,
          int? calories,
          double? proteinG,
          double? carbsG,
          double? fatG,
          double? servingLogged,
          String? servingUnit,
          String? mealType,
          DateTime? loggedAt,
          bool? isSynced,
          Value<String?> mealGroupId = const Value.absent(),
          Value<String?> uuid = const Value.absent()}) =>
      FoodLog(
        id: id ?? this.id,
        foodItemId: foodItemId.present ? foodItemId.value : this.foodItemId,
        name: name ?? this.name,
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        servingLogged: servingLogged ?? this.servingLogged,
        servingUnit: servingUnit ?? this.servingUnit,
        mealType: mealType ?? this.mealType,
        loggedAt: loggedAt ?? this.loggedAt,
        isSynced: isSynced ?? this.isSynced,
        mealGroupId: mealGroupId.present ? mealGroupId.value : this.mealGroupId,
        uuid: uuid.present ? uuid.value : this.uuid,
      );
  FoodLog copyWithCompanion(FoodLogsCompanion data) {
    return FoodLog(
      id: data.id.present ? data.id.value : this.id,
      foodItemId:
          data.foodItemId.present ? data.foodItemId.value : this.foodItemId,
      name: data.name.present ? data.name.value : this.name,
      calories: data.calories.present ? data.calories.value : this.calories,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      carbsG: data.carbsG.present ? data.carbsG.value : this.carbsG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      servingLogged: data.servingLogged.present
          ? data.servingLogged.value
          : this.servingLogged,
      servingUnit:
          data.servingUnit.present ? data.servingUnit.value : this.servingUnit,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      mealGroupId:
          data.mealGroupId.present ? data.mealGroupId.value : this.mealGroupId,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodLog(')
          ..write('id: $id, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('fatG: $fatG, ')
          ..write('servingLogged: $servingLogged, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('mealType: $mealType, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('mealGroupId: $mealGroupId, ')
          ..write('uuid: $uuid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      foodItemId,
      name,
      calories,
      proteinG,
      carbsG,
      fatG,
      servingLogged,
      servingUnit,
      mealType,
      loggedAt,
      isSynced,
      mealGroupId,
      uuid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodLog &&
          other.id == this.id &&
          other.foodItemId == this.foodItemId &&
          other.name == this.name &&
          other.calories == this.calories &&
          other.proteinG == this.proteinG &&
          other.carbsG == this.carbsG &&
          other.fatG == this.fatG &&
          other.servingLogged == this.servingLogged &&
          other.servingUnit == this.servingUnit &&
          other.mealType == this.mealType &&
          other.loggedAt == this.loggedAt &&
          other.isSynced == this.isSynced &&
          other.mealGroupId == this.mealGroupId &&
          other.uuid == this.uuid);
}

class FoodLogsCompanion extends UpdateCompanion<FoodLog> {
  final Value<int> id;
  final Value<int?> foodItemId;
  final Value<String> name;
  final Value<int> calories;
  final Value<double> proteinG;
  final Value<double> carbsG;
  final Value<double> fatG;
  final Value<double> servingLogged;
  final Value<String> servingUnit;
  final Value<String> mealType;
  final Value<DateTime> loggedAt;
  final Value<bool> isSynced;
  final Value<String?> mealGroupId;
  final Value<String?> uuid;
  const FoodLogsCompanion({
    this.id = const Value.absent(),
    this.foodItemId = const Value.absent(),
    this.name = const Value.absent(),
    this.calories = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.carbsG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.servingLogged = const Value.absent(),
    this.servingUnit = const Value.absent(),
    this.mealType = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.mealGroupId = const Value.absent(),
    this.uuid = const Value.absent(),
  });
  FoodLogsCompanion.insert({
    this.id = const Value.absent(),
    this.foodItemId = const Value.absent(),
    required String name,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double servingLogged,
    required String servingUnit,
    required String mealType,
    this.loggedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.mealGroupId = const Value.absent(),
    this.uuid = const Value.absent(),
  })  : name = Value(name),
        calories = Value(calories),
        proteinG = Value(proteinG),
        carbsG = Value(carbsG),
        fatG = Value(fatG),
        servingLogged = Value(servingLogged),
        servingUnit = Value(servingUnit),
        mealType = Value(mealType);
  static Insertable<FoodLog> custom({
    Expression<int>? id,
    Expression<int>? foodItemId,
    Expression<String>? name,
    Expression<int>? calories,
    Expression<double>? proteinG,
    Expression<double>? carbsG,
    Expression<double>? fatG,
    Expression<double>? servingLogged,
    Expression<String>? servingUnit,
    Expression<String>? mealType,
    Expression<DateTime>? loggedAt,
    Expression<bool>? isSynced,
    Expression<String>? mealGroupId,
    Expression<String>? uuid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (foodItemId != null) 'food_item_id': foodItemId,
      if (name != null) 'name': name,
      if (calories != null) 'calories': calories,
      if (proteinG != null) 'protein_g': proteinG,
      if (carbsG != null) 'carbs_g': carbsG,
      if (fatG != null) 'fat_g': fatG,
      if (servingLogged != null) 'serving_logged': servingLogged,
      if (servingUnit != null) 'serving_unit': servingUnit,
      if (mealType != null) 'meal_type': mealType,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (mealGroupId != null) 'meal_group_id': mealGroupId,
      if (uuid != null) 'uuid': uuid,
    });
  }

  FoodLogsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? foodItemId,
      Value<String>? name,
      Value<int>? calories,
      Value<double>? proteinG,
      Value<double>? carbsG,
      Value<double>? fatG,
      Value<double>? servingLogged,
      Value<String>? servingUnit,
      Value<String>? mealType,
      Value<DateTime>? loggedAt,
      Value<bool>? isSynced,
      Value<String?>? mealGroupId,
      Value<String?>? uuid}) {
    return FoodLogsCompanion(
      id: id ?? this.id,
      foodItemId: foodItemId ?? this.foodItemId,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      servingLogged: servingLogged ?? this.servingLogged,
      servingUnit: servingUnit ?? this.servingUnit,
      mealType: mealType ?? this.mealType,
      loggedAt: loggedAt ?? this.loggedAt,
      isSynced: isSynced ?? this.isSynced,
      mealGroupId: mealGroupId ?? this.mealGroupId,
      uuid: uuid ?? this.uuid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (foodItemId.present) {
      map['food_item_id'] = Variable<int>(foodItemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (carbsG.present) {
      map['carbs_g'] = Variable<double>(carbsG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (servingLogged.present) {
      map['serving_logged'] = Variable<double>(servingLogged.value);
    }
    if (servingUnit.present) {
      map['serving_unit'] = Variable<String>(servingUnit.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (mealGroupId.present) {
      map['meal_group_id'] = Variable<String>(mealGroupId.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodLogsCompanion(')
          ..write('id: $id, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('fatG: $fatG, ')
          ..write('servingLogged: $servingLogged, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('mealType: $mealType, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('mealGroupId: $mealGroupId, ')
          ..write('uuid: $uuid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _stableIdMeta =
      const VerificationMeta('stableId');
  @override
  late final GeneratedColumn<String> stableId = GeneratedColumn<String>(
      'stable_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _muscleGroupsMeta =
      const VerificationMeta('muscleGroups');
  @override
  late final GeneratedColumn<String> muscleGroups = GeneratedColumn<String>(
      'muscle_groups', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _equipmentMeta =
      const VerificationMeta('equipment');
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
      'equipment', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
      'difficulty', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _formCuesMeta =
      const VerificationMeta('formCues');
  @override
  late final GeneratedColumn<String> formCues = GeneratedColumn<String>(
      'form_cues', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _commonMistakesMeta =
      const VerificationMeta('commonMistakes');
  @override
  late final GeneratedColumn<String> commonMistakes = GeneratedColumn<String>(
      'common_mistakes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _youtubeIdMeta =
      const VerificationMeta('youtubeId');
  @override
  late final GeneratedColumn<String> youtubeId = GeneratedColumn<String>(
      'youtube_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isCustomMeta =
      const VerificationMeta('isCustom');
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
      'is_custom', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_custom" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        stableId,
        name,
        muscleGroups,
        equipment,
        difficulty,
        formCues,
        commonMistakes,
        youtubeId,
        isCustom
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(Insertable<Exercise> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('stable_id')) {
      context.handle(_stableIdMeta,
          stableId.isAcceptableOrUnknown(data['stable_id']!, _stableIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('muscle_groups')) {
      context.handle(
          _muscleGroupsMeta,
          muscleGroups.isAcceptableOrUnknown(
              data['muscle_groups']!, _muscleGroupsMeta));
    } else if (isInserting) {
      context.missing(_muscleGroupsMeta);
    }
    if (data.containsKey('equipment')) {
      context.handle(_equipmentMeta,
          equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta));
    } else if (isInserting) {
      context.missing(_equipmentMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('form_cues')) {
      context.handle(_formCuesMeta,
          formCues.isAcceptableOrUnknown(data['form_cues']!, _formCuesMeta));
    } else if (isInserting) {
      context.missing(_formCuesMeta);
    }
    if (data.containsKey('common_mistakes')) {
      context.handle(
          _commonMistakesMeta,
          commonMistakes.isAcceptableOrUnknown(
              data['common_mistakes']!, _commonMistakesMeta));
    } else if (isInserting) {
      context.missing(_commonMistakesMeta);
    }
    if (data.containsKey('youtube_id')) {
      context.handle(_youtubeIdMeta,
          youtubeId.isAcceptableOrUnknown(data['youtube_id']!, _youtubeIdMeta));
    }
    if (data.containsKey('is_custom')) {
      context.handle(_isCustomMeta,
          isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      stableId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stable_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      muscleGroups: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}muscle_groups'])!,
      equipment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment'])!,
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}difficulty'])!,
      formCues: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}form_cues'])!,
      commonMistakes: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}common_mistakes'])!,
      youtubeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}youtube_id']),
      isCustom: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_custom'])!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;

  /// Portable B01 identity. It remains nullable at the SQL declaration so a
  /// v14 table can be upgraded without a destructive table rebuild; v15
  /// migration and the insert trigger ensure every persisted row receives one.
  final String? stableId;
  final String name;
  final String muscleGroups;
  final String equipment;
  final String difficulty;
  final String formCues;
  final String commonMistakes;
  final String? youtubeId;
  final bool isCustom;
  const Exercise(
      {required this.id,
      this.stableId,
      required this.name,
      required this.muscleGroups,
      required this.equipment,
      required this.difficulty,
      required this.formCues,
      required this.commonMistakes,
      this.youtubeId,
      required this.isCustom});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || stableId != null) {
      map['stable_id'] = Variable<String>(stableId);
    }
    map['name'] = Variable<String>(name);
    map['muscle_groups'] = Variable<String>(muscleGroups);
    map['equipment'] = Variable<String>(equipment);
    map['difficulty'] = Variable<String>(difficulty);
    map['form_cues'] = Variable<String>(formCues);
    map['common_mistakes'] = Variable<String>(commonMistakes);
    if (!nullToAbsent || youtubeId != null) {
      map['youtube_id'] = Variable<String>(youtubeId);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      stableId: stableId == null && nullToAbsent
          ? const Value.absent()
          : Value(stableId),
      name: Value(name),
      muscleGroups: Value(muscleGroups),
      equipment: Value(equipment),
      difficulty: Value(difficulty),
      formCues: Value(formCues),
      commonMistakes: Value(commonMistakes),
      youtubeId: youtubeId == null && nullToAbsent
          ? const Value.absent()
          : Value(youtubeId),
      isCustom: Value(isCustom),
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      stableId: serializer.fromJson<String?>(json['stableId']),
      name: serializer.fromJson<String>(json['name']),
      muscleGroups: serializer.fromJson<String>(json['muscleGroups']),
      equipment: serializer.fromJson<String>(json['equipment']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      formCues: serializer.fromJson<String>(json['formCues']),
      commonMistakes: serializer.fromJson<String>(json['commonMistakes']),
      youtubeId: serializer.fromJson<String?>(json['youtubeId']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'stableId': serializer.toJson<String?>(stableId),
      'name': serializer.toJson<String>(name),
      'muscleGroups': serializer.toJson<String>(muscleGroups),
      'equipment': serializer.toJson<String>(equipment),
      'difficulty': serializer.toJson<String>(difficulty),
      'formCues': serializer.toJson<String>(formCues),
      'commonMistakes': serializer.toJson<String>(commonMistakes),
      'youtubeId': serializer.toJson<String?>(youtubeId),
      'isCustom': serializer.toJson<bool>(isCustom),
    };
  }

  Exercise copyWith(
          {int? id,
          Value<String?> stableId = const Value.absent(),
          String? name,
          String? muscleGroups,
          String? equipment,
          String? difficulty,
          String? formCues,
          String? commonMistakes,
          Value<String?> youtubeId = const Value.absent(),
          bool? isCustom}) =>
      Exercise(
        id: id ?? this.id,
        stableId: stableId.present ? stableId.value : this.stableId,
        name: name ?? this.name,
        muscleGroups: muscleGroups ?? this.muscleGroups,
        equipment: equipment ?? this.equipment,
        difficulty: difficulty ?? this.difficulty,
        formCues: formCues ?? this.formCues,
        commonMistakes: commonMistakes ?? this.commonMistakes,
        youtubeId: youtubeId.present ? youtubeId.value : this.youtubeId,
        isCustom: isCustom ?? this.isCustom,
      );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      stableId: data.stableId.present ? data.stableId.value : this.stableId,
      name: data.name.present ? data.name.value : this.name,
      muscleGroups: data.muscleGroups.present
          ? data.muscleGroups.value
          : this.muscleGroups,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      formCues: data.formCues.present ? data.formCues.value : this.formCues,
      commonMistakes: data.commonMistakes.present
          ? data.commonMistakes.value
          : this.commonMistakes,
      youtubeId: data.youtubeId.present ? data.youtubeId.value : this.youtubeId,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('stableId: $stableId, ')
          ..write('name: $name, ')
          ..write('muscleGroups: $muscleGroups, ')
          ..write('equipment: $equipment, ')
          ..write('difficulty: $difficulty, ')
          ..write('formCues: $formCues, ')
          ..write('commonMistakes: $commonMistakes, ')
          ..write('youtubeId: $youtubeId, ')
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, stableId, name, muscleGroups, equipment,
      difficulty, formCues, commonMistakes, youtubeId, isCustom);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.stableId == this.stableId &&
          other.name == this.name &&
          other.muscleGroups == this.muscleGroups &&
          other.equipment == this.equipment &&
          other.difficulty == this.difficulty &&
          other.formCues == this.formCues &&
          other.commonMistakes == this.commonMistakes &&
          other.youtubeId == this.youtubeId &&
          other.isCustom == this.isCustom);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String?> stableId;
  final Value<String> name;
  final Value<String> muscleGroups;
  final Value<String> equipment;
  final Value<String> difficulty;
  final Value<String> formCues;
  final Value<String> commonMistakes;
  final Value<String?> youtubeId;
  final Value<bool> isCustom;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.stableId = const Value.absent(),
    this.name = const Value.absent(),
    this.muscleGroups = const Value.absent(),
    this.equipment = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.formCues = const Value.absent(),
    this.commonMistakes = const Value.absent(),
    this.youtubeId = const Value.absent(),
    this.isCustom = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    this.stableId = const Value.absent(),
    required String name,
    required String muscleGroups,
    required String equipment,
    required String difficulty,
    required String formCues,
    required String commonMistakes,
    this.youtubeId = const Value.absent(),
    this.isCustom = const Value.absent(),
  })  : name = Value(name),
        muscleGroups = Value(muscleGroups),
        equipment = Value(equipment),
        difficulty = Value(difficulty),
        formCues = Value(formCues),
        commonMistakes = Value(commonMistakes);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? stableId,
    Expression<String>? name,
    Expression<String>? muscleGroups,
    Expression<String>? equipment,
    Expression<String>? difficulty,
    Expression<String>? formCues,
    Expression<String>? commonMistakes,
    Expression<String>? youtubeId,
    Expression<bool>? isCustom,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stableId != null) 'stable_id': stableId,
      if (name != null) 'name': name,
      if (muscleGroups != null) 'muscle_groups': muscleGroups,
      if (equipment != null) 'equipment': equipment,
      if (difficulty != null) 'difficulty': difficulty,
      if (formCues != null) 'form_cues': formCues,
      if (commonMistakes != null) 'common_mistakes': commonMistakes,
      if (youtubeId != null) 'youtube_id': youtubeId,
      if (isCustom != null) 'is_custom': isCustom,
    });
  }

  ExercisesCompanion copyWith(
      {Value<int>? id,
      Value<String?>? stableId,
      Value<String>? name,
      Value<String>? muscleGroups,
      Value<String>? equipment,
      Value<String>? difficulty,
      Value<String>? formCues,
      Value<String>? commonMistakes,
      Value<String?>? youtubeId,
      Value<bool>? isCustom}) {
    return ExercisesCompanion(
      id: id ?? this.id,
      stableId: stableId ?? this.stableId,
      name: name ?? this.name,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      formCues: formCues ?? this.formCues,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      youtubeId: youtubeId ?? this.youtubeId,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (stableId.present) {
      map['stable_id'] = Variable<String>(stableId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (muscleGroups.present) {
      map['muscle_groups'] = Variable<String>(muscleGroups.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (formCues.present) {
      map['form_cues'] = Variable<String>(formCues.value);
    }
    if (commonMistakes.present) {
      map['common_mistakes'] = Variable<String>(commonMistakes.value);
    }
    if (youtubeId.present) {
      map['youtube_id'] = Variable<String>(youtubeId.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('stableId: $stableId, ')
          ..write('name: $name, ')
          ..write('muscleGroups: $muscleGroups, ')
          ..write('equipment: $equipment, ')
          ..write('difficulty: $difficulty, ')
          ..write('formCues: $formCues, ')
          ..write('commonMistakes: $commonMistakes, ')
          ..write('youtubeId: $youtubeId, ')
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionsTable extends WorkoutSessions
    with TableInfo<$WorkoutSessionsTable, WorkoutSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _totalVolumeMeta =
      const VerificationMeta('totalVolume');
  @override
  late final GeneratedColumn<double> totalVolume = GeneratedColumn<double>(
      'total_volume', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _estimatedCaloriesMeta =
      const VerificationMeta('estimatedCalories');
  @override
  late final GeneratedColumn<int> estimatedCalories = GeneratedColumn<int>(
      'estimated_calories', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scheduledOccurrenceIdMeta =
      const VerificationMeta('scheduledOccurrenceId');
  @override
  late final GeneratedColumn<String> scheduledOccurrenceId =
      GeneratedColumn<String>('scheduled_occurrence_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          $customConstraints: 'REFERENCES scheduled_session_occurrences(id)');
  static const VerificationMeta _executionSnapshotJsonMeta =
      const VerificationMeta('executionSnapshotJson');
  @override
  late final GeneratedColumn<String> executionSnapshotJson =
      GeneratedColumn<String>('execution_snapshot_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _executionTimezoneIdMeta =
      const VerificationMeta('executionTimezoneId');
  @override
  late final GeneratedColumn<String> executionTimezoneId =
      GeneratedColumn<String>('execution_timezone_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _completionKindMeta =
      const VerificationMeta('completionKind');
  @override
  late final GeneratedColumn<String> completionKind = GeneratedColumn<String>(
      'completion_kind', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        totalVolume,
        durationSeconds,
        estimatedCalories,
        completedAt,
        isSynced,
        uuid,
        scheduledOccurrenceId,
        executionSnapshotJson,
        executionTimezoneId,
        completionKind
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('total_volume')) {
      context.handle(
          _totalVolumeMeta,
          totalVolume.isAcceptableOrUnknown(
              data['total_volume']!, _totalVolumeMeta));
    } else if (isInserting) {
      context.missing(_totalVolumeMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('estimated_calories')) {
      context.handle(
          _estimatedCaloriesMeta,
          estimatedCalories.isAcceptableOrUnknown(
              data['estimated_calories']!, _estimatedCaloriesMeta));
    } else if (isInserting) {
      context.missing(_estimatedCaloriesMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    }
    if (data.containsKey('scheduled_occurrence_id')) {
      context.handle(
          _scheduledOccurrenceIdMeta,
          scheduledOccurrenceId.isAcceptableOrUnknown(
              data['scheduled_occurrence_id']!, _scheduledOccurrenceIdMeta));
    }
    if (data.containsKey('execution_snapshot_json')) {
      context.handle(
          _executionSnapshotJsonMeta,
          executionSnapshotJson.isAcceptableOrUnknown(
              data['execution_snapshot_json']!, _executionSnapshotJsonMeta));
    }
    if (data.containsKey('execution_timezone_id')) {
      context.handle(
          _executionTimezoneIdMeta,
          executionTimezoneId.isAcceptableOrUnknown(
              data['execution_timezone_id']!, _executionTimezoneIdMeta));
    }
    if (data.containsKey('completion_kind')) {
      context.handle(
          _completionKindMeta,
          completionKind.isAcceptableOrUnknown(
              data['completion_kind']!, _completionKindMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSession(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      totalVolume: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_volume'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      estimatedCalories: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}estimated_calories'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid']),
      scheduledOccurrenceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scheduled_occurrence_id']),
      executionSnapshotJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}execution_snapshot_json']),
      executionTimezoneId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}execution_timezone_id']),
      completionKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}completion_kind']),
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSession extends DataClass implements Insertable<WorkoutSession> {
  final int id;
  final String name;
  final double totalVolume;
  final int durationSeconds;
  final int estimatedCalories;
  final DateTime completedAt;
  final bool isSynced;
  final String? uuid;
  final String? scheduledOccurrenceId;
  final String? executionSnapshotJson;
  final String? executionTimezoneId;
  final String? completionKind;
  const WorkoutSession(
      {required this.id,
      required this.name,
      required this.totalVolume,
      required this.durationSeconds,
      required this.estimatedCalories,
      required this.completedAt,
      required this.isSynced,
      this.uuid,
      this.scheduledOccurrenceId,
      this.executionSnapshotJson,
      this.executionTimezoneId,
      this.completionKind});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['total_volume'] = Variable<double>(totalVolume);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['estimated_calories'] = Variable<int>(estimatedCalories);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    if (!nullToAbsent || scheduledOccurrenceId != null) {
      map['scheduled_occurrence_id'] = Variable<String>(scheduledOccurrenceId);
    }
    if (!nullToAbsent || executionSnapshotJson != null) {
      map['execution_snapshot_json'] = Variable<String>(executionSnapshotJson);
    }
    if (!nullToAbsent || executionTimezoneId != null) {
      map['execution_timezone_id'] = Variable<String>(executionTimezoneId);
    }
    if (!nullToAbsent || completionKind != null) {
      map['completion_kind'] = Variable<String>(completionKind);
    }
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      id: Value(id),
      name: Value(name),
      totalVolume: Value(totalVolume),
      durationSeconds: Value(durationSeconds),
      estimatedCalories: Value(estimatedCalories),
      completedAt: Value(completedAt),
      isSynced: Value(isSynced),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
      scheduledOccurrenceId: scheduledOccurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledOccurrenceId),
      executionSnapshotJson: executionSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(executionSnapshotJson),
      executionTimezoneId: executionTimezoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(executionTimezoneId),
      completionKind: completionKind == null && nullToAbsent
          ? const Value.absent()
          : Value(completionKind),
    );
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSession(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      totalVolume: serializer.fromJson<double>(json['totalVolume']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      estimatedCalories: serializer.fromJson<int>(json['estimatedCalories']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      uuid: serializer.fromJson<String?>(json['uuid']),
      scheduledOccurrenceId:
          serializer.fromJson<String?>(json['scheduledOccurrenceId']),
      executionSnapshotJson:
          serializer.fromJson<String?>(json['executionSnapshotJson']),
      executionTimezoneId:
          serializer.fromJson<String?>(json['executionTimezoneId']),
      completionKind: serializer.fromJson<String?>(json['completionKind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'totalVolume': serializer.toJson<double>(totalVolume),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'estimatedCalories': serializer.toJson<int>(estimatedCalories),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
      'uuid': serializer.toJson<String?>(uuid),
      'scheduledOccurrenceId':
          serializer.toJson<String?>(scheduledOccurrenceId),
      'executionSnapshotJson':
          serializer.toJson<String?>(executionSnapshotJson),
      'executionTimezoneId': serializer.toJson<String?>(executionTimezoneId),
      'completionKind': serializer.toJson<String?>(completionKind),
    };
  }

  WorkoutSession copyWith(
          {int? id,
          String? name,
          double? totalVolume,
          int? durationSeconds,
          int? estimatedCalories,
          DateTime? completedAt,
          bool? isSynced,
          Value<String?> uuid = const Value.absent(),
          Value<String?> scheduledOccurrenceId = const Value.absent(),
          Value<String?> executionSnapshotJson = const Value.absent(),
          Value<String?> executionTimezoneId = const Value.absent(),
          Value<String?> completionKind = const Value.absent()}) =>
      WorkoutSession(
        id: id ?? this.id,
        name: name ?? this.name,
        totalVolume: totalVolume ?? this.totalVolume,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        estimatedCalories: estimatedCalories ?? this.estimatedCalories,
        completedAt: completedAt ?? this.completedAt,
        isSynced: isSynced ?? this.isSynced,
        uuid: uuid.present ? uuid.value : this.uuid,
        scheduledOccurrenceId: scheduledOccurrenceId.present
            ? scheduledOccurrenceId.value
            : this.scheduledOccurrenceId,
        executionSnapshotJson: executionSnapshotJson.present
            ? executionSnapshotJson.value
            : this.executionSnapshotJson,
        executionTimezoneId: executionTimezoneId.present
            ? executionTimezoneId.value
            : this.executionTimezoneId,
        completionKind:
            completionKind.present ? completionKind.value : this.completionKind,
      );
  WorkoutSession copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSession(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      totalVolume:
          data.totalVolume.present ? data.totalVolume.value : this.totalVolume,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      estimatedCalories: data.estimatedCalories.present
          ? data.estimatedCalories.value
          : this.estimatedCalories,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      scheduledOccurrenceId: data.scheduledOccurrenceId.present
          ? data.scheduledOccurrenceId.value
          : this.scheduledOccurrenceId,
      executionSnapshotJson: data.executionSnapshotJson.present
          ? data.executionSnapshotJson.value
          : this.executionSnapshotJson,
      executionTimezoneId: data.executionTimezoneId.present
          ? data.executionTimezoneId.value
          : this.executionTimezoneId,
      completionKind: data.completionKind.present
          ? data.completionKind.value
          : this.completionKind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSession(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('totalVolume: $totalVolume, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('estimatedCalories: $estimatedCalories, ')
          ..write('completedAt: $completedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('uuid: $uuid, ')
          ..write('scheduledOccurrenceId: $scheduledOccurrenceId, ')
          ..write('executionSnapshotJson: $executionSnapshotJson, ')
          ..write('executionTimezoneId: $executionTimezoneId, ')
          ..write('completionKind: $completionKind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      totalVolume,
      durationSeconds,
      estimatedCalories,
      completedAt,
      isSynced,
      uuid,
      scheduledOccurrenceId,
      executionSnapshotJson,
      executionTimezoneId,
      completionKind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSession &&
          other.id == this.id &&
          other.name == this.name &&
          other.totalVolume == this.totalVolume &&
          other.durationSeconds == this.durationSeconds &&
          other.estimatedCalories == this.estimatedCalories &&
          other.completedAt == this.completedAt &&
          other.isSynced == this.isSynced &&
          other.uuid == this.uuid &&
          other.scheduledOccurrenceId == this.scheduledOccurrenceId &&
          other.executionSnapshotJson == this.executionSnapshotJson &&
          other.executionTimezoneId == this.executionTimezoneId &&
          other.completionKind == this.completionKind);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSession> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> totalVolume;
  final Value<int> durationSeconds;
  final Value<int> estimatedCalories;
  final Value<DateTime> completedAt;
  final Value<bool> isSynced;
  final Value<String?> uuid;
  final Value<String?> scheduledOccurrenceId;
  final Value<String?> executionSnapshotJson;
  final Value<String?> executionTimezoneId;
  final Value<String?> completionKind;
  const WorkoutSessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.totalVolume = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.estimatedCalories = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.uuid = const Value.absent(),
    this.scheduledOccurrenceId = const Value.absent(),
    this.executionSnapshotJson = const Value.absent(),
    this.executionTimezoneId = const Value.absent(),
    this.completionKind = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double totalVolume,
    required int durationSeconds,
    required int estimatedCalories,
    this.completedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.uuid = const Value.absent(),
    this.scheduledOccurrenceId = const Value.absent(),
    this.executionSnapshotJson = const Value.absent(),
    this.executionTimezoneId = const Value.absent(),
    this.completionKind = const Value.absent(),
  })  : name = Value(name),
        totalVolume = Value(totalVolume),
        durationSeconds = Value(durationSeconds),
        estimatedCalories = Value(estimatedCalories);
  static Insertable<WorkoutSession> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? totalVolume,
    Expression<int>? durationSeconds,
    Expression<int>? estimatedCalories,
    Expression<DateTime>? completedAt,
    Expression<bool>? isSynced,
    Expression<String>? uuid,
    Expression<String>? scheduledOccurrenceId,
    Expression<String>? executionSnapshotJson,
    Expression<String>? executionTimezoneId,
    Expression<String>? completionKind,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (totalVolume != null) 'total_volume': totalVolume,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (estimatedCalories != null) 'estimated_calories': estimatedCalories,
      if (completedAt != null) 'completed_at': completedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (uuid != null) 'uuid': uuid,
      if (scheduledOccurrenceId != null)
        'scheduled_occurrence_id': scheduledOccurrenceId,
      if (executionSnapshotJson != null)
        'execution_snapshot_json': executionSnapshotJson,
      if (executionTimezoneId != null)
        'execution_timezone_id': executionTimezoneId,
      if (completionKind != null) 'completion_kind': completionKind,
    });
  }

  WorkoutSessionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<double>? totalVolume,
      Value<int>? durationSeconds,
      Value<int>? estimatedCalories,
      Value<DateTime>? completedAt,
      Value<bool>? isSynced,
      Value<String?>? uuid,
      Value<String?>? scheduledOccurrenceId,
      Value<String?>? executionSnapshotJson,
      Value<String?>? executionTimezoneId,
      Value<String?>? completionKind}) {
    return WorkoutSessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      totalVolume: totalVolume ?? this.totalVolume,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      completedAt: completedAt ?? this.completedAt,
      isSynced: isSynced ?? this.isSynced,
      uuid: uuid ?? this.uuid,
      scheduledOccurrenceId:
          scheduledOccurrenceId ?? this.scheduledOccurrenceId,
      executionSnapshotJson:
          executionSnapshotJson ?? this.executionSnapshotJson,
      executionTimezoneId: executionTimezoneId ?? this.executionTimezoneId,
      completionKind: completionKind ?? this.completionKind,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (totalVolume.present) {
      map['total_volume'] = Variable<double>(totalVolume.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (estimatedCalories.present) {
      map['estimated_calories'] = Variable<int>(estimatedCalories.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (scheduledOccurrenceId.present) {
      map['scheduled_occurrence_id'] =
          Variable<String>(scheduledOccurrenceId.value);
    }
    if (executionSnapshotJson.present) {
      map['execution_snapshot_json'] =
          Variable<String>(executionSnapshotJson.value);
    }
    if (executionTimezoneId.present) {
      map['execution_timezone_id'] =
          Variable<String>(executionTimezoneId.value);
    }
    if (completionKind.present) {
      map['completion_kind'] = Variable<String>(completionKind.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('totalVolume: $totalVolume, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('estimatedCalories: $estimatedCalories, ')
          ..write('completedAt: $completedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('uuid: $uuid, ')
          ..write('scheduledOccurrenceId: $scheduledOccurrenceId, ')
          ..write('executionSnapshotJson: $executionSnapshotJson, ')
          ..write('executionTimezoneId: $executionTimezoneId, ')
          ..write('completionKind: $completionKind')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets
    with TableInfo<$WorkoutSetsTable, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES workout_sessions (id)'));
  static const VerificationMeta _exerciseNameMeta =
      const VerificationMeta('exerciseName');
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
      'exercise_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
      'weight', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
      'reps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _setNumberMeta =
      const VerificationMeta('setNumber');
  @override
  late final GeneratedColumn<int> setNumber = GeneratedColumn<int>(
      'set_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isPrMeta = const VerificationMeta('isPr');
  @override
  late final GeneratedColumn<bool> isPr = GeneratedColumn<bool>(
      'is_pr', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pr" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<int> rpe = GeneratedColumn<int>(
      'rpe', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isWarmUpMeta =
      const VerificationMeta('isWarmUp');
  @override
  late final GeneratedColumn<bool> isWarmUp = GeneratedColumn<bool>(
      'is_warm_up', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_warm_up" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _setNotesMeta =
      const VerificationMeta('setNotes');
  @override
  late final GeneratedColumn<String> setNotes = GeneratedColumn<String>(
      'set_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _setTypeMeta =
      const VerificationMeta('setType');
  @override
  late final GeneratedColumn<String> setType = GeneratedColumn<String>(
      'set_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('working'));
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _distanceKmMeta =
      const VerificationMeta('distanceKm');
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
      'distance_km', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _inclinePercentageMeta =
      const VerificationMeta('inclinePercentage');
  @override
  late final GeneratedColumn<double> inclinePercentage =
      GeneratedColumn<double>('incline_percentage', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _exerciseIdMeta =
      const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
      'exercise_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES exercises (stable_id)'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        exerciseName,
        weight,
        reps,
        setNumber,
        isPr,
        rpe,
        isWarmUp,
        setNotes,
        uuid,
        setType,
        durationSeconds,
        distanceKm,
        inclinePercentage,
        exerciseId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutSet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('exercise_name')) {
      context.handle(
          _exerciseNameMeta,
          exerciseName.isAcceptableOrUnknown(
              data['exercise_name']!, _exerciseNameMeta));
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
          _repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('set_number')) {
      context.handle(_setNumberMeta,
          setNumber.isAcceptableOrUnknown(data['set_number']!, _setNumberMeta));
    } else if (isInserting) {
      context.missing(_setNumberMeta);
    }
    if (data.containsKey('is_pr')) {
      context.handle(
          _isPrMeta, isPr.isAcceptableOrUnknown(data['is_pr']!, _isPrMeta));
    }
    if (data.containsKey('rpe')) {
      context.handle(
          _rpeMeta, rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta));
    }
    if (data.containsKey('is_warm_up')) {
      context.handle(_isWarmUpMeta,
          isWarmUp.isAcceptableOrUnknown(data['is_warm_up']!, _isWarmUpMeta));
    }
    if (data.containsKey('set_notes')) {
      context.handle(_setNotesMeta,
          setNotes.isAcceptableOrUnknown(data['set_notes']!, _setNotesMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    }
    if (data.containsKey('set_type')) {
      context.handle(_setTypeMeta,
          setType.isAcceptableOrUnknown(data['set_type']!, _setTypeMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('distance_km')) {
      context.handle(
          _distanceKmMeta,
          distanceKm.isAcceptableOrUnknown(
              data['distance_km']!, _distanceKmMeta));
    }
    if (data.containsKey('incline_percentage')) {
      context.handle(
          _inclinePercentageMeta,
          inclinePercentage.isAcceptableOrUnknown(
              data['incline_percentage']!, _inclinePercentageMeta));
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
          _exerciseIdMeta,
          exerciseId.isAcceptableOrUnknown(
              data['exercise_id']!, _exerciseIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      exerciseName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_name'])!,
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight'])!,
      reps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reps'])!,
      setNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}set_number'])!,
      isPr: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pr'])!,
      rpe: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rpe']),
      isWarmUp: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_warm_up'])!,
      setNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}set_notes']),
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid']),
      setType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}set_type'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds']),
      distanceKm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}distance_km']),
      inclinePercentage: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}incline_percentage']),
      exerciseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_id']),
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  final int id;
  final int sessionId;
  final String exerciseName;
  final double weight;
  final int reps;
  final int setNumber;
  final bool isPr;
  final int? rpe;
  final bool isWarmUp;
  final String? setNotes;
  final String? uuid;
  final String setType;
  final int? durationSeconds;
  final double? distanceKm;
  final double? inclinePercentage;

  /// Stable exercise identity is additive; legacy name history remains intact.
  final String? exerciseId;
  const WorkoutSet(
      {required this.id,
      required this.sessionId,
      required this.exerciseName,
      required this.weight,
      required this.reps,
      required this.setNumber,
      required this.isPr,
      this.rpe,
      required this.isWarmUp,
      this.setNotes,
      this.uuid,
      required this.setType,
      this.durationSeconds,
      this.distanceKm,
      this.inclinePercentage,
      this.exerciseId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['exercise_name'] = Variable<String>(exerciseName);
    map['weight'] = Variable<double>(weight);
    map['reps'] = Variable<int>(reps);
    map['set_number'] = Variable<int>(setNumber);
    map['is_pr'] = Variable<bool>(isPr);
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<int>(rpe);
    }
    map['is_warm_up'] = Variable<bool>(isWarmUp);
    if (!nullToAbsent || setNotes != null) {
      map['set_notes'] = Variable<String>(setNotes);
    }
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    map['set_type'] = Variable<String>(setType);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || distanceKm != null) {
      map['distance_km'] = Variable<double>(distanceKm);
    }
    if (!nullToAbsent || inclinePercentage != null) {
      map['incline_percentage'] = Variable<double>(inclinePercentage);
    }
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<String>(exerciseId);
    }
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exerciseName: Value(exerciseName),
      weight: Value(weight),
      reps: Value(reps),
      setNumber: Value(setNumber),
      isPr: Value(isPr),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      isWarmUp: Value(isWarmUp),
      setNotes: setNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(setNotes),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
      setType: Value(setType),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      distanceKm: distanceKm == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceKm),
      inclinePercentage: inclinePercentage == null && nullToAbsent
          ? const Value.absent()
          : Value(inclinePercentage),
      exerciseId: exerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseId),
    );
  }

  factory WorkoutSet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      weight: serializer.fromJson<double>(json['weight']),
      reps: serializer.fromJson<int>(json['reps']),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      isPr: serializer.fromJson<bool>(json['isPr']),
      rpe: serializer.fromJson<int?>(json['rpe']),
      isWarmUp: serializer.fromJson<bool>(json['isWarmUp']),
      setNotes: serializer.fromJson<String?>(json['setNotes']),
      uuid: serializer.fromJson<String?>(json['uuid']),
      setType: serializer.fromJson<String>(json['setType']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      distanceKm: serializer.fromJson<double?>(json['distanceKm']),
      inclinePercentage:
          serializer.fromJson<double?>(json['inclinePercentage']),
      exerciseId: serializer.fromJson<String?>(json['exerciseId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'exerciseName': serializer.toJson<String>(exerciseName),
      'weight': serializer.toJson<double>(weight),
      'reps': serializer.toJson<int>(reps),
      'setNumber': serializer.toJson<int>(setNumber),
      'isPr': serializer.toJson<bool>(isPr),
      'rpe': serializer.toJson<int?>(rpe),
      'isWarmUp': serializer.toJson<bool>(isWarmUp),
      'setNotes': serializer.toJson<String?>(setNotes),
      'uuid': serializer.toJson<String?>(uuid),
      'setType': serializer.toJson<String>(setType),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'distanceKm': serializer.toJson<double?>(distanceKm),
      'inclinePercentage': serializer.toJson<double?>(inclinePercentage),
      'exerciseId': serializer.toJson<String?>(exerciseId),
    };
  }

  WorkoutSet copyWith(
          {int? id,
          int? sessionId,
          String? exerciseName,
          double? weight,
          int? reps,
          int? setNumber,
          bool? isPr,
          Value<int?> rpe = const Value.absent(),
          bool? isWarmUp,
          Value<String?> setNotes = const Value.absent(),
          Value<String?> uuid = const Value.absent(),
          String? setType,
          Value<int?> durationSeconds = const Value.absent(),
          Value<double?> distanceKm = const Value.absent(),
          Value<double?> inclinePercentage = const Value.absent(),
          Value<String?> exerciseId = const Value.absent()}) =>
      WorkoutSet(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        exerciseName: exerciseName ?? this.exerciseName,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        setNumber: setNumber ?? this.setNumber,
        isPr: isPr ?? this.isPr,
        rpe: rpe.present ? rpe.value : this.rpe,
        isWarmUp: isWarmUp ?? this.isWarmUp,
        setNotes: setNotes.present ? setNotes.value : this.setNotes,
        uuid: uuid.present ? uuid.value : this.uuid,
        setType: setType ?? this.setType,
        durationSeconds: durationSeconds.present
            ? durationSeconds.value
            : this.durationSeconds,
        distanceKm: distanceKm.present ? distanceKm.value : this.distanceKm,
        inclinePercentage: inclinePercentage.present
            ? inclinePercentage.value
            : this.inclinePercentage,
        exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
      );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      weight: data.weight.present ? data.weight.value : this.weight,
      reps: data.reps.present ? data.reps.value : this.reps,
      setNumber: data.setNumber.present ? data.setNumber.value : this.setNumber,
      isPr: data.isPr.present ? data.isPr.value : this.isPr,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      isWarmUp: data.isWarmUp.present ? data.isWarmUp.value : this.isWarmUp,
      setNotes: data.setNotes.present ? data.setNotes.value : this.setNotes,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      setType: data.setType.present ? data.setType.value : this.setType,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      distanceKm:
          data.distanceKm.present ? data.distanceKm.value : this.distanceKm,
      inclinePercentage: data.inclinePercentage.present
          ? data.inclinePercentage.value
          : this.inclinePercentage,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('setNumber: $setNumber, ')
          ..write('isPr: $isPr, ')
          ..write('rpe: $rpe, ')
          ..write('isWarmUp: $isWarmUp, ')
          ..write('setNotes: $setNotes, ')
          ..write('uuid: $uuid, ')
          ..write('setType: $setType, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('inclinePercentage: $inclinePercentage, ')
          ..write('exerciseId: $exerciseId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sessionId,
      exerciseName,
      weight,
      reps,
      setNumber,
      isPr,
      rpe,
      isWarmUp,
      setNotes,
      uuid,
      setType,
      durationSeconds,
      distanceKm,
      inclinePercentage,
      exerciseId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseName == this.exerciseName &&
          other.weight == this.weight &&
          other.reps == this.reps &&
          other.setNumber == this.setNumber &&
          other.isPr == this.isPr &&
          other.rpe == this.rpe &&
          other.isWarmUp == this.isWarmUp &&
          other.setNotes == this.setNotes &&
          other.uuid == this.uuid &&
          other.setType == this.setType &&
          other.durationSeconds == this.durationSeconds &&
          other.distanceKm == this.distanceKm &&
          other.inclinePercentage == this.inclinePercentage &&
          other.exerciseId == this.exerciseId);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> exerciseName;
  final Value<double> weight;
  final Value<int> reps;
  final Value<int> setNumber;
  final Value<bool> isPr;
  final Value<int?> rpe;
  final Value<bool> isWarmUp;
  final Value<String?> setNotes;
  final Value<String?> uuid;
  final Value<String> setType;
  final Value<int?> durationSeconds;
  final Value<double?> distanceKm;
  final Value<double?> inclinePercentage;
  final Value<String?> exerciseId;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.isPr = const Value.absent(),
    this.rpe = const Value.absent(),
    this.isWarmUp = const Value.absent(),
    this.setNotes = const Value.absent(),
    this.uuid = const Value.absent(),
    this.setType = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.inclinePercentage = const Value.absent(),
    this.exerciseId = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String exerciseName,
    required double weight,
    required int reps,
    required int setNumber,
    this.isPr = const Value.absent(),
    this.rpe = const Value.absent(),
    this.isWarmUp = const Value.absent(),
    this.setNotes = const Value.absent(),
    this.uuid = const Value.absent(),
    this.setType = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.inclinePercentage = const Value.absent(),
    this.exerciseId = const Value.absent(),
  })  : sessionId = Value(sessionId),
        exerciseName = Value(exerciseName),
        weight = Value(weight),
        reps = Value(reps),
        setNumber = Value(setNumber);
  static Insertable<WorkoutSet> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? exerciseName,
    Expression<double>? weight,
    Expression<int>? reps,
    Expression<int>? setNumber,
    Expression<bool>? isPr,
    Expression<int>? rpe,
    Expression<bool>? isWarmUp,
    Expression<String>? setNotes,
    Expression<String>? uuid,
    Expression<String>? setType,
    Expression<int>? durationSeconds,
    Expression<double>? distanceKm,
    Expression<double>? inclinePercentage,
    Expression<String>? exerciseId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (weight != null) 'weight': weight,
      if (reps != null) 'reps': reps,
      if (setNumber != null) 'set_number': setNumber,
      if (isPr != null) 'is_pr': isPr,
      if (rpe != null) 'rpe': rpe,
      if (isWarmUp != null) 'is_warm_up': isWarmUp,
      if (setNotes != null) 'set_notes': setNotes,
      if (uuid != null) 'uuid': uuid,
      if (setType != null) 'set_type': setType,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (inclinePercentage != null) 'incline_percentage': inclinePercentage,
      if (exerciseId != null) 'exercise_id': exerciseId,
    });
  }

  WorkoutSetsCompanion copyWith(
      {Value<int>? id,
      Value<int>? sessionId,
      Value<String>? exerciseName,
      Value<double>? weight,
      Value<int>? reps,
      Value<int>? setNumber,
      Value<bool>? isPr,
      Value<int?>? rpe,
      Value<bool>? isWarmUp,
      Value<String?>? setNotes,
      Value<String?>? uuid,
      Value<String>? setType,
      Value<int?>? durationSeconds,
      Value<double?>? distanceKm,
      Value<double?>? inclinePercentage,
      Value<String?>? exerciseId}) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseName: exerciseName ?? this.exerciseName,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      setNumber: setNumber ?? this.setNumber,
      isPr: isPr ?? this.isPr,
      rpe: rpe ?? this.rpe,
      isWarmUp: isWarmUp ?? this.isWarmUp,
      setNotes: setNotes ?? this.setNotes,
      uuid: uuid ?? this.uuid,
      setType: setType ?? this.setType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      inclinePercentage: inclinePercentage ?? this.inclinePercentage,
      exerciseId: exerciseId ?? this.exerciseId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (exerciseName.present) {
      map['exercise_name'] = Variable<String>(exerciseName.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (setNumber.present) {
      map['set_number'] = Variable<int>(setNumber.value);
    }
    if (isPr.present) {
      map['is_pr'] = Variable<bool>(isPr.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<int>(rpe.value);
    }
    if (isWarmUp.present) {
      map['is_warm_up'] = Variable<bool>(isWarmUp.value);
    }
    if (setNotes.present) {
      map['set_notes'] = Variable<String>(setNotes.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (setType.present) {
      map['set_type'] = Variable<String>(setType.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (inclinePercentage.present) {
      map['incline_percentage'] = Variable<double>(inclinePercentage.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('setNumber: $setNumber, ')
          ..write('isPr: $isPr, ')
          ..write('rpe: $rpe, ')
          ..write('isWarmUp: $isWarmUp, ')
          ..write('setNotes: $setNotes, ')
          ..write('uuid: $uuid, ')
          ..write('setType: $setType, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('inclinePercentage: $inclinePercentage, ')
          ..write('exerciseId: $exerciseId')
          ..write(')'))
        .toString();
  }
}

class $BodyMeasurementsTable extends BodyMeasurements
    with TableInfo<$BodyMeasurementsTable, BodyMeasurement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyMeasurementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
      'weight', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _waistMeta = const VerificationMeta('waist');
  @override
  late final GeneratedColumn<double> waist = GeneratedColumn<double>(
      'waist', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _chestMeta = const VerificationMeta('chest');
  @override
  late final GeneratedColumn<double> chest = GeneratedColumn<double>(
      'chest', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _armsMeta = const VerificationMeta('arms');
  @override
  late final GeneratedColumn<double> arms = GeneratedColumn<double>(
      'arms', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, weight, waist, chest, arms, recordedAt, isSynced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'body_measurements';
  @override
  VerificationContext validateIntegrity(Insertable<BodyMeasurement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('waist')) {
      context.handle(
          _waistMeta, waist.isAcceptableOrUnknown(data['waist']!, _waistMeta));
    }
    if (data.containsKey('chest')) {
      context.handle(
          _chestMeta, chest.isAcceptableOrUnknown(data['chest']!, _chestMeta));
    }
    if (data.containsKey('arms')) {
      context.handle(
          _armsMeta, arms.isAcceptableOrUnknown(data['arms']!, _armsMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BodyMeasurement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyMeasurement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight']),
      waist: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}waist']),
      chest: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}chest']),
      arms: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}arms']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
    );
  }

  @override
  $BodyMeasurementsTable createAlias(String alias) {
    return $BodyMeasurementsTable(attachedDatabase, alias);
  }
}

class BodyMeasurement extends DataClass implements Insertable<BodyMeasurement> {
  final int id;
  final double? weight;
  final double? waist;
  final double? chest;
  final double? arms;
  final DateTime recordedAt;
  final bool isSynced;
  const BodyMeasurement(
      {required this.id,
      this.weight,
      this.waist,
      this.chest,
      this.arms,
      required this.recordedAt,
      required this.isSynced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    if (!nullToAbsent || waist != null) {
      map['waist'] = Variable<double>(waist);
    }
    if (!nullToAbsent || chest != null) {
      map['chest'] = Variable<double>(chest);
    }
    if (!nullToAbsent || arms != null) {
      map['arms'] = Variable<double>(arms);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  BodyMeasurementsCompanion toCompanion(bool nullToAbsent) {
    return BodyMeasurementsCompanion(
      id: Value(id),
      weight:
          weight == null && nullToAbsent ? const Value.absent() : Value(weight),
      waist:
          waist == null && nullToAbsent ? const Value.absent() : Value(waist),
      chest:
          chest == null && nullToAbsent ? const Value.absent() : Value(chest),
      arms: arms == null && nullToAbsent ? const Value.absent() : Value(arms),
      recordedAt: Value(recordedAt),
      isSynced: Value(isSynced),
    );
  }

  factory BodyMeasurement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyMeasurement(
      id: serializer.fromJson<int>(json['id']),
      weight: serializer.fromJson<double?>(json['weight']),
      waist: serializer.fromJson<double?>(json['waist']),
      chest: serializer.fromJson<double?>(json['chest']),
      arms: serializer.fromJson<double?>(json['arms']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weight': serializer.toJson<double?>(weight),
      'waist': serializer.toJson<double?>(waist),
      'chest': serializer.toJson<double?>(chest),
      'arms': serializer.toJson<double?>(arms),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  BodyMeasurement copyWith(
          {int? id,
          Value<double?> weight = const Value.absent(),
          Value<double?> waist = const Value.absent(),
          Value<double?> chest = const Value.absent(),
          Value<double?> arms = const Value.absent(),
          DateTime? recordedAt,
          bool? isSynced}) =>
      BodyMeasurement(
        id: id ?? this.id,
        weight: weight.present ? weight.value : this.weight,
        waist: waist.present ? waist.value : this.waist,
        chest: chest.present ? chest.value : this.chest,
        arms: arms.present ? arms.value : this.arms,
        recordedAt: recordedAt ?? this.recordedAt,
        isSynced: isSynced ?? this.isSynced,
      );
  BodyMeasurement copyWithCompanion(BodyMeasurementsCompanion data) {
    return BodyMeasurement(
      id: data.id.present ? data.id.value : this.id,
      weight: data.weight.present ? data.weight.value : this.weight,
      waist: data.waist.present ? data.waist.value : this.waist,
      chest: data.chest.present ? data.chest.value : this.chest,
      arms: data.arms.present ? data.arms.value : this.arms,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyMeasurement(')
          ..write('id: $id, ')
          ..write('weight: $weight, ')
          ..write('waist: $waist, ')
          ..write('chest: $chest, ')
          ..write('arms: $arms, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, weight, waist, chest, arms, recordedAt, isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyMeasurement &&
          other.id == this.id &&
          other.weight == this.weight &&
          other.waist == this.waist &&
          other.chest == this.chest &&
          other.arms == this.arms &&
          other.recordedAt == this.recordedAt &&
          other.isSynced == this.isSynced);
}

class BodyMeasurementsCompanion extends UpdateCompanion<BodyMeasurement> {
  final Value<int> id;
  final Value<double?> weight;
  final Value<double?> waist;
  final Value<double?> chest;
  final Value<double?> arms;
  final Value<DateTime> recordedAt;
  final Value<bool> isSynced;
  const BodyMeasurementsCompanion({
    this.id = const Value.absent(),
    this.weight = const Value.absent(),
    this.waist = const Value.absent(),
    this.chest = const Value.absent(),
    this.arms = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  BodyMeasurementsCompanion.insert({
    this.id = const Value.absent(),
    this.weight = const Value.absent(),
    this.waist = const Value.absent(),
    this.chest = const Value.absent(),
    this.arms = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  static Insertable<BodyMeasurement> custom({
    Expression<int>? id,
    Expression<double>? weight,
    Expression<double>? waist,
    Expression<double>? chest,
    Expression<double>? arms,
    Expression<DateTime>? recordedAt,
    Expression<bool>? isSynced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weight != null) 'weight': weight,
      if (waist != null) 'waist': waist,
      if (chest != null) 'chest': chest,
      if (arms != null) 'arms': arms,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  BodyMeasurementsCompanion copyWith(
      {Value<int>? id,
      Value<double?>? weight,
      Value<double?>? waist,
      Value<double?>? chest,
      Value<double?>? arms,
      Value<DateTime>? recordedAt,
      Value<bool>? isSynced}) {
    return BodyMeasurementsCompanion(
      id: id ?? this.id,
      weight: weight ?? this.weight,
      waist: waist ?? this.waist,
      chest: chest ?? this.chest,
      arms: arms ?? this.arms,
      recordedAt: recordedAt ?? this.recordedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (waist.present) {
      map['waist'] = Variable<double>(waist.value);
    }
    if (chest.present) {
      map['chest'] = Variable<double>(chest.value);
    }
    if (arms.present) {
      map['arms'] = Variable<double>(arms.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyMeasurementsCompanion(')
          ..write('id: $id, ')
          ..write('weight: $weight, ')
          ..write('waist: $waist, ')
          ..write('chest: $chest, ')
          ..write('arms: $arms, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }
}

class $WorkoutRoutinesTable extends WorkoutRoutines
    with TableInfo<$WorkoutRoutinesTable, WorkoutRoutine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutRoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
      'goal', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, goal, notes, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_routines';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutRoutine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('goal')) {
      context.handle(
          _goalMeta, goal.isAcceptableOrUnknown(data['goal']!, _goalMeta));
    } else if (isInserting) {
      context.missing(_goalMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutRoutine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutRoutine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      goal: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $WorkoutRoutinesTable createAlias(String alias) {
    return $WorkoutRoutinesTable(attachedDatabase, alias);
  }
}

class WorkoutRoutine extends DataClass implements Insertable<WorkoutRoutine> {
  final int id;
  final String name;
  final String goal;
  final String? notes;
  final DateTime createdAt;
  const WorkoutRoutine(
      {required this.id,
      required this.name,
      required this.goal,
      this.notes,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['goal'] = Variable<String>(goal);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkoutRoutinesCompanion toCompanion(bool nullToAbsent) {
    return WorkoutRoutinesCompanion(
      id: Value(id),
      name: Value(name),
      goal: Value(goal),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutRoutine(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      goal: serializer.fromJson<String>(json['goal']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'goal': serializer.toJson<String>(goal),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkoutRoutine copyWith(
          {int? id,
          String? name,
          String? goal,
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt}) =>
      WorkoutRoutine(
        id: id ?? this.id,
        name: name ?? this.name,
        goal: goal ?? this.goal,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
  WorkoutRoutine copyWithCompanion(WorkoutRoutinesCompanion data) {
    return WorkoutRoutine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      goal: data.goal.present ? data.goal.value : this.goal,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutRoutine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goal: $goal, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, goal, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutRoutine &&
          other.id == this.id &&
          other.name == this.name &&
          other.goal == this.goal &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class WorkoutRoutinesCompanion extends UpdateCompanion<WorkoutRoutine> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> goal;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const WorkoutRoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.goal = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WorkoutRoutinesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String goal,
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : name = Value(name),
        goal = Value(goal);
  static Insertable<WorkoutRoutine> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? goal,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (goal != null) 'goal': goal,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WorkoutRoutinesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? goal,
      Value<String?>? notes,
      Value<DateTime>? createdAt}) {
    return WorkoutRoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutRoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goal: $goal, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RoutineDaysTable extends RoutineDays
    with TableInfo<$RoutineDaysTable, RoutineDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _routineIdMeta =
      const VerificationMeta('routineId');
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
      'routine_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES workout_routines (id)'));
  static const VerificationMeta _dayOfWeekMeta =
      const VerificationMeta('dayOfWeek');
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
      'day_of_week', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isRestDayMeta =
      const VerificationMeta('isRestDay');
  @override
  late final GeneratedColumn<bool> isRestDay = GeneratedColumn<bool>(
      'is_rest_day', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_rest_day" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, routineId, dayOfWeek, name, isRestDay];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_days';
  @override
  VerificationContext validateIntegrity(Insertable<RoutineDay> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('routine_id')) {
      context.handle(_routineIdMeta,
          routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta));
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
          _dayOfWeekMeta,
          dayOfWeek.isAcceptableOrUnknown(
              data['day_of_week']!, _dayOfWeekMeta));
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_rest_day')) {
      context.handle(
          _isRestDayMeta,
          isRestDay.isAcceptableOrUnknown(
              data['is_rest_day']!, _isRestDayMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineDay(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      routineId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}routine_id'])!,
      dayOfWeek: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_of_week'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      isRestDay: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_rest_day'])!,
    );
  }

  @override
  $RoutineDaysTable createAlias(String alias) {
    return $RoutineDaysTable(attachedDatabase, alias);
  }
}

class RoutineDay extends DataClass implements Insertable<RoutineDay> {
  final int id;
  final int routineId;
  final int dayOfWeek;
  final String name;
  final bool isRestDay;
  const RoutineDay(
      {required this.id,
      required this.routineId,
      required this.dayOfWeek,
      required this.name,
      required this.isRestDay});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['routine_id'] = Variable<int>(routineId);
    map['day_of_week'] = Variable<int>(dayOfWeek);
    map['name'] = Variable<String>(name);
    map['is_rest_day'] = Variable<bool>(isRestDay);
    return map;
  }

  RoutineDaysCompanion toCompanion(bool nullToAbsent) {
    return RoutineDaysCompanion(
      id: Value(id),
      routineId: Value(routineId),
      dayOfWeek: Value(dayOfWeek),
      name: Value(name),
      isRestDay: Value(isRestDay),
    );
  }

  factory RoutineDay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineDay(
      id: serializer.fromJson<int>(json['id']),
      routineId: serializer.fromJson<int>(json['routineId']),
      dayOfWeek: serializer.fromJson<int>(json['dayOfWeek']),
      name: serializer.fromJson<String>(json['name']),
      isRestDay: serializer.fromJson<bool>(json['isRestDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineId': serializer.toJson<int>(routineId),
      'dayOfWeek': serializer.toJson<int>(dayOfWeek),
      'name': serializer.toJson<String>(name),
      'isRestDay': serializer.toJson<bool>(isRestDay),
    };
  }

  RoutineDay copyWith(
          {int? id,
          int? routineId,
          int? dayOfWeek,
          String? name,
          bool? isRestDay}) =>
      RoutineDay(
        id: id ?? this.id,
        routineId: routineId ?? this.routineId,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        name: name ?? this.name,
        isRestDay: isRestDay ?? this.isRestDay,
      );
  RoutineDay copyWithCompanion(RoutineDaysCompanion data) {
    return RoutineDay(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      name: data.name.present ? data.name.value : this.name,
      isRestDay: data.isRestDay.present ? data.isRestDay.value : this.isRestDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineDay(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('name: $name, ')
          ..write('isRestDay: $isRestDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, routineId, dayOfWeek, name, isRestDay);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineDay &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.name == this.name &&
          other.isRestDay == this.isRestDay);
}

class RoutineDaysCompanion extends UpdateCompanion<RoutineDay> {
  final Value<int> id;
  final Value<int> routineId;
  final Value<int> dayOfWeek;
  final Value<String> name;
  final Value<bool> isRestDay;
  const RoutineDaysCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.name = const Value.absent(),
    this.isRestDay = const Value.absent(),
  });
  RoutineDaysCompanion.insert({
    this.id = const Value.absent(),
    required int routineId,
    required int dayOfWeek,
    required String name,
    this.isRestDay = const Value.absent(),
  })  : routineId = Value(routineId),
        dayOfWeek = Value(dayOfWeek),
        name = Value(name);
  static Insertable<RoutineDay> custom({
    Expression<int>? id,
    Expression<int>? routineId,
    Expression<int>? dayOfWeek,
    Expression<String>? name,
    Expression<bool>? isRestDay,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (name != null) 'name': name,
      if (isRestDay != null) 'is_rest_day': isRestDay,
    });
  }

  RoutineDaysCompanion copyWith(
      {Value<int>? id,
      Value<int>? routineId,
      Value<int>? dayOfWeek,
      Value<String>? name,
      Value<bool>? isRestDay}) {
    return RoutineDaysCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      name: name ?? this.name,
      isRestDay: isRestDay ?? this.isRestDay,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isRestDay.present) {
      map['is_rest_day'] = Variable<bool>(isRestDay.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineDaysCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('name: $name, ')
          ..write('isRestDay: $isRestDay')
          ..write(')'))
        .toString();
  }
}

class $RoutineExercisesTable extends RoutineExercises
    with TableInfo<$RoutineExercisesTable, RoutineExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<int> dayId = GeneratedColumn<int>(
      'day_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES routine_days (id)'));
  static const VerificationMeta _exerciseNameMeta =
      const VerificationMeta('exerciseName');
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
      'exercise_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _setsMeta = const VerificationMeta('sets');
  @override
  late final GeneratedColumn<int> sets = GeneratedColumn<int>(
      'sets', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _repsRangeMeta =
      const VerificationMeta('repsRange');
  @override
  late final GeneratedColumn<String> repsRange = GeneratedColumn<String>(
      'reps_range', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, dayId, exerciseName, sets, repsRange, orderIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_exercises';
  @override
  VerificationContext validateIntegrity(Insertable<RoutineExercise> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day_id')) {
      context.handle(
          _dayIdMeta, dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta));
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('exercise_name')) {
      context.handle(
          _exerciseNameMeta,
          exerciseName.isAcceptableOrUnknown(
              data['exercise_name']!, _exerciseNameMeta));
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('sets')) {
      context.handle(
          _setsMeta, sets.isAcceptableOrUnknown(data['sets']!, _setsMeta));
    } else if (isInserting) {
      context.missing(_setsMeta);
    }
    if (data.containsKey('reps_range')) {
      context.handle(_repsRangeMeta,
          repsRange.isAcceptableOrUnknown(data['reps_range']!, _repsRangeMeta));
    } else if (isInserting) {
      context.missing(_repsRangeMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineExercise(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      dayId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_id'])!,
      exerciseName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_name'])!,
      sets: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sets'])!,
      repsRange: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reps_range'])!,
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
    );
  }

  @override
  $RoutineExercisesTable createAlias(String alias) {
    return $RoutineExercisesTable(attachedDatabase, alias);
  }
}

class RoutineExercise extends DataClass implements Insertable<RoutineExercise> {
  final int id;
  final int dayId;
  final String exerciseName;
  final int sets;
  final String repsRange;
  final int orderIndex;
  const RoutineExercise(
      {required this.id,
      required this.dayId,
      required this.exerciseName,
      required this.sets,
      required this.repsRange,
      required this.orderIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day_id'] = Variable<int>(dayId);
    map['exercise_name'] = Variable<String>(exerciseName);
    map['sets'] = Variable<int>(sets);
    map['reps_range'] = Variable<String>(repsRange);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  RoutineExercisesCompanion toCompanion(bool nullToAbsent) {
    return RoutineExercisesCompanion(
      id: Value(id),
      dayId: Value(dayId),
      exerciseName: Value(exerciseName),
      sets: Value(sets),
      repsRange: Value(repsRange),
      orderIndex: Value(orderIndex),
    );
  }

  factory RoutineExercise.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineExercise(
      id: serializer.fromJson<int>(json['id']),
      dayId: serializer.fromJson<int>(json['dayId']),
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      sets: serializer.fromJson<int>(json['sets']),
      repsRange: serializer.fromJson<String>(json['repsRange']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dayId': serializer.toJson<int>(dayId),
      'exerciseName': serializer.toJson<String>(exerciseName),
      'sets': serializer.toJson<int>(sets),
      'repsRange': serializer.toJson<String>(repsRange),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  RoutineExercise copyWith(
          {int? id,
          int? dayId,
          String? exerciseName,
          int? sets,
          String? repsRange,
          int? orderIndex}) =>
      RoutineExercise(
        id: id ?? this.id,
        dayId: dayId ?? this.dayId,
        exerciseName: exerciseName ?? this.exerciseName,
        sets: sets ?? this.sets,
        repsRange: repsRange ?? this.repsRange,
        orderIndex: orderIndex ?? this.orderIndex,
      );
  RoutineExercise copyWithCompanion(RoutineExercisesCompanion data) {
    return RoutineExercise(
      id: data.id.present ? data.id.value : this.id,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      sets: data.sets.present ? data.sets.value : this.sets,
      repsRange: data.repsRange.present ? data.repsRange.value : this.repsRange,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercise(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('sets: $sets, ')
          ..write('repsRange: $repsRange, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dayId, exerciseName, sets, repsRange, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineExercise &&
          other.id == this.id &&
          other.dayId == this.dayId &&
          other.exerciseName == this.exerciseName &&
          other.sets == this.sets &&
          other.repsRange == this.repsRange &&
          other.orderIndex == this.orderIndex);
}

class RoutineExercisesCompanion extends UpdateCompanion<RoutineExercise> {
  final Value<int> id;
  final Value<int> dayId;
  final Value<String> exerciseName;
  final Value<int> sets;
  final Value<String> repsRange;
  final Value<int> orderIndex;
  const RoutineExercisesCompanion({
    this.id = const Value.absent(),
    this.dayId = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.sets = const Value.absent(),
    this.repsRange = const Value.absent(),
    this.orderIndex = const Value.absent(),
  });
  RoutineExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int dayId,
    required String exerciseName,
    required int sets,
    required String repsRange,
    required int orderIndex,
  })  : dayId = Value(dayId),
        exerciseName = Value(exerciseName),
        sets = Value(sets),
        repsRange = Value(repsRange),
        orderIndex = Value(orderIndex);
  static Insertable<RoutineExercise> custom({
    Expression<int>? id,
    Expression<int>? dayId,
    Expression<String>? exerciseName,
    Expression<int>? sets,
    Expression<String>? repsRange,
    Expression<int>? orderIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayId != null) 'day_id': dayId,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (sets != null) 'sets': sets,
      if (repsRange != null) 'reps_range': repsRange,
      if (orderIndex != null) 'order_index': orderIndex,
    });
  }

  RoutineExercisesCompanion copyWith(
      {Value<int>? id,
      Value<int>? dayId,
      Value<String>? exerciseName,
      Value<int>? sets,
      Value<String>? repsRange,
      Value<int>? orderIndex}) {
    return RoutineExercisesCompanion(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      repsRange: repsRange ?? this.repsRange,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<int>(dayId.value);
    }
    if (exerciseName.present) {
      map['exercise_name'] = Variable<String>(exerciseName.value);
    }
    if (sets.present) {
      map['sets'] = Variable<int>(sets.value);
    }
    if (repsRange.present) {
      map['reps_range'] = Variable<String>(repsRange.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercisesCompanion(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('sets: $sets, ')
          ..write('repsRange: $repsRange, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }
}

class $WorkoutDraftsTable extends WorkoutDrafts
    with TableInfo<$WorkoutDraftsTable, WorkoutDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _routineNameMeta =
      const VerificationMeta('routineName');
  @override
  late final GeneratedColumn<String> routineName = GeneratedColumn<String>(
      'routine_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentExerciseIndexMeta =
      const VerificationMeta('currentExerciseIndex');
  @override
  late final GeneratedColumn<int> currentExerciseIndex = GeneratedColumn<int>(
      'current_exercise_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currentSetIndexMeta =
      const VerificationMeta('currentSetIndex');
  @override
  late final GeneratedColumn<int> currentSetIndex = GeneratedColumn<int>(
      'current_set_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _elapsedSecondsMeta =
      const VerificationMeta('elapsedSeconds');
  @override
  late final GeneratedColumn<int> elapsedSeconds = GeneratedColumn<int>(
      'elapsed_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _loggedSetsJsonMeta =
      const VerificationMeta('loggedSetsJson');
  @override
  late final GeneratedColumn<String> loggedSetsJson = GeneratedColumn<String>(
      'logged_sets_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _scheduledOccurrenceIdMeta =
      const VerificationMeta('scheduledOccurrenceId');
  @override
  late final GeneratedColumn<String> scheduledOccurrenceId =
      GeneratedColumn<String>('scheduled_occurrence_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          $customConstraints: 'REFERENCES scheduled_session_occurrences(id)');
  static const VerificationMeta _executionSnapshotJsonMeta =
      const VerificationMeta('executionSnapshotJson');
  @override
  late final GeneratedColumn<String> executionSnapshotJson =
      GeneratedColumn<String>('execution_snapshot_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _draftSchemaVersionMeta =
      const VerificationMeta('draftSchemaVersion');
  @override
  late final GeneratedColumn<int> draftSchemaVersion = GeneratedColumn<int>(
      'draft_schema_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        routineName,
        currentExerciseIndex,
        currentSetIndex,
        elapsedSeconds,
        loggedSetsJson,
        updatedAt,
        scheduledOccurrenceId,
        executionSnapshotJson,
        draftSchemaVersion
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_drafts';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutDraft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('routine_name')) {
      context.handle(
          _routineNameMeta,
          routineName.isAcceptableOrUnknown(
              data['routine_name']!, _routineNameMeta));
    } else if (isInserting) {
      context.missing(_routineNameMeta);
    }
    if (data.containsKey('current_exercise_index')) {
      context.handle(
          _currentExerciseIndexMeta,
          currentExerciseIndex.isAcceptableOrUnknown(
              data['current_exercise_index']!, _currentExerciseIndexMeta));
    } else if (isInserting) {
      context.missing(_currentExerciseIndexMeta);
    }
    if (data.containsKey('current_set_index')) {
      context.handle(
          _currentSetIndexMeta,
          currentSetIndex.isAcceptableOrUnknown(
              data['current_set_index']!, _currentSetIndexMeta));
    } else if (isInserting) {
      context.missing(_currentSetIndexMeta);
    }
    if (data.containsKey('elapsed_seconds')) {
      context.handle(
          _elapsedSecondsMeta,
          elapsedSeconds.isAcceptableOrUnknown(
              data['elapsed_seconds']!, _elapsedSecondsMeta));
    } else if (isInserting) {
      context.missing(_elapsedSecondsMeta);
    }
    if (data.containsKey('logged_sets_json')) {
      context.handle(
          _loggedSetsJsonMeta,
          loggedSetsJson.isAcceptableOrUnknown(
              data['logged_sets_json']!, _loggedSetsJsonMeta));
    } else if (isInserting) {
      context.missing(_loggedSetsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('scheduled_occurrence_id')) {
      context.handle(
          _scheduledOccurrenceIdMeta,
          scheduledOccurrenceId.isAcceptableOrUnknown(
              data['scheduled_occurrence_id']!, _scheduledOccurrenceIdMeta));
    }
    if (data.containsKey('execution_snapshot_json')) {
      context.handle(
          _executionSnapshotJsonMeta,
          executionSnapshotJson.isAcceptableOrUnknown(
              data['execution_snapshot_json']!, _executionSnapshotJsonMeta));
    }
    if (data.containsKey('draft_schema_version')) {
      context.handle(
          _draftSchemaVersionMeta,
          draftSchemaVersion.isAcceptableOrUnknown(
              data['draft_schema_version']!, _draftSchemaVersionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutDraft(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      routineName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}routine_name'])!,
      currentExerciseIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_exercise_index'])!,
      currentSetIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_set_index'])!,
      elapsedSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}elapsed_seconds'])!,
      loggedSetsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}logged_sets_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      scheduledOccurrenceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scheduled_occurrence_id']),
      executionSnapshotJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}execution_snapshot_json']),
      draftSchemaVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}draft_schema_version'])!,
    );
  }

  @override
  $WorkoutDraftsTable createAlias(String alias) {
    return $WorkoutDraftsTable(attachedDatabase, alias);
  }
}

class WorkoutDraft extends DataClass implements Insertable<WorkoutDraft> {
  final int id;
  final String routineName;
  final int currentExerciseIndex;
  final int currentSetIndex;
  final int elapsedSeconds;
  final String loggedSetsJson;
  final DateTime updatedAt;
  final String? scheduledOccurrenceId;
  final String? executionSnapshotJson;
  final int draftSchemaVersion;
  const WorkoutDraft(
      {required this.id,
      required this.routineName,
      required this.currentExerciseIndex,
      required this.currentSetIndex,
      required this.elapsedSeconds,
      required this.loggedSetsJson,
      required this.updatedAt,
      this.scheduledOccurrenceId,
      this.executionSnapshotJson,
      required this.draftSchemaVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['routine_name'] = Variable<String>(routineName);
    map['current_exercise_index'] = Variable<int>(currentExerciseIndex);
    map['current_set_index'] = Variable<int>(currentSetIndex);
    map['elapsed_seconds'] = Variable<int>(elapsedSeconds);
    map['logged_sets_json'] = Variable<String>(loggedSetsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || scheduledOccurrenceId != null) {
      map['scheduled_occurrence_id'] = Variable<String>(scheduledOccurrenceId);
    }
    if (!nullToAbsent || executionSnapshotJson != null) {
      map['execution_snapshot_json'] = Variable<String>(executionSnapshotJson);
    }
    map['draft_schema_version'] = Variable<int>(draftSchemaVersion);
    return map;
  }

  WorkoutDraftsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutDraftsCompanion(
      id: Value(id),
      routineName: Value(routineName),
      currentExerciseIndex: Value(currentExerciseIndex),
      currentSetIndex: Value(currentSetIndex),
      elapsedSeconds: Value(elapsedSeconds),
      loggedSetsJson: Value(loggedSetsJson),
      updatedAt: Value(updatedAt),
      scheduledOccurrenceId: scheduledOccurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledOccurrenceId),
      executionSnapshotJson: executionSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(executionSnapshotJson),
      draftSchemaVersion: Value(draftSchemaVersion),
    );
  }

  factory WorkoutDraft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutDraft(
      id: serializer.fromJson<int>(json['id']),
      routineName: serializer.fromJson<String>(json['routineName']),
      currentExerciseIndex:
          serializer.fromJson<int>(json['currentExerciseIndex']),
      currentSetIndex: serializer.fromJson<int>(json['currentSetIndex']),
      elapsedSeconds: serializer.fromJson<int>(json['elapsedSeconds']),
      loggedSetsJson: serializer.fromJson<String>(json['loggedSetsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      scheduledOccurrenceId:
          serializer.fromJson<String?>(json['scheduledOccurrenceId']),
      executionSnapshotJson:
          serializer.fromJson<String?>(json['executionSnapshotJson']),
      draftSchemaVersion: serializer.fromJson<int>(json['draftSchemaVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineName': serializer.toJson<String>(routineName),
      'currentExerciseIndex': serializer.toJson<int>(currentExerciseIndex),
      'currentSetIndex': serializer.toJson<int>(currentSetIndex),
      'elapsedSeconds': serializer.toJson<int>(elapsedSeconds),
      'loggedSetsJson': serializer.toJson<String>(loggedSetsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'scheduledOccurrenceId':
          serializer.toJson<String?>(scheduledOccurrenceId),
      'executionSnapshotJson':
          serializer.toJson<String?>(executionSnapshotJson),
      'draftSchemaVersion': serializer.toJson<int>(draftSchemaVersion),
    };
  }

  WorkoutDraft copyWith(
          {int? id,
          String? routineName,
          int? currentExerciseIndex,
          int? currentSetIndex,
          int? elapsedSeconds,
          String? loggedSetsJson,
          DateTime? updatedAt,
          Value<String?> scheduledOccurrenceId = const Value.absent(),
          Value<String?> executionSnapshotJson = const Value.absent(),
          int? draftSchemaVersion}) =>
      WorkoutDraft(
        id: id ?? this.id,
        routineName: routineName ?? this.routineName,
        currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
        currentSetIndex: currentSetIndex ?? this.currentSetIndex,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        loggedSetsJson: loggedSetsJson ?? this.loggedSetsJson,
        updatedAt: updatedAt ?? this.updatedAt,
        scheduledOccurrenceId: scheduledOccurrenceId.present
            ? scheduledOccurrenceId.value
            : this.scheduledOccurrenceId,
        executionSnapshotJson: executionSnapshotJson.present
            ? executionSnapshotJson.value
            : this.executionSnapshotJson,
        draftSchemaVersion: draftSchemaVersion ?? this.draftSchemaVersion,
      );
  WorkoutDraft copyWithCompanion(WorkoutDraftsCompanion data) {
    return WorkoutDraft(
      id: data.id.present ? data.id.value : this.id,
      routineName:
          data.routineName.present ? data.routineName.value : this.routineName,
      currentExerciseIndex: data.currentExerciseIndex.present
          ? data.currentExerciseIndex.value
          : this.currentExerciseIndex,
      currentSetIndex: data.currentSetIndex.present
          ? data.currentSetIndex.value
          : this.currentSetIndex,
      elapsedSeconds: data.elapsedSeconds.present
          ? data.elapsedSeconds.value
          : this.elapsedSeconds,
      loggedSetsJson: data.loggedSetsJson.present
          ? data.loggedSetsJson.value
          : this.loggedSetsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      scheduledOccurrenceId: data.scheduledOccurrenceId.present
          ? data.scheduledOccurrenceId.value
          : this.scheduledOccurrenceId,
      executionSnapshotJson: data.executionSnapshotJson.present
          ? data.executionSnapshotJson.value
          : this.executionSnapshotJson,
      draftSchemaVersion: data.draftSchemaVersion.present
          ? data.draftSchemaVersion.value
          : this.draftSchemaVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDraft(')
          ..write('id: $id, ')
          ..write('routineName: $routineName, ')
          ..write('currentExerciseIndex: $currentExerciseIndex, ')
          ..write('currentSetIndex: $currentSetIndex, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('loggedSetsJson: $loggedSetsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scheduledOccurrenceId: $scheduledOccurrenceId, ')
          ..write('executionSnapshotJson: $executionSnapshotJson, ')
          ..write('draftSchemaVersion: $draftSchemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      routineName,
      currentExerciseIndex,
      currentSetIndex,
      elapsedSeconds,
      loggedSetsJson,
      updatedAt,
      scheduledOccurrenceId,
      executionSnapshotJson,
      draftSchemaVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutDraft &&
          other.id == this.id &&
          other.routineName == this.routineName &&
          other.currentExerciseIndex == this.currentExerciseIndex &&
          other.currentSetIndex == this.currentSetIndex &&
          other.elapsedSeconds == this.elapsedSeconds &&
          other.loggedSetsJson == this.loggedSetsJson &&
          other.updatedAt == this.updatedAt &&
          other.scheduledOccurrenceId == this.scheduledOccurrenceId &&
          other.executionSnapshotJson == this.executionSnapshotJson &&
          other.draftSchemaVersion == this.draftSchemaVersion);
}

class WorkoutDraftsCompanion extends UpdateCompanion<WorkoutDraft> {
  final Value<int> id;
  final Value<String> routineName;
  final Value<int> currentExerciseIndex;
  final Value<int> currentSetIndex;
  final Value<int> elapsedSeconds;
  final Value<String> loggedSetsJson;
  final Value<DateTime> updatedAt;
  final Value<String?> scheduledOccurrenceId;
  final Value<String?> executionSnapshotJson;
  final Value<int> draftSchemaVersion;
  const WorkoutDraftsCompanion({
    this.id = const Value.absent(),
    this.routineName = const Value.absent(),
    this.currentExerciseIndex = const Value.absent(),
    this.currentSetIndex = const Value.absent(),
    this.elapsedSeconds = const Value.absent(),
    this.loggedSetsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.scheduledOccurrenceId = const Value.absent(),
    this.executionSnapshotJson = const Value.absent(),
    this.draftSchemaVersion = const Value.absent(),
  });
  WorkoutDraftsCompanion.insert({
    this.id = const Value.absent(),
    required String routineName,
    required int currentExerciseIndex,
    required int currentSetIndex,
    required int elapsedSeconds,
    required String loggedSetsJson,
    this.updatedAt = const Value.absent(),
    this.scheduledOccurrenceId = const Value.absent(),
    this.executionSnapshotJson = const Value.absent(),
    this.draftSchemaVersion = const Value.absent(),
  })  : routineName = Value(routineName),
        currentExerciseIndex = Value(currentExerciseIndex),
        currentSetIndex = Value(currentSetIndex),
        elapsedSeconds = Value(elapsedSeconds),
        loggedSetsJson = Value(loggedSetsJson);
  static Insertable<WorkoutDraft> custom({
    Expression<int>? id,
    Expression<String>? routineName,
    Expression<int>? currentExerciseIndex,
    Expression<int>? currentSetIndex,
    Expression<int>? elapsedSeconds,
    Expression<String>? loggedSetsJson,
    Expression<DateTime>? updatedAt,
    Expression<String>? scheduledOccurrenceId,
    Expression<String>? executionSnapshotJson,
    Expression<int>? draftSchemaVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineName != null) 'routine_name': routineName,
      if (currentExerciseIndex != null)
        'current_exercise_index': currentExerciseIndex,
      if (currentSetIndex != null) 'current_set_index': currentSetIndex,
      if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
      if (loggedSetsJson != null) 'logged_sets_json': loggedSetsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (scheduledOccurrenceId != null)
        'scheduled_occurrence_id': scheduledOccurrenceId,
      if (executionSnapshotJson != null)
        'execution_snapshot_json': executionSnapshotJson,
      if (draftSchemaVersion != null)
        'draft_schema_version': draftSchemaVersion,
    });
  }

  WorkoutDraftsCompanion copyWith(
      {Value<int>? id,
      Value<String>? routineName,
      Value<int>? currentExerciseIndex,
      Value<int>? currentSetIndex,
      Value<int>? elapsedSeconds,
      Value<String>? loggedSetsJson,
      Value<DateTime>? updatedAt,
      Value<String?>? scheduledOccurrenceId,
      Value<String?>? executionSnapshotJson,
      Value<int>? draftSchemaVersion}) {
    return WorkoutDraftsCompanion(
      id: id ?? this.id,
      routineName: routineName ?? this.routineName,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      currentSetIndex: currentSetIndex ?? this.currentSetIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      loggedSetsJson: loggedSetsJson ?? this.loggedSetsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledOccurrenceId:
          scheduledOccurrenceId ?? this.scheduledOccurrenceId,
      executionSnapshotJson:
          executionSnapshotJson ?? this.executionSnapshotJson,
      draftSchemaVersion: draftSchemaVersion ?? this.draftSchemaVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (routineName.present) {
      map['routine_name'] = Variable<String>(routineName.value);
    }
    if (currentExerciseIndex.present) {
      map['current_exercise_index'] = Variable<int>(currentExerciseIndex.value);
    }
    if (currentSetIndex.present) {
      map['current_set_index'] = Variable<int>(currentSetIndex.value);
    }
    if (elapsedSeconds.present) {
      map['elapsed_seconds'] = Variable<int>(elapsedSeconds.value);
    }
    if (loggedSetsJson.present) {
      map['logged_sets_json'] = Variable<String>(loggedSetsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (scheduledOccurrenceId.present) {
      map['scheduled_occurrence_id'] =
          Variable<String>(scheduledOccurrenceId.value);
    }
    if (executionSnapshotJson.present) {
      map['execution_snapshot_json'] =
          Variable<String>(executionSnapshotJson.value);
    }
    if (draftSchemaVersion.present) {
      map['draft_schema_version'] = Variable<int>(draftSchemaVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDraftsCompanion(')
          ..write('id: $id, ')
          ..write('routineName: $routineName, ')
          ..write('currentExerciseIndex: $currentExerciseIndex, ')
          ..write('currentSetIndex: $currentSetIndex, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('loggedSetsJson: $loggedSetsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scheduledOccurrenceId: $scheduledOccurrenceId, ')
          ..write('executionSnapshotJson: $executionSnapshotJson, ')
          ..write('draftSchemaVersion: $draftSchemaVersion')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
      'age', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(25));
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
      'height', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(170.0));
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
      'weight', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(70.0));
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
      'sex', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('male'));
  static const VerificationMeta _activityLevelMeta =
      const VerificationMeta('activityLevel');
  @override
  late final GeneratedColumn<String> activityLevel = GeneratedColumn<String>(
      'activity_level', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('moderate'));
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
      'goal', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('maintain'));
  static const VerificationMeta _dietPreferenceMeta =
      const VerificationMeta('dietPreference');
  @override
  late final GeneratedColumn<String> dietPreference = GeneratedColumn<String>(
      'diet_preference', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('balanced'));
  static const VerificationMeta _calorieGoalMeta =
      const VerificationMeta('calorieGoal');
  @override
  late final GeneratedColumn<int> calorieGoal = GeneratedColumn<int>(
      'calorie_goal', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(2000));
  static const VerificationMeta _proteinGoalMeta =
      const VerificationMeta('proteinGoal');
  @override
  late final GeneratedColumn<double> proteinGoal = GeneratedColumn<double>(
      'protein_goal', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(140.0));
  static const VerificationMeta _carbsGoalMeta =
      const VerificationMeta('carbsGoal');
  @override
  late final GeneratedColumn<double> carbsGoal = GeneratedColumn<double>(
      'carbs_goal', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(220.0));
  static const VerificationMeta _fatGoalMeta =
      const VerificationMeta('fatGoal');
  @override
  late final GeneratedColumn<double> fatGoal = GeneratedColumn<double>(
      'fat_goal', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(60.0));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _equipmentAccessMeta =
      const VerificationMeta('equipmentAccess');
  @override
  late final GeneratedColumn<String> equipmentAccess = GeneratedColumn<String>(
      'equipment_access', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('full_gym'));
  static const VerificationMeta _injuriesLimitationsMeta =
      const VerificationMeta('injuriesLimitations');
  @override
  late final GeneratedColumn<String> injuriesLimitations =
      GeneratedColumn<String>('injuries_limitations', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant(''));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        age,
        height,
        weight,
        sex,
        activityLevel,
        goal,
        dietPreference,
        calorieGoal,
        proteinGoal,
        carbsGoal,
        fatGoal,
        name,
        equipmentAccess,
        injuriesLimitations,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('age')) {
      context.handle(
          _ageMeta, age.isAcceptableOrUnknown(data['age']!, _ageMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('sex')) {
      context.handle(
          _sexMeta, sex.isAcceptableOrUnknown(data['sex']!, _sexMeta));
    }
    if (data.containsKey('activity_level')) {
      context.handle(
          _activityLevelMeta,
          activityLevel.isAcceptableOrUnknown(
              data['activity_level']!, _activityLevelMeta));
    }
    if (data.containsKey('goal')) {
      context.handle(
          _goalMeta, goal.isAcceptableOrUnknown(data['goal']!, _goalMeta));
    }
    if (data.containsKey('diet_preference')) {
      context.handle(
          _dietPreferenceMeta,
          dietPreference.isAcceptableOrUnknown(
              data['diet_preference']!, _dietPreferenceMeta));
    }
    if (data.containsKey('calorie_goal')) {
      context.handle(
          _calorieGoalMeta,
          calorieGoal.isAcceptableOrUnknown(
              data['calorie_goal']!, _calorieGoalMeta));
    }
    if (data.containsKey('protein_goal')) {
      context.handle(
          _proteinGoalMeta,
          proteinGoal.isAcceptableOrUnknown(
              data['protein_goal']!, _proteinGoalMeta));
    }
    if (data.containsKey('carbs_goal')) {
      context.handle(_carbsGoalMeta,
          carbsGoal.isAcceptableOrUnknown(data['carbs_goal']!, _carbsGoalMeta));
    }
    if (data.containsKey('fat_goal')) {
      context.handle(_fatGoalMeta,
          fatGoal.isAcceptableOrUnknown(data['fat_goal']!, _fatGoalMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('equipment_access')) {
      context.handle(
          _equipmentAccessMeta,
          equipmentAccess.isAcceptableOrUnknown(
              data['equipment_access']!, _equipmentAccessMeta));
    }
    if (data.containsKey('injuries_limitations')) {
      context.handle(
          _injuriesLimitationsMeta,
          injuriesLimitations.isAcceptableOrUnknown(
              data['injuries_limitations']!, _injuriesLimitationsMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      age: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}age'])!,
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}height'])!,
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight'])!,
      sex: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sex'])!,
      activityLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}activity_level'])!,
      goal: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal'])!,
      dietPreference: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}diet_preference'])!,
      calorieGoal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calorie_goal'])!,
      proteinGoal: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}protein_goal'])!,
      carbsGoal: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_goal'])!,
      fatGoal: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fat_goal'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      equipmentAccess: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}equipment_access'])!,
      injuriesLimitations: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}injuries_limitations'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final int age;
  final double height;
  final double weight;
  final String sex;
  final String activityLevel;
  final String goal;
  final String dietPreference;
  final int calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final String name;
  final String equipmentAccess;
  final String injuriesLimitations;
  final DateTime updatedAt;
  const UserProfile(
      {required this.id,
      required this.age,
      required this.height,
      required this.weight,
      required this.sex,
      required this.activityLevel,
      required this.goal,
      required this.dietPreference,
      required this.calorieGoal,
      required this.proteinGoal,
      required this.carbsGoal,
      required this.fatGoal,
      required this.name,
      required this.equipmentAccess,
      required this.injuriesLimitations,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['age'] = Variable<int>(age);
    map['height'] = Variable<double>(height);
    map['weight'] = Variable<double>(weight);
    map['sex'] = Variable<String>(sex);
    map['activity_level'] = Variable<String>(activityLevel);
    map['goal'] = Variable<String>(goal);
    map['diet_preference'] = Variable<String>(dietPreference);
    map['calorie_goal'] = Variable<int>(calorieGoal);
    map['protein_goal'] = Variable<double>(proteinGoal);
    map['carbs_goal'] = Variable<double>(carbsGoal);
    map['fat_goal'] = Variable<double>(fatGoal);
    map['name'] = Variable<String>(name);
    map['equipment_access'] = Variable<String>(equipmentAccess);
    map['injuries_limitations'] = Variable<String>(injuriesLimitations);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      age: Value(age),
      height: Value(height),
      weight: Value(weight),
      sex: Value(sex),
      activityLevel: Value(activityLevel),
      goal: Value(goal),
      dietPreference: Value(dietPreference),
      calorieGoal: Value(calorieGoal),
      proteinGoal: Value(proteinGoal),
      carbsGoal: Value(carbsGoal),
      fatGoal: Value(fatGoal),
      name: Value(name),
      equipmentAccess: Value(equipmentAccess),
      injuriesLimitations: Value(injuriesLimitations),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      age: serializer.fromJson<int>(json['age']),
      height: serializer.fromJson<double>(json['height']),
      weight: serializer.fromJson<double>(json['weight']),
      sex: serializer.fromJson<String>(json['sex']),
      activityLevel: serializer.fromJson<String>(json['activityLevel']),
      goal: serializer.fromJson<String>(json['goal']),
      dietPreference: serializer.fromJson<String>(json['dietPreference']),
      calorieGoal: serializer.fromJson<int>(json['calorieGoal']),
      proteinGoal: serializer.fromJson<double>(json['proteinGoal']),
      carbsGoal: serializer.fromJson<double>(json['carbsGoal']),
      fatGoal: serializer.fromJson<double>(json['fatGoal']),
      name: serializer.fromJson<String>(json['name']),
      equipmentAccess: serializer.fromJson<String>(json['equipmentAccess']),
      injuriesLimitations:
          serializer.fromJson<String>(json['injuriesLimitations']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'age': serializer.toJson<int>(age),
      'height': serializer.toJson<double>(height),
      'weight': serializer.toJson<double>(weight),
      'sex': serializer.toJson<String>(sex),
      'activityLevel': serializer.toJson<String>(activityLevel),
      'goal': serializer.toJson<String>(goal),
      'dietPreference': serializer.toJson<String>(dietPreference),
      'calorieGoal': serializer.toJson<int>(calorieGoal),
      'proteinGoal': serializer.toJson<double>(proteinGoal),
      'carbsGoal': serializer.toJson<double>(carbsGoal),
      'fatGoal': serializer.toJson<double>(fatGoal),
      'name': serializer.toJson<String>(name),
      'equipmentAccess': serializer.toJson<String>(equipmentAccess),
      'injuriesLimitations': serializer.toJson<String>(injuriesLimitations),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfile copyWith(
          {int? id,
          int? age,
          double? height,
          double? weight,
          String? sex,
          String? activityLevel,
          String? goal,
          String? dietPreference,
          int? calorieGoal,
          double? proteinGoal,
          double? carbsGoal,
          double? fatGoal,
          String? name,
          String? equipmentAccess,
          String? injuriesLimitations,
          DateTime? updatedAt}) =>
      UserProfile(
        id: id ?? this.id,
        age: age ?? this.age,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        sex: sex ?? this.sex,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        dietPreference: dietPreference ?? this.dietPreference,
        calorieGoal: calorieGoal ?? this.calorieGoal,
        proteinGoal: proteinGoal ?? this.proteinGoal,
        carbsGoal: carbsGoal ?? this.carbsGoal,
        fatGoal: fatGoal ?? this.fatGoal,
        name: name ?? this.name,
        equipmentAccess: equipmentAccess ?? this.equipmentAccess,
        injuriesLimitations: injuriesLimitations ?? this.injuriesLimitations,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      age: data.age.present ? data.age.value : this.age,
      height: data.height.present ? data.height.value : this.height,
      weight: data.weight.present ? data.weight.value : this.weight,
      sex: data.sex.present ? data.sex.value : this.sex,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      goal: data.goal.present ? data.goal.value : this.goal,
      dietPreference: data.dietPreference.present
          ? data.dietPreference.value
          : this.dietPreference,
      calorieGoal:
          data.calorieGoal.present ? data.calorieGoal.value : this.calorieGoal,
      proteinGoal:
          data.proteinGoal.present ? data.proteinGoal.value : this.proteinGoal,
      carbsGoal: data.carbsGoal.present ? data.carbsGoal.value : this.carbsGoal,
      fatGoal: data.fatGoal.present ? data.fatGoal.value : this.fatGoal,
      name: data.name.present ? data.name.value : this.name,
      equipmentAccess: data.equipmentAccess.present
          ? data.equipmentAccess.value
          : this.equipmentAccess,
      injuriesLimitations: data.injuriesLimitations.present
          ? data.injuriesLimitations.value
          : this.injuriesLimitations,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('age: $age, ')
          ..write('height: $height, ')
          ..write('weight: $weight, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goal: $goal, ')
          ..write('dietPreference: $dietPreference, ')
          ..write('calorieGoal: $calorieGoal, ')
          ..write('proteinGoal: $proteinGoal, ')
          ..write('carbsGoal: $carbsGoal, ')
          ..write('fatGoal: $fatGoal, ')
          ..write('name: $name, ')
          ..write('equipmentAccess: $equipmentAccess, ')
          ..write('injuriesLimitations: $injuriesLimitations, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      age,
      height,
      weight,
      sex,
      activityLevel,
      goal,
      dietPreference,
      calorieGoal,
      proteinGoal,
      carbsGoal,
      fatGoal,
      name,
      equipmentAccess,
      injuriesLimitations,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.age == this.age &&
          other.height == this.height &&
          other.weight == this.weight &&
          other.sex == this.sex &&
          other.activityLevel == this.activityLevel &&
          other.goal == this.goal &&
          other.dietPreference == this.dietPreference &&
          other.calorieGoal == this.calorieGoal &&
          other.proteinGoal == this.proteinGoal &&
          other.carbsGoal == this.carbsGoal &&
          other.fatGoal == this.fatGoal &&
          other.name == this.name &&
          other.equipmentAccess == this.equipmentAccess &&
          other.injuriesLimitations == this.injuriesLimitations &&
          other.updatedAt == this.updatedAt);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<int> age;
  final Value<double> height;
  final Value<double> weight;
  final Value<String> sex;
  final Value<String> activityLevel;
  final Value<String> goal;
  final Value<String> dietPreference;
  final Value<int> calorieGoal;
  final Value<double> proteinGoal;
  final Value<double> carbsGoal;
  final Value<double> fatGoal;
  final Value<String> name;
  final Value<String> equipmentAccess;
  final Value<String> injuriesLimitations;
  final Value<DateTime> updatedAt;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.age = const Value.absent(),
    this.height = const Value.absent(),
    this.weight = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.goal = const Value.absent(),
    this.dietPreference = const Value.absent(),
    this.calorieGoal = const Value.absent(),
    this.proteinGoal = const Value.absent(),
    this.carbsGoal = const Value.absent(),
    this.fatGoal = const Value.absent(),
    this.name = const Value.absent(),
    this.equipmentAccess = const Value.absent(),
    this.injuriesLimitations = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.age = const Value.absent(),
    this.height = const Value.absent(),
    this.weight = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.goal = const Value.absent(),
    this.dietPreference = const Value.absent(),
    this.calorieGoal = const Value.absent(),
    this.proteinGoal = const Value.absent(),
    this.carbsGoal = const Value.absent(),
    this.fatGoal = const Value.absent(),
    this.name = const Value.absent(),
    this.equipmentAccess = const Value.absent(),
    this.injuriesLimitations = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<int>? age,
    Expression<double>? height,
    Expression<double>? weight,
    Expression<String>? sex,
    Expression<String>? activityLevel,
    Expression<String>? goal,
    Expression<String>? dietPreference,
    Expression<int>? calorieGoal,
    Expression<double>? proteinGoal,
    Expression<double>? carbsGoal,
    Expression<double>? fatGoal,
    Expression<String>? name,
    Expression<String>? equipmentAccess,
    Expression<String>? injuriesLimitations,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (age != null) 'age': age,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (sex != null) 'sex': sex,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (goal != null) 'goal': goal,
      if (dietPreference != null) 'diet_preference': dietPreference,
      if (calorieGoal != null) 'calorie_goal': calorieGoal,
      if (proteinGoal != null) 'protein_goal': proteinGoal,
      if (carbsGoal != null) 'carbs_goal': carbsGoal,
      if (fatGoal != null) 'fat_goal': fatGoal,
      if (name != null) 'name': name,
      if (equipmentAccess != null) 'equipment_access': equipmentAccess,
      if (injuriesLimitations != null)
        'injuries_limitations': injuriesLimitations,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserProfilesCompanion copyWith(
      {Value<int>? id,
      Value<int>? age,
      Value<double>? height,
      Value<double>? weight,
      Value<String>? sex,
      Value<String>? activityLevel,
      Value<String>? goal,
      Value<String>? dietPreference,
      Value<int>? calorieGoal,
      Value<double>? proteinGoal,
      Value<double>? carbsGoal,
      Value<double>? fatGoal,
      Value<String>? name,
      Value<String>? equipmentAccess,
      Value<String>? injuriesLimitations,
      Value<DateTime>? updatedAt}) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      dietPreference: dietPreference ?? this.dietPreference,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      name: name ?? this.name,
      equipmentAccess: equipmentAccess ?? this.equipmentAccess,
      injuriesLimitations: injuriesLimitations ?? this.injuriesLimitations,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<String>(activityLevel.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (dietPreference.present) {
      map['diet_preference'] = Variable<String>(dietPreference.value);
    }
    if (calorieGoal.present) {
      map['calorie_goal'] = Variable<int>(calorieGoal.value);
    }
    if (proteinGoal.present) {
      map['protein_goal'] = Variable<double>(proteinGoal.value);
    }
    if (carbsGoal.present) {
      map['carbs_goal'] = Variable<double>(carbsGoal.value);
    }
    if (fatGoal.present) {
      map['fat_goal'] = Variable<double>(fatGoal.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (equipmentAccess.present) {
      map['equipment_access'] = Variable<String>(equipmentAccess.value);
    }
    if (injuriesLimitations.present) {
      map['injuries_limitations'] = Variable<String>(injuriesLimitations.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('age: $age, ')
          ..write('height: $height, ')
          ..write('weight: $weight, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goal: $goal, ')
          ..write('dietPreference: $dietPreference, ')
          ..write('calorieGoal: $calorieGoal, ')
          ..write('proteinGoal: $proteinGoal, ')
          ..write('carbsGoal: $carbsGoal, ')
          ..write('fatGoal: $fatGoal, ')
          ..write('name: $name, ')
          ..write('equipmentAccess: $equipmentAccess, ')
          ..write('injuriesLimitations: $injuriesLimitations, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MealTemplatesTable extends MealTemplates
    with TableInfo<$MealTemplatesTable, MealTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _defaultMealTypeMeta =
      const VerificationMeta('defaultMealType');
  @override
  late final GeneratedColumn<String> defaultMealType = GeneratedColumn<String>(
      'default_meal_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('breakfast'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, defaultMealType, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_templates';
  @override
  VerificationContext validateIntegrity(Insertable<MealTemplate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('default_meal_type')) {
      context.handle(
          _defaultMealTypeMeta,
          defaultMealType.isAcceptableOrUnknown(
              data['default_meal_type']!, _defaultMealTypeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealTemplate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      defaultMealType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}default_meal_type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MealTemplatesTable createAlias(String alias) {
    return $MealTemplatesTable(attachedDatabase, alias);
  }
}

class MealTemplate extends DataClass implements Insertable<MealTemplate> {
  final int id;
  final String name;
  final String defaultMealType;
  final DateTime createdAt;
  const MealTemplate(
      {required this.id,
      required this.name,
      required this.defaultMealType,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['default_meal_type'] = Variable<String>(defaultMealType);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MealTemplatesCompanion toCompanion(bool nullToAbsent) {
    return MealTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      defaultMealType: Value(defaultMealType),
      createdAt: Value(createdAt),
    );
  }

  factory MealTemplate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealTemplate(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      defaultMealType: serializer.fromJson<String>(json['defaultMealType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'defaultMealType': serializer.toJson<String>(defaultMealType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MealTemplate copyWith(
          {int? id,
          String? name,
          String? defaultMealType,
          DateTime? createdAt}) =>
      MealTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        defaultMealType: defaultMealType ?? this.defaultMealType,
        createdAt: createdAt ?? this.createdAt,
      );
  MealTemplate copyWithCompanion(MealTemplatesCompanion data) {
    return MealTemplate(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      defaultMealType: data.defaultMealType.present
          ? data.defaultMealType.value
          : this.defaultMealType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealTemplate(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('defaultMealType: $defaultMealType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, defaultMealType, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealTemplate &&
          other.id == this.id &&
          other.name == this.name &&
          other.defaultMealType == this.defaultMealType &&
          other.createdAt == this.createdAt);
}

class MealTemplatesCompanion extends UpdateCompanion<MealTemplate> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> defaultMealType;
  final Value<DateTime> createdAt;
  const MealTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.defaultMealType = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MealTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.defaultMealType = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<MealTemplate> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? defaultMealType,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (defaultMealType != null) 'default_meal_type': defaultMealType,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MealTemplatesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? defaultMealType,
      Value<DateTime>? createdAt}) {
    return MealTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultMealType: defaultMealType ?? this.defaultMealType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (defaultMealType.present) {
      map['default_meal_type'] = Variable<String>(defaultMealType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('defaultMealType: $defaultMealType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MealTemplateItemsTable extends MealTemplateItems
    with TableInfo<$MealTemplateItemsTable, MealTemplateItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealTemplateItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _templateIdMeta =
      const VerificationMeta('templateId');
  @override
  late final GeneratedColumn<int> templateId = GeneratedColumn<int>(
      'template_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES meal_templates (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _caloriesMeta =
      const VerificationMeta('calories');
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
      'calories', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _proteinGMeta =
      const VerificationMeta('proteinG');
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
      'protein_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _carbsGMeta = const VerificationMeta('carbsG');
  @override
  late final GeneratedColumn<double> carbsG = GeneratedColumn<double>(
      'carbs_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
      'fat_g', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _servingLoggedMeta =
      const VerificationMeta('servingLogged');
  @override
  late final GeneratedColumn<double> servingLogged = GeneratedColumn<double>(
      'serving_logged', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _servingUnitMeta =
      const VerificationMeta('servingUnit');
  @override
  late final GeneratedColumn<String> servingUnit = GeneratedColumn<String>(
      'serving_unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        templateId,
        name,
        calories,
        proteinG,
        carbsG,
        fatG,
        servingLogged,
        servingUnit
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_template_items';
  @override
  VerificationContext validateIntegrity(Insertable<MealTemplateItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('template_id')) {
      context.handle(
          _templateIdMeta,
          templateId.isAcceptableOrUnknown(
              data['template_id']!, _templateIdMeta));
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(_caloriesMeta,
          calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta));
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(_proteinGMeta,
          proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta));
    } else if (isInserting) {
      context.missing(_proteinGMeta);
    }
    if (data.containsKey('carbs_g')) {
      context.handle(_carbsGMeta,
          carbsG.isAcceptableOrUnknown(data['carbs_g']!, _carbsGMeta));
    } else if (isInserting) {
      context.missing(_carbsGMeta);
    }
    if (data.containsKey('fat_g')) {
      context.handle(
          _fatGMeta, fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta));
    } else if (isInserting) {
      context.missing(_fatGMeta);
    }
    if (data.containsKey('serving_logged')) {
      context.handle(
          _servingLoggedMeta,
          servingLogged.isAcceptableOrUnknown(
              data['serving_logged']!, _servingLoggedMeta));
    } else if (isInserting) {
      context.missing(_servingLoggedMeta);
    }
    if (data.containsKey('serving_unit')) {
      context.handle(
          _servingUnitMeta,
          servingUnit.isAcceptableOrUnknown(
              data['serving_unit']!, _servingUnitMeta));
    } else if (isInserting) {
      context.missing(_servingUnitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealTemplateItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealTemplateItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      templateId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}template_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      calories: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calories'])!,
      proteinG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}protein_g'])!,
      carbsG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_g'])!,
      fatG: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fat_g'])!,
      servingLogged: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}serving_logged'])!,
      servingUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serving_unit'])!,
    );
  }

  @override
  $MealTemplateItemsTable createAlias(String alias) {
    return $MealTemplateItemsTable(attachedDatabase, alias);
  }
}

class MealTemplateItem extends DataClass
    implements Insertable<MealTemplateItem> {
  final int id;
  final int templateId;
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingLogged;
  final String servingUnit;
  const MealTemplateItem(
      {required this.id,
      required this.templateId,
      required this.name,
      required this.calories,
      required this.proteinG,
      required this.carbsG,
      required this.fatG,
      required this.servingLogged,
      required this.servingUnit});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['template_id'] = Variable<int>(templateId);
    map['name'] = Variable<String>(name);
    map['calories'] = Variable<int>(calories);
    map['protein_g'] = Variable<double>(proteinG);
    map['carbs_g'] = Variable<double>(carbsG);
    map['fat_g'] = Variable<double>(fatG);
    map['serving_logged'] = Variable<double>(servingLogged);
    map['serving_unit'] = Variable<String>(servingUnit);
    return map;
  }

  MealTemplateItemsCompanion toCompanion(bool nullToAbsent) {
    return MealTemplateItemsCompanion(
      id: Value(id),
      templateId: Value(templateId),
      name: Value(name),
      calories: Value(calories),
      proteinG: Value(proteinG),
      carbsG: Value(carbsG),
      fatG: Value(fatG),
      servingLogged: Value(servingLogged),
      servingUnit: Value(servingUnit),
    );
  }

  factory MealTemplateItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealTemplateItem(
      id: serializer.fromJson<int>(json['id']),
      templateId: serializer.fromJson<int>(json['templateId']),
      name: serializer.fromJson<String>(json['name']),
      calories: serializer.fromJson<int>(json['calories']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      carbsG: serializer.fromJson<double>(json['carbsG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      servingLogged: serializer.fromJson<double>(json['servingLogged']),
      servingUnit: serializer.fromJson<String>(json['servingUnit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'templateId': serializer.toJson<int>(templateId),
      'name': serializer.toJson<String>(name),
      'calories': serializer.toJson<int>(calories),
      'proteinG': serializer.toJson<double>(proteinG),
      'carbsG': serializer.toJson<double>(carbsG),
      'fatG': serializer.toJson<double>(fatG),
      'servingLogged': serializer.toJson<double>(servingLogged),
      'servingUnit': serializer.toJson<String>(servingUnit),
    };
  }

  MealTemplateItem copyWith(
          {int? id,
          int? templateId,
          String? name,
          int? calories,
          double? proteinG,
          double? carbsG,
          double? fatG,
          double? servingLogged,
          String? servingUnit}) =>
      MealTemplateItem(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        name: name ?? this.name,
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        servingLogged: servingLogged ?? this.servingLogged,
        servingUnit: servingUnit ?? this.servingUnit,
      );
  MealTemplateItem copyWithCompanion(MealTemplateItemsCompanion data) {
    return MealTemplateItem(
      id: data.id.present ? data.id.value : this.id,
      templateId:
          data.templateId.present ? data.templateId.value : this.templateId,
      name: data.name.present ? data.name.value : this.name,
      calories: data.calories.present ? data.calories.value : this.calories,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      carbsG: data.carbsG.present ? data.carbsG.value : this.carbsG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      servingLogged: data.servingLogged.present
          ? data.servingLogged.value
          : this.servingLogged,
      servingUnit:
          data.servingUnit.present ? data.servingUnit.value : this.servingUnit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealTemplateItem(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('fatG: $fatG, ')
          ..write('servingLogged: $servingLogged, ')
          ..write('servingUnit: $servingUnit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, templateId, name, calories, proteinG,
      carbsG, fatG, servingLogged, servingUnit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealTemplateItem &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.name == this.name &&
          other.calories == this.calories &&
          other.proteinG == this.proteinG &&
          other.carbsG == this.carbsG &&
          other.fatG == this.fatG &&
          other.servingLogged == this.servingLogged &&
          other.servingUnit == this.servingUnit);
}

class MealTemplateItemsCompanion extends UpdateCompanion<MealTemplateItem> {
  final Value<int> id;
  final Value<int> templateId;
  final Value<String> name;
  final Value<int> calories;
  final Value<double> proteinG;
  final Value<double> carbsG;
  final Value<double> fatG;
  final Value<double> servingLogged;
  final Value<String> servingUnit;
  const MealTemplateItemsCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.name = const Value.absent(),
    this.calories = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.carbsG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.servingLogged = const Value.absent(),
    this.servingUnit = const Value.absent(),
  });
  MealTemplateItemsCompanion.insert({
    this.id = const Value.absent(),
    required int templateId,
    required String name,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double servingLogged,
    required String servingUnit,
  })  : templateId = Value(templateId),
        name = Value(name),
        calories = Value(calories),
        proteinG = Value(proteinG),
        carbsG = Value(carbsG),
        fatG = Value(fatG),
        servingLogged = Value(servingLogged),
        servingUnit = Value(servingUnit);
  static Insertable<MealTemplateItem> custom({
    Expression<int>? id,
    Expression<int>? templateId,
    Expression<String>? name,
    Expression<int>? calories,
    Expression<double>? proteinG,
    Expression<double>? carbsG,
    Expression<double>? fatG,
    Expression<double>? servingLogged,
    Expression<String>? servingUnit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (name != null) 'name': name,
      if (calories != null) 'calories': calories,
      if (proteinG != null) 'protein_g': proteinG,
      if (carbsG != null) 'carbs_g': carbsG,
      if (fatG != null) 'fat_g': fatG,
      if (servingLogged != null) 'serving_logged': servingLogged,
      if (servingUnit != null) 'serving_unit': servingUnit,
    });
  }

  MealTemplateItemsCompanion copyWith(
      {Value<int>? id,
      Value<int>? templateId,
      Value<String>? name,
      Value<int>? calories,
      Value<double>? proteinG,
      Value<double>? carbsG,
      Value<double>? fatG,
      Value<double>? servingLogged,
      Value<String>? servingUnit}) {
    return MealTemplateItemsCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      servingLogged: servingLogged ?? this.servingLogged,
      servingUnit: servingUnit ?? this.servingUnit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<int>(templateId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (carbsG.present) {
      map['carbs_g'] = Variable<double>(carbsG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (servingLogged.present) {
      map['serving_logged'] = Variable<double>(servingLogged.value);
    }
    if (servingUnit.present) {
      map['serving_unit'] = Variable<String>(servingUnit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealTemplateItemsCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbsG: $carbsG, ')
          ..write('fatG: $fatG, ')
          ..write('servingLogged: $servingLogged, ')
          ..write('servingUnit: $servingUnit')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(Insertable<UserSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const UserSetting(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      UserSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<UserSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return UserSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyHydrationsTable extends DailyHydrations
    with TableInfo<$DailyHydrationsTable, DailyHydration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyHydrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dateStringMeta =
      const VerificationMeta('dateString');
  @override
  late final GeneratedColumn<String> dateString = GeneratedColumn<String>(
      'date_string', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _totalMlMeta =
      const VerificationMeta('totalMl');
  @override
  late final GeneratedColumn<int> totalMl = GeneratedColumn<int>(
      'total_ml', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _goalMlMeta = const VerificationMeta('goalMl');
  @override
  late final GeneratedColumn<int> goalMl = GeneratedColumn<int>(
      'goal_ml', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, dateString, totalMl, goalMl, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_hydrations';
  @override
  VerificationContext validateIntegrity(Insertable<DailyHydration> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_string')) {
      context.handle(
          _dateStringMeta,
          dateString.isAcceptableOrUnknown(
              data['date_string']!, _dateStringMeta));
    } else if (isInserting) {
      context.missing(_dateStringMeta);
    }
    if (data.containsKey('total_ml')) {
      context.handle(_totalMlMeta,
          totalMl.isAcceptableOrUnknown(data['total_ml']!, _totalMlMeta));
    } else if (isInserting) {
      context.missing(_totalMlMeta);
    }
    if (data.containsKey('goal_ml')) {
      context.handle(_goalMlMeta,
          goalMl.isAcceptableOrUnknown(data['goal_ml']!, _goalMlMeta));
    } else if (isInserting) {
      context.missing(_goalMlMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyHydration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyHydration(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      dateString: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_string'])!,
      totalMl: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_ml'])!,
      goalMl: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}goal_ml'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DailyHydrationsTable createAlias(String alias) {
    return $DailyHydrationsTable(attachedDatabase, alias);
  }
}

class DailyHydration extends DataClass implements Insertable<DailyHydration> {
  final int id;
  final String dateString;
  final int totalMl;
  final int goalMl;
  final DateTime updatedAt;
  const DailyHydration(
      {required this.id,
      required this.dateString,
      required this.totalMl,
      required this.goalMl,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_string'] = Variable<String>(dateString);
    map['total_ml'] = Variable<int>(totalMl);
    map['goal_ml'] = Variable<int>(goalMl);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DailyHydrationsCompanion toCompanion(bool nullToAbsent) {
    return DailyHydrationsCompanion(
      id: Value(id),
      dateString: Value(dateString),
      totalMl: Value(totalMl),
      goalMl: Value(goalMl),
      updatedAt: Value(updatedAt),
    );
  }

  factory DailyHydration.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyHydration(
      id: serializer.fromJson<int>(json['id']),
      dateString: serializer.fromJson<String>(json['dateString']),
      totalMl: serializer.fromJson<int>(json['totalMl']),
      goalMl: serializer.fromJson<int>(json['goalMl']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateString': serializer.toJson<String>(dateString),
      'totalMl': serializer.toJson<int>(totalMl),
      'goalMl': serializer.toJson<int>(goalMl),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DailyHydration copyWith(
          {int? id,
          String? dateString,
          int? totalMl,
          int? goalMl,
          DateTime? updatedAt}) =>
      DailyHydration(
        id: id ?? this.id,
        dateString: dateString ?? this.dateString,
        totalMl: totalMl ?? this.totalMl,
        goalMl: goalMl ?? this.goalMl,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DailyHydration copyWithCompanion(DailyHydrationsCompanion data) {
    return DailyHydration(
      id: data.id.present ? data.id.value : this.id,
      dateString:
          data.dateString.present ? data.dateString.value : this.dateString,
      totalMl: data.totalMl.present ? data.totalMl.value : this.totalMl,
      goalMl: data.goalMl.present ? data.goalMl.value : this.goalMl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyHydration(')
          ..write('id: $id, ')
          ..write('dateString: $dateString, ')
          ..write('totalMl: $totalMl, ')
          ..write('goalMl: $goalMl, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateString, totalMl, goalMl, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyHydration &&
          other.id == this.id &&
          other.dateString == this.dateString &&
          other.totalMl == this.totalMl &&
          other.goalMl == this.goalMl &&
          other.updatedAt == this.updatedAt);
}

class DailyHydrationsCompanion extends UpdateCompanion<DailyHydration> {
  final Value<int> id;
  final Value<String> dateString;
  final Value<int> totalMl;
  final Value<int> goalMl;
  final Value<DateTime> updatedAt;
  const DailyHydrationsCompanion({
    this.id = const Value.absent(),
    this.dateString = const Value.absent(),
    this.totalMl = const Value.absent(),
    this.goalMl = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DailyHydrationsCompanion.insert({
    this.id = const Value.absent(),
    required String dateString,
    required int totalMl,
    required int goalMl,
    this.updatedAt = const Value.absent(),
  })  : dateString = Value(dateString),
        totalMl = Value(totalMl),
        goalMl = Value(goalMl);
  static Insertable<DailyHydration> custom({
    Expression<int>? id,
    Expression<String>? dateString,
    Expression<int>? totalMl,
    Expression<int>? goalMl,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateString != null) 'date_string': dateString,
      if (totalMl != null) 'total_ml': totalMl,
      if (goalMl != null) 'goal_ml': goalMl,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DailyHydrationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? dateString,
      Value<int>? totalMl,
      Value<int>? goalMl,
      Value<DateTime>? updatedAt}) {
    return DailyHydrationsCompanion(
      id: id ?? this.id,
      dateString: dateString ?? this.dateString,
      totalMl: totalMl ?? this.totalMl,
      goalMl: goalMl ?? this.goalMl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateString.present) {
      map['date_string'] = Variable<String>(dateString.value);
    }
    if (totalMl.present) {
      map['total_ml'] = Variable<int>(totalMl.value);
    }
    if (goalMl.present) {
      map['goal_ml'] = Variable<int>(goalMl.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyHydrationsCompanion(')
          ..write('id: $id, ')
          ..write('dateString: $dateString, ')
          ..write('totalMl: $totalMl, ')
          ..write('goalMl: $goalMl, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $HealthProvenancesTable extends HealthProvenances
    with TableInfo<$HealthProvenancesTable, HealthProvenance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthProvenancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _externalIdMeta =
      const VerificationMeta('externalId');
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
      'external_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _sourceNameMeta =
      const VerificationMeta('sourceName');
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
      'source_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _importedAtMeta =
      const VerificationMeta('importedAt');
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
      'imported_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _localSessionIdMeta =
      const VerificationMeta('localSessionId');
  @override
  late final GeneratedColumn<int> localSessionId = GeneratedColumn<int>(
      'local_session_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES workout_sessions (id)'));
  static const VerificationMeta _fingerprintMeta =
      const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
      'fingerprint', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        provider,
        externalId,
        sourceName,
        importedAt,
        localSessionId,
        fingerprint
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_provenances';
  @override
  VerificationContext validateIntegrity(Insertable<HealthProvenance> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
          _externalIdMeta,
          externalId.isAcceptableOrUnknown(
              data['external_id']!, _externalIdMeta));
    }
    if (data.containsKey('source_name')) {
      context.handle(
          _sourceNameMeta,
          sourceName.isAcceptableOrUnknown(
              data['source_name']!, _sourceNameMeta));
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
          _importedAtMeta,
          importedAt.isAcceptableOrUnknown(
              data['imported_at']!, _importedAtMeta));
    }
    if (data.containsKey('local_session_id')) {
      context.handle(
          _localSessionIdMeta,
          localSessionId.isAcceptableOrUnknown(
              data['local_session_id']!, _localSessionIdMeta));
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
          _fingerprintMeta,
          fingerprint.isAcceptableOrUnknown(
              data['fingerprint']!, _fingerprintMeta));
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthProvenance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthProvenance(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      externalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}external_id']),
      sourceName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_name'])!,
      importedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}imported_at'])!,
      localSessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}local_session_id']),
      fingerprint: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fingerprint'])!,
    );
  }

  @override
  $HealthProvenancesTable createAlias(String alias) {
    return $HealthProvenancesTable(attachedDatabase, alias);
  }
}

class HealthProvenance extends DataClass
    implements Insertable<HealthProvenance> {
  final int id;
  final String provider;
  final String? externalId;
  final String sourceName;
  final DateTime importedAt;
  final int? localSessionId;
  final String fingerprint;
  const HealthProvenance(
      {required this.id,
      required this.provider,
      this.externalId,
      required this.sourceName,
      required this.importedAt,
      this.localSessionId,
      required this.fingerprint});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    map['source_name'] = Variable<String>(sourceName);
    map['imported_at'] = Variable<DateTime>(importedAt);
    if (!nullToAbsent || localSessionId != null) {
      map['local_session_id'] = Variable<int>(localSessionId);
    }
    map['fingerprint'] = Variable<String>(fingerprint);
    return map;
  }

  HealthProvenancesCompanion toCompanion(bool nullToAbsent) {
    return HealthProvenancesCompanion(
      id: Value(id),
      provider: Value(provider),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      sourceName: Value(sourceName),
      importedAt: Value(importedAt),
      localSessionId: localSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(localSessionId),
      fingerprint: Value(fingerprint),
    );
  }

  factory HealthProvenance.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthProvenance(
      id: serializer.fromJson<int>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      localSessionId: serializer.fromJson<int?>(json['localSessionId']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'provider': serializer.toJson<String>(provider),
      'externalId': serializer.toJson<String?>(externalId),
      'sourceName': serializer.toJson<String>(sourceName),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'localSessionId': serializer.toJson<int?>(localSessionId),
      'fingerprint': serializer.toJson<String>(fingerprint),
    };
  }

  HealthProvenance copyWith(
          {int? id,
          String? provider,
          Value<String?> externalId = const Value.absent(),
          String? sourceName,
          DateTime? importedAt,
          Value<int?> localSessionId = const Value.absent(),
          String? fingerprint}) =>
      HealthProvenance(
        id: id ?? this.id,
        provider: provider ?? this.provider,
        externalId: externalId.present ? externalId.value : this.externalId,
        sourceName: sourceName ?? this.sourceName,
        importedAt: importedAt ?? this.importedAt,
        localSessionId:
            localSessionId.present ? localSessionId.value : this.localSessionId,
        fingerprint: fingerprint ?? this.fingerprint,
      );
  HealthProvenance copyWithCompanion(HealthProvenancesCompanion data) {
    return HealthProvenance(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      externalId:
          data.externalId.present ? data.externalId.value : this.externalId,
      sourceName:
          data.sourceName.present ? data.sourceName.value : this.sourceName,
      importedAt:
          data.importedAt.present ? data.importedAt.value : this.importedAt,
      localSessionId: data.localSessionId.present
          ? data.localSessionId.value
          : this.localSessionId,
      fingerprint:
          data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthProvenance(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('sourceName: $sourceName, ')
          ..write('importedAt: $importedAt, ')
          ..write('localSessionId: $localSessionId, ')
          ..write('fingerprint: $fingerprint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, provider, externalId, sourceName,
      importedAt, localSessionId, fingerprint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthProvenance &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.externalId == this.externalId &&
          other.sourceName == this.sourceName &&
          other.importedAt == this.importedAt &&
          other.localSessionId == this.localSessionId &&
          other.fingerprint == this.fingerprint);
}

class HealthProvenancesCompanion extends UpdateCompanion<HealthProvenance> {
  final Value<int> id;
  final Value<String> provider;
  final Value<String?> externalId;
  final Value<String> sourceName;
  final Value<DateTime> importedAt;
  final Value<int?> localSessionId;
  final Value<String> fingerprint;
  const HealthProvenancesCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.externalId = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.localSessionId = const Value.absent(),
    this.fingerprint = const Value.absent(),
  });
  HealthProvenancesCompanion.insert({
    this.id = const Value.absent(),
    required String provider,
    this.externalId = const Value.absent(),
    required String sourceName,
    this.importedAt = const Value.absent(),
    this.localSessionId = const Value.absent(),
    required String fingerprint,
  })  : provider = Value(provider),
        sourceName = Value(sourceName),
        fingerprint = Value(fingerprint);
  static Insertable<HealthProvenance> custom({
    Expression<int>? id,
    Expression<String>? provider,
    Expression<String>? externalId,
    Expression<String>? sourceName,
    Expression<DateTime>? importedAt,
    Expression<int>? localSessionId,
    Expression<String>? fingerprint,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (externalId != null) 'external_id': externalId,
      if (sourceName != null) 'source_name': sourceName,
      if (importedAt != null) 'imported_at': importedAt,
      if (localSessionId != null) 'local_session_id': localSessionId,
      if (fingerprint != null) 'fingerprint': fingerprint,
    });
  }

  HealthProvenancesCompanion copyWith(
      {Value<int>? id,
      Value<String>? provider,
      Value<String?>? externalId,
      Value<String>? sourceName,
      Value<DateTime>? importedAt,
      Value<int?>? localSessionId,
      Value<String>? fingerprint}) {
    return HealthProvenancesCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      externalId: externalId ?? this.externalId,
      sourceName: sourceName ?? this.sourceName,
      importedAt: importedAt ?? this.importedAt,
      localSessionId: localSessionId ?? this.localSessionId,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (localSessionId.present) {
      map['local_session_id'] = Variable<int>(localSessionId.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthProvenancesCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('sourceName: $sourceName, ')
          ..write('importedAt: $importedAt, ')
          ..write('localSessionId: $localSessionId, ')
          ..write('fingerprint: $fingerprint')
          ..write(')'))
        .toString();
  }
}

class $AchievementUnlocksTable extends AchievementUnlocks
    with TableInfo<$AchievementUnlocksTable, AchievementUnlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementUnlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _achievementIdMeta =
      const VerificationMeta('achievementId');
  @override
  late final GeneratedColumn<String> achievementId = GeneratedColumn<String>(
      'achievement_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _unlockedAtMeta =
      const VerificationMeta('unlockedAt');
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
      'unlocked_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, achievementId, unlockedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievement_unlocks';
  @override
  VerificationContext validateIntegrity(Insertable<AchievementUnlock> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('achievement_id')) {
      context.handle(
          _achievementIdMeta,
          achievementId.isAcceptableOrUnknown(
              data['achievement_id']!, _achievementIdMeta));
    } else if (isInserting) {
      context.missing(_achievementIdMeta);
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
          _unlockedAtMeta,
          unlockedAt.isAcceptableOrUnknown(
              data['unlocked_at']!, _unlockedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AchievementUnlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AchievementUnlock(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      achievementId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}achievement_id'])!,
      unlockedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}unlocked_at'])!,
    );
  }

  @override
  $AchievementUnlocksTable createAlias(String alias) {
    return $AchievementUnlocksTable(attachedDatabase, alias);
  }
}

class AchievementUnlock extends DataClass
    implements Insertable<AchievementUnlock> {
  final int id;
  final String achievementId;
  final DateTime unlockedAt;
  const AchievementUnlock(
      {required this.id,
      required this.achievementId,
      required this.unlockedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['achievement_id'] = Variable<String>(achievementId);
    map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    return map;
  }

  AchievementUnlocksCompanion toCompanion(bool nullToAbsent) {
    return AchievementUnlocksCompanion(
      id: Value(id),
      achievementId: Value(achievementId),
      unlockedAt: Value(unlockedAt),
    );
  }

  factory AchievementUnlock.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AchievementUnlock(
      id: serializer.fromJson<int>(json['id']),
      achievementId: serializer.fromJson<String>(json['achievementId']),
      unlockedAt: serializer.fromJson<DateTime>(json['unlockedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'achievementId': serializer.toJson<String>(achievementId),
      'unlockedAt': serializer.toJson<DateTime>(unlockedAt),
    };
  }

  AchievementUnlock copyWith(
          {int? id, String? achievementId, DateTime? unlockedAt}) =>
      AchievementUnlock(
        id: id ?? this.id,
        achievementId: achievementId ?? this.achievementId,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
  AchievementUnlock copyWithCompanion(AchievementUnlocksCompanion data) {
    return AchievementUnlock(
      id: data.id.present ? data.id.value : this.id,
      achievementId: data.achievementId.present
          ? data.achievementId.value
          : this.achievementId,
      unlockedAt:
          data.unlockedAt.present ? data.unlockedAt.value : this.unlockedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AchievementUnlock(')
          ..write('id: $id, ')
          ..write('achievementId: $achievementId, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, achievementId, unlockedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AchievementUnlock &&
          other.id == this.id &&
          other.achievementId == this.achievementId &&
          other.unlockedAt == this.unlockedAt);
}

class AchievementUnlocksCompanion extends UpdateCompanion<AchievementUnlock> {
  final Value<int> id;
  final Value<String> achievementId;
  final Value<DateTime> unlockedAt;
  const AchievementUnlocksCompanion({
    this.id = const Value.absent(),
    this.achievementId = const Value.absent(),
    this.unlockedAt = const Value.absent(),
  });
  AchievementUnlocksCompanion.insert({
    this.id = const Value.absent(),
    required String achievementId,
    this.unlockedAt = const Value.absent(),
  }) : achievementId = Value(achievementId);
  static Insertable<AchievementUnlock> custom({
    Expression<int>? id,
    Expression<String>? achievementId,
    Expression<DateTime>? unlockedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (achievementId != null) 'achievement_id': achievementId,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
    });
  }

  AchievementUnlocksCompanion copyWith(
      {Value<int>? id,
      Value<String>? achievementId,
      Value<DateTime>? unlockedAt}) {
    return AchievementUnlocksCompanion(
      id: id ?? this.id,
      achievementId: achievementId ?? this.achievementId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (achievementId.present) {
      map['achievement_id'] = Variable<String>(achievementId.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementUnlocksCompanion(')
          ..write('id: $id, ')
          ..write('achievementId: $achievementId, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }
}

class $ProgramsTable extends Programs with TableInfo<$ProgramsTable, Program> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
      'goal', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _archivedAtUtcMeta =
      const VerificationMeta('archivedAtUtc');
  @override
  late final GeneratedColumn<DateTime> archivedAtUtc =
      GeneratedColumn<DateTime>('archived_at_utc', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, goal, notes, createdAtUtc, archivedAtUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'programs';
  @override
  VerificationContext validateIntegrity(Insertable<Program> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('goal')) {
      context.handle(
          _goalMeta, goal.isAcceptableOrUnknown(data['goal']!, _goalMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('archived_at_utc')) {
      context.handle(
          _archivedAtUtcMeta,
          archivedAtUtc.isAcceptableOrUnknown(
              data['archived_at_utc']!, _archivedAtUtcMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Program map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Program(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      goal: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      archivedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}archived_at_utc']),
    );
  }

  @override
  $ProgramsTable createAlias(String alias) {
    return $ProgramsTable(attachedDatabase, alias);
  }
}

class Program extends DataClass implements Insertable<Program> {
  final String id;
  final String name;
  final String? goal;
  final String? notes;
  final DateTime createdAtUtc;
  final DateTime? archivedAtUtc;
  const Program(
      {required this.id,
      required this.name,
      this.goal,
      this.notes,
      required this.createdAtUtc,
      this.archivedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || goal != null) {
      map['goal'] = Variable<String>(goal);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    if (!nullToAbsent || archivedAtUtc != null) {
      map['archived_at_utc'] = Variable<DateTime>(archivedAtUtc);
    }
    return map;
  }

  ProgramsCompanion toCompanion(bool nullToAbsent) {
    return ProgramsCompanion(
      id: Value(id),
      name: Value(name),
      goal: goal == null && nullToAbsent ? const Value.absent() : Value(goal),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAtUtc: Value(createdAtUtc),
      archivedAtUtc: archivedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtUtc),
    );
  }

  factory Program.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Program(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      goal: serializer.fromJson<String?>(json['goal']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      archivedAtUtc: serializer.fromJson<DateTime?>(json['archivedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'goal': serializer.toJson<String?>(goal),
      'notes': serializer.toJson<String?>(notes),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'archivedAtUtc': serializer.toJson<DateTime?>(archivedAtUtc),
    };
  }

  Program copyWith(
          {String? id,
          String? name,
          Value<String?> goal = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? createdAtUtc,
          Value<DateTime?> archivedAtUtc = const Value.absent()}) =>
      Program(
        id: id ?? this.id,
        name: name ?? this.name,
        goal: goal.present ? goal.value : this.goal,
        notes: notes.present ? notes.value : this.notes,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        archivedAtUtc:
            archivedAtUtc.present ? archivedAtUtc.value : this.archivedAtUtc,
      );
  Program copyWithCompanion(ProgramsCompanion data) {
    return Program(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      goal: data.goal.present ? data.goal.value : this.goal,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      archivedAtUtc: data.archivedAtUtc.present
          ? data.archivedAtUtc.value
          : this.archivedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Program(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goal: $goal, ')
          ..write('notes: $notes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('archivedAtUtc: $archivedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, goal, notes, createdAtUtc, archivedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Program &&
          other.id == this.id &&
          other.name == this.name &&
          other.goal == this.goal &&
          other.notes == this.notes &&
          other.createdAtUtc == this.createdAtUtc &&
          other.archivedAtUtc == this.archivedAtUtc);
}

class ProgramsCompanion extends UpdateCompanion<Program> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> goal;
  final Value<String?> notes;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime?> archivedAtUtc;
  final Value<int> rowid;
  const ProgramsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.goal = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.archivedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramsCompanion.insert({
    required String id,
    required String name,
    this.goal = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAtUtc,
    this.archivedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAtUtc = Value(createdAtUtc);
  static Insertable<Program> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? goal,
    Expression<String>? notes,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? archivedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (goal != null) 'goal': goal,
      if (notes != null) 'notes': notes,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (archivedAtUtc != null) 'archived_at_utc': archivedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? goal,
      Value<String?>? notes,
      Value<DateTime>? createdAtUtc,
      Value<DateTime?>? archivedAtUtc,
      Value<int>? rowid}) {
    return ProgramsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      notes: notes ?? this.notes,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      archivedAtUtc: archivedAtUtc ?? this.archivedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (archivedAtUtc.present) {
      map['archived_at_utc'] = Variable<DateTime>(archivedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goal: $goal, ')
          ..write('notes: $notes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('archivedAtUtc: $archivedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgramVersionsTable extends ProgramVersions
    with TableInfo<$ProgramVersionsTable, ProgramVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _programIdMeta =
      const VerificationMeta('programId');
  @override
  late final GeneratedColumn<String> programId = GeneratedColumn<String>(
      'program_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES programs (id)'));
  static const VerificationMeta _versionNumberMeta =
      const VerificationMeta('versionNumber');
  @override
  late final GeneratedColumn<int> versionNumber = GeneratedColumn<int>(
      'version_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
      'origin', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('user'));
  static const VerificationMeta _sourceVersionIdMeta =
      const VerificationMeta('sourceVersionId');
  @override
  late final GeneratedColumn<String> sourceVersionId = GeneratedColumn<String>(
      'source_version_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES program_versions (id)'));
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _publishedAtUtcMeta =
      const VerificationMeta('publishedAtUtc');
  @override
  late final GeneratedColumn<DateTime> publishedAtUtc =
      GeneratedColumn<DateTime>('published_at_utc', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _archivedAtUtcMeta =
      const VerificationMeta('archivedAtUtc');
  @override
  late final GeneratedColumn<DateTime> archivedAtUtc =
      GeneratedColumn<DateTime>('archived_at_utc', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        programId,
        versionNumber,
        status,
        origin,
        sourceVersionId,
        createdAtUtc,
        publishedAtUtc,
        archivedAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'program_versions';
  @override
  VerificationContext validateIntegrity(Insertable<ProgramVersion> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('program_id')) {
      context.handle(_programIdMeta,
          programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta));
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('version_number')) {
      context.handle(
          _versionNumberMeta,
          versionNumber.isAcceptableOrUnknown(
              data['version_number']!, _versionNumberMeta));
    } else if (isInserting) {
      context.missing(_versionNumberMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(_originMeta,
          origin.isAcceptableOrUnknown(data['origin']!, _originMeta));
    }
    if (data.containsKey('source_version_id')) {
      context.handle(
          _sourceVersionIdMeta,
          sourceVersionId.isAcceptableOrUnknown(
              data['source_version_id']!, _sourceVersionIdMeta));
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('published_at_utc')) {
      context.handle(
          _publishedAtUtcMeta,
          publishedAtUtc.isAcceptableOrUnknown(
              data['published_at_utc']!, _publishedAtUtcMeta));
    }
    if (data.containsKey('archived_at_utc')) {
      context.handle(
          _archivedAtUtcMeta,
          archivedAtUtc.isAcceptableOrUnknown(
              data['archived_at_utc']!, _archivedAtUtcMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {programId, versionNumber},
      ];
  @override
  ProgramVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramVersion(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      programId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}program_id'])!,
      versionNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version_number'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      origin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}origin'])!,
      sourceVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_version_id']),
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      publishedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}published_at_utc']),
      archivedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}archived_at_utc']),
    );
  }

  @override
  $ProgramVersionsTable createAlias(String alias) {
    return $ProgramVersionsTable(attachedDatabase, alias);
  }
}

class ProgramVersion extends DataClass implements Insertable<ProgramVersion> {
  final String id;
  final String programId;
  final int versionNumber;
  final String status;
  final String origin;
  final String? sourceVersionId;
  final DateTime createdAtUtc;
  final DateTime? publishedAtUtc;
  final DateTime? archivedAtUtc;
  const ProgramVersion(
      {required this.id,
      required this.programId,
      required this.versionNumber,
      required this.status,
      required this.origin,
      this.sourceVersionId,
      required this.createdAtUtc,
      this.publishedAtUtc,
      this.archivedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['program_id'] = Variable<String>(programId);
    map['version_number'] = Variable<int>(versionNumber);
    map['status'] = Variable<String>(status);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || sourceVersionId != null) {
      map['source_version_id'] = Variable<String>(sourceVersionId);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    if (!nullToAbsent || publishedAtUtc != null) {
      map['published_at_utc'] = Variable<DateTime>(publishedAtUtc);
    }
    if (!nullToAbsent || archivedAtUtc != null) {
      map['archived_at_utc'] = Variable<DateTime>(archivedAtUtc);
    }
    return map;
  }

  ProgramVersionsCompanion toCompanion(bool nullToAbsent) {
    return ProgramVersionsCompanion(
      id: Value(id),
      programId: Value(programId),
      versionNumber: Value(versionNumber),
      status: Value(status),
      origin: Value(origin),
      sourceVersionId: sourceVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceVersionId),
      createdAtUtc: Value(createdAtUtc),
      publishedAtUtc: publishedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAtUtc),
      archivedAtUtc: archivedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtUtc),
    );
  }

  factory ProgramVersion.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramVersion(
      id: serializer.fromJson<String>(json['id']),
      programId: serializer.fromJson<String>(json['programId']),
      versionNumber: serializer.fromJson<int>(json['versionNumber']),
      status: serializer.fromJson<String>(json['status']),
      origin: serializer.fromJson<String>(json['origin']),
      sourceVersionId: serializer.fromJson<String?>(json['sourceVersionId']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      publishedAtUtc: serializer.fromJson<DateTime?>(json['publishedAtUtc']),
      archivedAtUtc: serializer.fromJson<DateTime?>(json['archivedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'programId': serializer.toJson<String>(programId),
      'versionNumber': serializer.toJson<int>(versionNumber),
      'status': serializer.toJson<String>(status),
      'origin': serializer.toJson<String>(origin),
      'sourceVersionId': serializer.toJson<String?>(sourceVersionId),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'publishedAtUtc': serializer.toJson<DateTime?>(publishedAtUtc),
      'archivedAtUtc': serializer.toJson<DateTime?>(archivedAtUtc),
    };
  }

  ProgramVersion copyWith(
          {String? id,
          String? programId,
          int? versionNumber,
          String? status,
          String? origin,
          Value<String?> sourceVersionId = const Value.absent(),
          DateTime? createdAtUtc,
          Value<DateTime?> publishedAtUtc = const Value.absent(),
          Value<DateTime?> archivedAtUtc = const Value.absent()}) =>
      ProgramVersion(
        id: id ?? this.id,
        programId: programId ?? this.programId,
        versionNumber: versionNumber ?? this.versionNumber,
        status: status ?? this.status,
        origin: origin ?? this.origin,
        sourceVersionId: sourceVersionId.present
            ? sourceVersionId.value
            : this.sourceVersionId,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        publishedAtUtc:
            publishedAtUtc.present ? publishedAtUtc.value : this.publishedAtUtc,
        archivedAtUtc:
            archivedAtUtc.present ? archivedAtUtc.value : this.archivedAtUtc,
      );
  ProgramVersion copyWithCompanion(ProgramVersionsCompanion data) {
    return ProgramVersion(
      id: data.id.present ? data.id.value : this.id,
      programId: data.programId.present ? data.programId.value : this.programId,
      versionNumber: data.versionNumber.present
          ? data.versionNumber.value
          : this.versionNumber,
      status: data.status.present ? data.status.value : this.status,
      origin: data.origin.present ? data.origin.value : this.origin,
      sourceVersionId: data.sourceVersionId.present
          ? data.sourceVersionId.value
          : this.sourceVersionId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      publishedAtUtc: data.publishedAtUtc.present
          ? data.publishedAtUtc.value
          : this.publishedAtUtc,
      archivedAtUtc: data.archivedAtUtc.present
          ? data.archivedAtUtc.value
          : this.archivedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramVersion(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('sourceVersionId: $sourceVersionId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('publishedAtUtc: $publishedAtUtc, ')
          ..write('archivedAtUtc: $archivedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, programId, versionNumber, status, origin,
      sourceVersionId, createdAtUtc, publishedAtUtc, archivedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramVersion &&
          other.id == this.id &&
          other.programId == this.programId &&
          other.versionNumber == this.versionNumber &&
          other.status == this.status &&
          other.origin == this.origin &&
          other.sourceVersionId == this.sourceVersionId &&
          other.createdAtUtc == this.createdAtUtc &&
          other.publishedAtUtc == this.publishedAtUtc &&
          other.archivedAtUtc == this.archivedAtUtc);
}

class ProgramVersionsCompanion extends UpdateCompanion<ProgramVersion> {
  final Value<String> id;
  final Value<String> programId;
  final Value<int> versionNumber;
  final Value<String> status;
  final Value<String> origin;
  final Value<String?> sourceVersionId;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime?> publishedAtUtc;
  final Value<DateTime?> archivedAtUtc;
  final Value<int> rowid;
  const ProgramVersionsCompanion({
    this.id = const Value.absent(),
    this.programId = const Value.absent(),
    this.versionNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.origin = const Value.absent(),
    this.sourceVersionId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.publishedAtUtc = const Value.absent(),
    this.archivedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramVersionsCompanion.insert({
    required String id,
    required String programId,
    required int versionNumber,
    required String status,
    this.origin = const Value.absent(),
    this.sourceVersionId = const Value.absent(),
    required DateTime createdAtUtc,
    this.publishedAtUtc = const Value.absent(),
    this.archivedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        programId = Value(programId),
        versionNumber = Value(versionNumber),
        status = Value(status),
        createdAtUtc = Value(createdAtUtc);
  static Insertable<ProgramVersion> custom({
    Expression<String>? id,
    Expression<String>? programId,
    Expression<int>? versionNumber,
    Expression<String>? status,
    Expression<String>? origin,
    Expression<String>? sourceVersionId,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? publishedAtUtc,
    Expression<DateTime>? archivedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programId != null) 'program_id': programId,
      if (versionNumber != null) 'version_number': versionNumber,
      if (status != null) 'status': status,
      if (origin != null) 'origin': origin,
      if (sourceVersionId != null) 'source_version_id': sourceVersionId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (publishedAtUtc != null) 'published_at_utc': publishedAtUtc,
      if (archivedAtUtc != null) 'archived_at_utc': archivedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramVersionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? programId,
      Value<int>? versionNumber,
      Value<String>? status,
      Value<String>? origin,
      Value<String?>? sourceVersionId,
      Value<DateTime>? createdAtUtc,
      Value<DateTime?>? publishedAtUtc,
      Value<DateTime?>? archivedAtUtc,
      Value<int>? rowid}) {
    return ProgramVersionsCompanion(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      versionNumber: versionNumber ?? this.versionNumber,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      sourceVersionId: sourceVersionId ?? this.sourceVersionId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      publishedAtUtc: publishedAtUtc ?? this.publishedAtUtc,
      archivedAtUtc: archivedAtUtc ?? this.archivedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<String>(programId.value);
    }
    if (versionNumber.present) {
      map['version_number'] = Variable<int>(versionNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (sourceVersionId.present) {
      map['source_version_id'] = Variable<String>(sourceVersionId.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (publishedAtUtc.present) {
      map['published_at_utc'] = Variable<DateTime>(publishedAtUtc.value);
    }
    if (archivedAtUtc.present) {
      map['archived_at_utc'] = Variable<DateTime>(archivedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramVersionsCompanion(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('sourceVersionId: $sourceVersionId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('publishedAtUtc: $publishedAtUtc, ')
          ..write('archivedAtUtc: $archivedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgramBlocksTable extends ProgramBlocks
    with TableInfo<$ProgramBlocksTable, ProgramBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _programVersionIdMeta =
      const VerificationMeta('programVersionId');
  @override
  late final GeneratedColumn<String> programVersionId = GeneratedColumn<String>(
      'program_version_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES program_versions (id)'));
  static const VerificationMeta _ordinalMeta =
      const VerificationMeta('ordinal');
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
      'ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, programVersionId, ordinal, name, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'program_blocks';
  @override
  VerificationContext validateIntegrity(Insertable<ProgramBlock> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('program_version_id')) {
      context.handle(
          _programVersionIdMeta,
          programVersionId.isAcceptableOrUnknown(
              data['program_version_id']!, _programVersionIdMeta));
    } else if (isInserting) {
      context.missing(_programVersionIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(_ordinalMeta,
          ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta));
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {programVersionId, ordinal},
      ];
  @override
  ProgramBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramBlock(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      programVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}program_version_id'])!,
      ordinal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ordinal'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
    );
  }

  @override
  $ProgramBlocksTable createAlias(String alias) {
    return $ProgramBlocksTable(attachedDatabase, alias);
  }
}

class ProgramBlock extends DataClass implements Insertable<ProgramBlock> {
  final String id;
  final String programVersionId;
  final int ordinal;
  final String name;
  final String? description;
  const ProgramBlock(
      {required this.id,
      required this.programVersionId,
      required this.ordinal,
      required this.name,
      this.description});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['program_version_id'] = Variable<String>(programVersionId);
    map['ordinal'] = Variable<int>(ordinal);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  ProgramBlocksCompanion toCompanion(bool nullToAbsent) {
    return ProgramBlocksCompanion(
      id: Value(id),
      programVersionId: Value(programVersionId),
      ordinal: Value(ordinal),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory ProgramBlock.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramBlock(
      id: serializer.fromJson<String>(json['id']),
      programVersionId: serializer.fromJson<String>(json['programVersionId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'programVersionId': serializer.toJson<String>(programVersionId),
      'ordinal': serializer.toJson<int>(ordinal),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
    };
  }

  ProgramBlock copyWith(
          {String? id,
          String? programVersionId,
          int? ordinal,
          String? name,
          Value<String?> description = const Value.absent()}) =>
      ProgramBlock(
        id: id ?? this.id,
        programVersionId: programVersionId ?? this.programVersionId,
        ordinal: ordinal ?? this.ordinal,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
      );
  ProgramBlock copyWithCompanion(ProgramBlocksCompanion data) {
    return ProgramBlock(
      id: data.id.present ? data.id.value : this.id,
      programVersionId: data.programVersionId.present
          ? data.programVersionId.value
          : this.programVersionId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramBlock(')
          ..write('id: $id, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, programVersionId, ordinal, name, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramBlock &&
          other.id == this.id &&
          other.programVersionId == this.programVersionId &&
          other.ordinal == this.ordinal &&
          other.name == this.name &&
          other.description == this.description);
}

class ProgramBlocksCompanion extends UpdateCompanion<ProgramBlock> {
  final Value<String> id;
  final Value<String> programVersionId;
  final Value<int> ordinal;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> rowid;
  const ProgramBlocksCompanion({
    this.id = const Value.absent(),
    this.programVersionId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramBlocksCompanion.insert({
    required String id,
    required String programVersionId,
    required int ordinal,
    required String name,
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        programVersionId = Value(programVersionId),
        ordinal = Value(ordinal),
        name = Value(name);
  static Insertable<ProgramBlock> custom({
    Expression<String>? id,
    Expression<String>? programVersionId,
    Expression<int>? ordinal,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programVersionId != null) 'program_version_id': programVersionId,
      if (ordinal != null) 'ordinal': ordinal,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramBlocksCompanion copyWith(
      {Value<String>? id,
      Value<String>? programVersionId,
      Value<int>? ordinal,
      Value<String>? name,
      Value<String?>? description,
      Value<int>? rowid}) {
    return ProgramBlocksCompanion(
      id: id ?? this.id,
      programVersionId: programVersionId ?? this.programVersionId,
      ordinal: ordinal ?? this.ordinal,
      name: name ?? this.name,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (programVersionId.present) {
      map['program_version_id'] = Variable<String>(programVersionId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramBlocksCompanion(')
          ..write('id: $id, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgramWeeksTable extends ProgramWeeks
    with TableInfo<$ProgramWeeksTable, ProgramWeek> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramWeeksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _programVersionIdMeta =
      const VerificationMeta('programVersionId');
  @override
  late final GeneratedColumn<String> programVersionId = GeneratedColumn<String>(
      'program_version_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES program_versions (id)'));
  static const VerificationMeta _programBlockIdMeta =
      const VerificationMeta('programBlockId');
  @override
  late final GeneratedColumn<String> programBlockId = GeneratedColumn<String>(
      'program_block_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES program_blocks (id)'));
  static const VerificationMeta _ordinalInBlockMeta =
      const VerificationMeta('ordinalInBlock');
  @override
  late final GeneratedColumn<int> ordinalInBlock = GeneratedColumn<int>(
      'ordinal_in_block', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _programWeekOrdinalMeta =
      const VerificationMeta('programWeekOrdinal');
  @override
  late final GeneratedColumn<int> programWeekOrdinal = GeneratedColumn<int>(
      'program_week_ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDeloadMeta =
      const VerificationMeta('isDeload');
  @override
  late final GeneratedColumn<bool> isDeload = GeneratedColumn<bool>(
      'is_deload', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deload" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        programVersionId,
        programBlockId,
        ordinalInBlock,
        programWeekOrdinal,
        name,
        isDeload
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'program_weeks';
  @override
  VerificationContext validateIntegrity(Insertable<ProgramWeek> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('program_version_id')) {
      context.handle(
          _programVersionIdMeta,
          programVersionId.isAcceptableOrUnknown(
              data['program_version_id']!, _programVersionIdMeta));
    } else if (isInserting) {
      context.missing(_programVersionIdMeta);
    }
    if (data.containsKey('program_block_id')) {
      context.handle(
          _programBlockIdMeta,
          programBlockId.isAcceptableOrUnknown(
              data['program_block_id']!, _programBlockIdMeta));
    } else if (isInserting) {
      context.missing(_programBlockIdMeta);
    }
    if (data.containsKey('ordinal_in_block')) {
      context.handle(
          _ordinalInBlockMeta,
          ordinalInBlock.isAcceptableOrUnknown(
              data['ordinal_in_block']!, _ordinalInBlockMeta));
    } else if (isInserting) {
      context.missing(_ordinalInBlockMeta);
    }
    if (data.containsKey('program_week_ordinal')) {
      context.handle(
          _programWeekOrdinalMeta,
          programWeekOrdinal.isAcceptableOrUnknown(
              data['program_week_ordinal']!, _programWeekOrdinalMeta));
    } else if (isInserting) {
      context.missing(_programWeekOrdinalMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('is_deload')) {
      context.handle(_isDeloadMeta,
          isDeload.isAcceptableOrUnknown(data['is_deload']!, _isDeloadMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {programBlockId, ordinalInBlock},
        {programVersionId, programWeekOrdinal},
      ];
  @override
  ProgramWeek map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramWeek(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      programVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}program_version_id'])!,
      programBlockId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}program_block_id'])!,
      ordinalInBlock: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ordinal_in_block'])!,
      programWeekOrdinal: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}program_week_ordinal'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      isDeload: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deload'])!,
    );
  }

  @override
  $ProgramWeeksTable createAlias(String alias) {
    return $ProgramWeeksTable(attachedDatabase, alias);
  }
}

class ProgramWeek extends DataClass implements Insertable<ProgramWeek> {
  final String id;
  final String programVersionId;
  final String programBlockId;
  final int ordinalInBlock;
  final int programWeekOrdinal;
  final String? name;
  final bool isDeload;
  const ProgramWeek(
      {required this.id,
      required this.programVersionId,
      required this.programBlockId,
      required this.ordinalInBlock,
      required this.programWeekOrdinal,
      this.name,
      required this.isDeload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['program_version_id'] = Variable<String>(programVersionId);
    map['program_block_id'] = Variable<String>(programBlockId);
    map['ordinal_in_block'] = Variable<int>(ordinalInBlock);
    map['program_week_ordinal'] = Variable<int>(programWeekOrdinal);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['is_deload'] = Variable<bool>(isDeload);
    return map;
  }

  ProgramWeeksCompanion toCompanion(bool nullToAbsent) {
    return ProgramWeeksCompanion(
      id: Value(id),
      programVersionId: Value(programVersionId),
      programBlockId: Value(programBlockId),
      ordinalInBlock: Value(ordinalInBlock),
      programWeekOrdinal: Value(programWeekOrdinal),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      isDeload: Value(isDeload),
    );
  }

  factory ProgramWeek.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramWeek(
      id: serializer.fromJson<String>(json['id']),
      programVersionId: serializer.fromJson<String>(json['programVersionId']),
      programBlockId: serializer.fromJson<String>(json['programBlockId']),
      ordinalInBlock: serializer.fromJson<int>(json['ordinalInBlock']),
      programWeekOrdinal: serializer.fromJson<int>(json['programWeekOrdinal']),
      name: serializer.fromJson<String?>(json['name']),
      isDeload: serializer.fromJson<bool>(json['isDeload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'programVersionId': serializer.toJson<String>(programVersionId),
      'programBlockId': serializer.toJson<String>(programBlockId),
      'ordinalInBlock': serializer.toJson<int>(ordinalInBlock),
      'programWeekOrdinal': serializer.toJson<int>(programWeekOrdinal),
      'name': serializer.toJson<String?>(name),
      'isDeload': serializer.toJson<bool>(isDeload),
    };
  }

  ProgramWeek copyWith(
          {String? id,
          String? programVersionId,
          String? programBlockId,
          int? ordinalInBlock,
          int? programWeekOrdinal,
          Value<String?> name = const Value.absent(),
          bool? isDeload}) =>
      ProgramWeek(
        id: id ?? this.id,
        programVersionId: programVersionId ?? this.programVersionId,
        programBlockId: programBlockId ?? this.programBlockId,
        ordinalInBlock: ordinalInBlock ?? this.ordinalInBlock,
        programWeekOrdinal: programWeekOrdinal ?? this.programWeekOrdinal,
        name: name.present ? name.value : this.name,
        isDeload: isDeload ?? this.isDeload,
      );
  ProgramWeek copyWithCompanion(ProgramWeeksCompanion data) {
    return ProgramWeek(
      id: data.id.present ? data.id.value : this.id,
      programVersionId: data.programVersionId.present
          ? data.programVersionId.value
          : this.programVersionId,
      programBlockId: data.programBlockId.present
          ? data.programBlockId.value
          : this.programBlockId,
      ordinalInBlock: data.ordinalInBlock.present
          ? data.ordinalInBlock.value
          : this.ordinalInBlock,
      programWeekOrdinal: data.programWeekOrdinal.present
          ? data.programWeekOrdinal.value
          : this.programWeekOrdinal,
      name: data.name.present ? data.name.value : this.name,
      isDeload: data.isDeload.present ? data.isDeload.value : this.isDeload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramWeek(')
          ..write('id: $id, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('programBlockId: $programBlockId, ')
          ..write('ordinalInBlock: $ordinalInBlock, ')
          ..write('programWeekOrdinal: $programWeekOrdinal, ')
          ..write('name: $name, ')
          ..write('isDeload: $isDeload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, programVersionId, programBlockId,
      ordinalInBlock, programWeekOrdinal, name, isDeload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramWeek &&
          other.id == this.id &&
          other.programVersionId == this.programVersionId &&
          other.programBlockId == this.programBlockId &&
          other.ordinalInBlock == this.ordinalInBlock &&
          other.programWeekOrdinal == this.programWeekOrdinal &&
          other.name == this.name &&
          other.isDeload == this.isDeload);
}

class ProgramWeeksCompanion extends UpdateCompanion<ProgramWeek> {
  final Value<String> id;
  final Value<String> programVersionId;
  final Value<String> programBlockId;
  final Value<int> ordinalInBlock;
  final Value<int> programWeekOrdinal;
  final Value<String?> name;
  final Value<bool> isDeload;
  final Value<int> rowid;
  const ProgramWeeksCompanion({
    this.id = const Value.absent(),
    this.programVersionId = const Value.absent(),
    this.programBlockId = const Value.absent(),
    this.ordinalInBlock = const Value.absent(),
    this.programWeekOrdinal = const Value.absent(),
    this.name = const Value.absent(),
    this.isDeload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramWeeksCompanion.insert({
    required String id,
    required String programVersionId,
    required String programBlockId,
    required int ordinalInBlock,
    required int programWeekOrdinal,
    this.name = const Value.absent(),
    this.isDeload = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        programVersionId = Value(programVersionId),
        programBlockId = Value(programBlockId),
        ordinalInBlock = Value(ordinalInBlock),
        programWeekOrdinal = Value(programWeekOrdinal);
  static Insertable<ProgramWeek> custom({
    Expression<String>? id,
    Expression<String>? programVersionId,
    Expression<String>? programBlockId,
    Expression<int>? ordinalInBlock,
    Expression<int>? programWeekOrdinal,
    Expression<String>? name,
    Expression<bool>? isDeload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programVersionId != null) 'program_version_id': programVersionId,
      if (programBlockId != null) 'program_block_id': programBlockId,
      if (ordinalInBlock != null) 'ordinal_in_block': ordinalInBlock,
      if (programWeekOrdinal != null)
        'program_week_ordinal': programWeekOrdinal,
      if (name != null) 'name': name,
      if (isDeload != null) 'is_deload': isDeload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramWeeksCompanion copyWith(
      {Value<String>? id,
      Value<String>? programVersionId,
      Value<String>? programBlockId,
      Value<int>? ordinalInBlock,
      Value<int>? programWeekOrdinal,
      Value<String?>? name,
      Value<bool>? isDeload,
      Value<int>? rowid}) {
    return ProgramWeeksCompanion(
      id: id ?? this.id,
      programVersionId: programVersionId ?? this.programVersionId,
      programBlockId: programBlockId ?? this.programBlockId,
      ordinalInBlock: ordinalInBlock ?? this.ordinalInBlock,
      programWeekOrdinal: programWeekOrdinal ?? this.programWeekOrdinal,
      name: name ?? this.name,
      isDeload: isDeload ?? this.isDeload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (programVersionId.present) {
      map['program_version_id'] = Variable<String>(programVersionId.value);
    }
    if (programBlockId.present) {
      map['program_block_id'] = Variable<String>(programBlockId.value);
    }
    if (ordinalInBlock.present) {
      map['ordinal_in_block'] = Variable<int>(ordinalInBlock.value);
    }
    if (programWeekOrdinal.present) {
      map['program_week_ordinal'] = Variable<int>(programWeekOrdinal.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDeload.present) {
      map['is_deload'] = Variable<bool>(isDeload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramWeeksCompanion(')
          ..write('id: $id, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('programBlockId: $programBlockId, ')
          ..write('ordinalInBlock: $ordinalInBlock, ')
          ..write('programWeekOrdinal: $programWeekOrdinal, ')
          ..write('name: $name, ')
          ..write('isDeload: $isDeload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionTemplatesTable extends SessionTemplates
    with TableInfo<$SessionTemplatesTable, SessionTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _programWeekIdMeta =
      const VerificationMeta('programWeekId');
  @override
  late final GeneratedColumn<String> programWeekId = GeneratedColumn<String>(
      'program_week_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES program_weeks (id)'));
  static const VerificationMeta _ordinalMeta =
      const VerificationMeta('ordinal');
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
      'ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plannedWeekdayMeta =
      const VerificationMeta('plannedWeekday');
  @override
  late final GeneratedColumn<int> plannedWeekday = GeneratedColumn<int>(
      'planned_weekday', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _plannedStartMinuteMeta =
      const VerificationMeta('plannedStartMinute');
  @override
  late final GeneratedColumn<int> plannedStartMinute = GeneratedColumn<int>(
      'planned_start_minute', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        programWeekId,
        ordinal,
        name,
        plannedWeekday,
        plannedStartMinute,
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_templates';
  @override
  VerificationContext validateIntegrity(Insertable<SessionTemplate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('program_week_id')) {
      context.handle(
          _programWeekIdMeta,
          programWeekId.isAcceptableOrUnknown(
              data['program_week_id']!, _programWeekIdMeta));
    } else if (isInserting) {
      context.missing(_programWeekIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(_ordinalMeta,
          ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta));
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('planned_weekday')) {
      context.handle(
          _plannedWeekdayMeta,
          plannedWeekday.isAcceptableOrUnknown(
              data['planned_weekday']!, _plannedWeekdayMeta));
    } else if (isInserting) {
      context.missing(_plannedWeekdayMeta);
    }
    if (data.containsKey('planned_start_minute')) {
      context.handle(
          _plannedStartMinuteMeta,
          plannedStartMinute.isAcceptableOrUnknown(
              data['planned_start_minute']!, _plannedStartMinuteMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {programWeekId, ordinal},
        {programWeekId, plannedWeekday, ordinal},
      ];
  @override
  SessionTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionTemplate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      programWeekId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}program_week_id'])!,
      ordinal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ordinal'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      plannedWeekday: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}planned_weekday'])!,
      plannedStartMinute: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}planned_start_minute']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $SessionTemplatesTable createAlias(String alias) {
    return $SessionTemplatesTable(attachedDatabase, alias);
  }
}

class SessionTemplate extends DataClass implements Insertable<SessionTemplate> {
  final String id;
  final String programWeekId;
  final int ordinal;
  final String name;
  final int plannedWeekday;
  final int? plannedStartMinute;
  final String? notes;
  const SessionTemplate(
      {required this.id,
      required this.programWeekId,
      required this.ordinal,
      required this.name,
      required this.plannedWeekday,
      this.plannedStartMinute,
      this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['program_week_id'] = Variable<String>(programWeekId);
    map['ordinal'] = Variable<int>(ordinal);
    map['name'] = Variable<String>(name);
    map['planned_weekday'] = Variable<int>(plannedWeekday);
    if (!nullToAbsent || plannedStartMinute != null) {
      map['planned_start_minute'] = Variable<int>(plannedStartMinute);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  SessionTemplatesCompanion toCompanion(bool nullToAbsent) {
    return SessionTemplatesCompanion(
      id: Value(id),
      programWeekId: Value(programWeekId),
      ordinal: Value(ordinal),
      name: Value(name),
      plannedWeekday: Value(plannedWeekday),
      plannedStartMinute: plannedStartMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedStartMinute),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory SessionTemplate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionTemplate(
      id: serializer.fromJson<String>(json['id']),
      programWeekId: serializer.fromJson<String>(json['programWeekId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      name: serializer.fromJson<String>(json['name']),
      plannedWeekday: serializer.fromJson<int>(json['plannedWeekday']),
      plannedStartMinute: serializer.fromJson<int?>(json['plannedStartMinute']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'programWeekId': serializer.toJson<String>(programWeekId),
      'ordinal': serializer.toJson<int>(ordinal),
      'name': serializer.toJson<String>(name),
      'plannedWeekday': serializer.toJson<int>(plannedWeekday),
      'plannedStartMinute': serializer.toJson<int?>(plannedStartMinute),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  SessionTemplate copyWith(
          {String? id,
          String? programWeekId,
          int? ordinal,
          String? name,
          int? plannedWeekday,
          Value<int?> plannedStartMinute = const Value.absent(),
          Value<String?> notes = const Value.absent()}) =>
      SessionTemplate(
        id: id ?? this.id,
        programWeekId: programWeekId ?? this.programWeekId,
        ordinal: ordinal ?? this.ordinal,
        name: name ?? this.name,
        plannedWeekday: plannedWeekday ?? this.plannedWeekday,
        plannedStartMinute: plannedStartMinute.present
            ? plannedStartMinute.value
            : this.plannedStartMinute,
        notes: notes.present ? notes.value : this.notes,
      );
  SessionTemplate copyWithCompanion(SessionTemplatesCompanion data) {
    return SessionTemplate(
      id: data.id.present ? data.id.value : this.id,
      programWeekId: data.programWeekId.present
          ? data.programWeekId.value
          : this.programWeekId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      name: data.name.present ? data.name.value : this.name,
      plannedWeekday: data.plannedWeekday.present
          ? data.plannedWeekday.value
          : this.plannedWeekday,
      plannedStartMinute: data.plannedStartMinute.present
          ? data.plannedStartMinute.value
          : this.plannedStartMinute,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionTemplate(')
          ..write('id: $id, ')
          ..write('programWeekId: $programWeekId, ')
          ..write('ordinal: $ordinal, ')
          ..write('name: $name, ')
          ..write('plannedWeekday: $plannedWeekday, ')
          ..write('plannedStartMinute: $plannedStartMinute, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, programWeekId, ordinal, name,
      plannedWeekday, plannedStartMinute, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionTemplate &&
          other.id == this.id &&
          other.programWeekId == this.programWeekId &&
          other.ordinal == this.ordinal &&
          other.name == this.name &&
          other.plannedWeekday == this.plannedWeekday &&
          other.plannedStartMinute == this.plannedStartMinute &&
          other.notes == this.notes);
}

class SessionTemplatesCompanion extends UpdateCompanion<SessionTemplate> {
  final Value<String> id;
  final Value<String> programWeekId;
  final Value<int> ordinal;
  final Value<String> name;
  final Value<int> plannedWeekday;
  final Value<int?> plannedStartMinute;
  final Value<String?> notes;
  final Value<int> rowid;
  const SessionTemplatesCompanion({
    this.id = const Value.absent(),
    this.programWeekId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.name = const Value.absent(),
    this.plannedWeekday = const Value.absent(),
    this.plannedStartMinute = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionTemplatesCompanion.insert({
    required String id,
    required String programWeekId,
    required int ordinal,
    required String name,
    required int plannedWeekday,
    this.plannedStartMinute = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        programWeekId = Value(programWeekId),
        ordinal = Value(ordinal),
        name = Value(name),
        plannedWeekday = Value(plannedWeekday);
  static Insertable<SessionTemplate> custom({
    Expression<String>? id,
    Expression<String>? programWeekId,
    Expression<int>? ordinal,
    Expression<String>? name,
    Expression<int>? plannedWeekday,
    Expression<int>? plannedStartMinute,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programWeekId != null) 'program_week_id': programWeekId,
      if (ordinal != null) 'ordinal': ordinal,
      if (name != null) 'name': name,
      if (plannedWeekday != null) 'planned_weekday': plannedWeekday,
      if (plannedStartMinute != null)
        'planned_start_minute': plannedStartMinute,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionTemplatesCompanion copyWith(
      {Value<String>? id,
      Value<String>? programWeekId,
      Value<int>? ordinal,
      Value<String>? name,
      Value<int>? plannedWeekday,
      Value<int?>? plannedStartMinute,
      Value<String?>? notes,
      Value<int>? rowid}) {
    return SessionTemplatesCompanion(
      id: id ?? this.id,
      programWeekId: programWeekId ?? this.programWeekId,
      ordinal: ordinal ?? this.ordinal,
      name: name ?? this.name,
      plannedWeekday: plannedWeekday ?? this.plannedWeekday,
      plannedStartMinute: plannedStartMinute ?? this.plannedStartMinute,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (programWeekId.present) {
      map['program_week_id'] = Variable<String>(programWeekId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (plannedWeekday.present) {
      map['planned_weekday'] = Variable<int>(plannedWeekday.value);
    }
    if (plannedStartMinute.present) {
      map['planned_start_minute'] = Variable<int>(plannedStartMinute.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('programWeekId: $programWeekId, ')
          ..write('ordinal: $ordinal, ')
          ..write('name: $name, ')
          ..write('plannedWeekday: $plannedWeekday, ')
          ..write('plannedStartMinute: $plannedStartMinute, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisePrescriptionsTable extends ExercisePrescriptions
    with TableInfo<$ExercisePrescriptionsTable, ExercisePrescription> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisePrescriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionTemplateIdMeta =
      const VerificationMeta('sessionTemplateId');
  @override
  late final GeneratedColumn<String> sessionTemplateId =
      GeneratedColumn<String>('session_template_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES session_templates (id)'));
  static const VerificationMeta _ordinalMeta =
      const VerificationMeta('ordinal');
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
      'ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _exerciseIdMeta =
      const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
      'exercise_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES exercises (stable_id)'));
  static const VerificationMeta _exerciseNameSnapshotMeta =
      const VerificationMeta('exerciseNameSnapshot');
  @override
  late final GeneratedColumn<String> exerciseNameSnapshot =
      GeneratedColumn<String>('exercise_name_snapshot', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plannedSetsMeta =
      const VerificationMeta('plannedSets');
  @override
  late final GeneratedColumn<int> plannedSets = GeneratedColumn<int>(
      'planned_sets', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _repsRangeMeta =
      const VerificationMeta('repsRange');
  @override
  late final GeneratedColumn<String> repsRange = GeneratedColumn<String>(
      'reps_range', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionTemplateId,
        ordinal,
        exerciseId,
        exerciseNameSnapshot,
        plannedSets,
        repsRange
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_prescriptions';
  @override
  VerificationContext validateIntegrity(
      Insertable<ExercisePrescription> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_template_id')) {
      context.handle(
          _sessionTemplateIdMeta,
          sessionTemplateId.isAcceptableOrUnknown(
              data['session_template_id']!, _sessionTemplateIdMeta));
    } else if (isInserting) {
      context.missing(_sessionTemplateIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(_ordinalMeta,
          ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta));
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
          _exerciseIdMeta,
          exerciseId.isAcceptableOrUnknown(
              data['exercise_id']!, _exerciseIdMeta));
    }
    if (data.containsKey('exercise_name_snapshot')) {
      context.handle(
          _exerciseNameSnapshotMeta,
          exerciseNameSnapshot.isAcceptableOrUnknown(
              data['exercise_name_snapshot']!, _exerciseNameSnapshotMeta));
    } else if (isInserting) {
      context.missing(_exerciseNameSnapshotMeta);
    }
    if (data.containsKey('planned_sets')) {
      context.handle(
          _plannedSetsMeta,
          plannedSets.isAcceptableOrUnknown(
              data['planned_sets']!, _plannedSetsMeta));
    } else if (isInserting) {
      context.missing(_plannedSetsMeta);
    }
    if (data.containsKey('reps_range')) {
      context.handle(_repsRangeMeta,
          repsRange.isAcceptableOrUnknown(data['reps_range']!, _repsRangeMeta));
    } else if (isInserting) {
      context.missing(_repsRangeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {sessionTemplateId, ordinal},
      ];
  @override
  ExercisePrescription map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExercisePrescription(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionTemplateId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}session_template_id'])!,
      ordinal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ordinal'])!,
      exerciseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_id']),
      exerciseNameSnapshot: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}exercise_name_snapshot'])!,
      plannedSets: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}planned_sets'])!,
      repsRange: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reps_range'])!,
    );
  }

  @override
  $ExercisePrescriptionsTable createAlias(String alias) {
    return $ExercisePrescriptionsTable(attachedDatabase, alias);
  }
}

class ExercisePrescription extends DataClass
    implements Insertable<ExercisePrescription> {
  final String id;
  final String sessionTemplateId;
  final int ordinal;

  /// A nullable stable ID preserves unresolved migration/import data.
  final String? exerciseId;
  final String exerciseNameSnapshot;
  final int plannedSets;
  final String repsRange;
  const ExercisePrescription(
      {required this.id,
      required this.sessionTemplateId,
      required this.ordinal,
      this.exerciseId,
      required this.exerciseNameSnapshot,
      required this.plannedSets,
      required this.repsRange});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_template_id'] = Variable<String>(sessionTemplateId);
    map['ordinal'] = Variable<int>(ordinal);
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<String>(exerciseId);
    }
    map['exercise_name_snapshot'] = Variable<String>(exerciseNameSnapshot);
    map['planned_sets'] = Variable<int>(plannedSets);
    map['reps_range'] = Variable<String>(repsRange);
    return map;
  }

  ExercisePrescriptionsCompanion toCompanion(bool nullToAbsent) {
    return ExercisePrescriptionsCompanion(
      id: Value(id),
      sessionTemplateId: Value(sessionTemplateId),
      ordinal: Value(ordinal),
      exerciseId: exerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseId),
      exerciseNameSnapshot: Value(exerciseNameSnapshot),
      plannedSets: Value(plannedSets),
      repsRange: Value(repsRange),
    );
  }

  factory ExercisePrescription.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExercisePrescription(
      id: serializer.fromJson<String>(json['id']),
      sessionTemplateId: serializer.fromJson<String>(json['sessionTemplateId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      exerciseId: serializer.fromJson<String?>(json['exerciseId']),
      exerciseNameSnapshot:
          serializer.fromJson<String>(json['exerciseNameSnapshot']),
      plannedSets: serializer.fromJson<int>(json['plannedSets']),
      repsRange: serializer.fromJson<String>(json['repsRange']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionTemplateId': serializer.toJson<String>(sessionTemplateId),
      'ordinal': serializer.toJson<int>(ordinal),
      'exerciseId': serializer.toJson<String?>(exerciseId),
      'exerciseNameSnapshot': serializer.toJson<String>(exerciseNameSnapshot),
      'plannedSets': serializer.toJson<int>(plannedSets),
      'repsRange': serializer.toJson<String>(repsRange),
    };
  }

  ExercisePrescription copyWith(
          {String? id,
          String? sessionTemplateId,
          int? ordinal,
          Value<String?> exerciseId = const Value.absent(),
          String? exerciseNameSnapshot,
          int? plannedSets,
          String? repsRange}) =>
      ExercisePrescription(
        id: id ?? this.id,
        sessionTemplateId: sessionTemplateId ?? this.sessionTemplateId,
        ordinal: ordinal ?? this.ordinal,
        exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
        exerciseNameSnapshot: exerciseNameSnapshot ?? this.exerciseNameSnapshot,
        plannedSets: plannedSets ?? this.plannedSets,
        repsRange: repsRange ?? this.repsRange,
      );
  ExercisePrescription copyWithCompanion(ExercisePrescriptionsCompanion data) {
    return ExercisePrescription(
      id: data.id.present ? data.id.value : this.id,
      sessionTemplateId: data.sessionTemplateId.present
          ? data.sessionTemplateId.value
          : this.sessionTemplateId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      exerciseNameSnapshot: data.exerciseNameSnapshot.present
          ? data.exerciseNameSnapshot.value
          : this.exerciseNameSnapshot,
      plannedSets:
          data.plannedSets.present ? data.plannedSets.value : this.plannedSets,
      repsRange: data.repsRange.present ? data.repsRange.value : this.repsRange,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExercisePrescription(')
          ..write('id: $id, ')
          ..write('sessionTemplateId: $sessionTemplateId, ')
          ..write('ordinal: $ordinal, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseNameSnapshot: $exerciseNameSnapshot, ')
          ..write('plannedSets: $plannedSets, ')
          ..write('repsRange: $repsRange')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionTemplateId, ordinal, exerciseId,
      exerciseNameSnapshot, plannedSets, repsRange);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExercisePrescription &&
          other.id == this.id &&
          other.sessionTemplateId == this.sessionTemplateId &&
          other.ordinal == this.ordinal &&
          other.exerciseId == this.exerciseId &&
          other.exerciseNameSnapshot == this.exerciseNameSnapshot &&
          other.plannedSets == this.plannedSets &&
          other.repsRange == this.repsRange);
}

class ExercisePrescriptionsCompanion
    extends UpdateCompanion<ExercisePrescription> {
  final Value<String> id;
  final Value<String> sessionTemplateId;
  final Value<int> ordinal;
  final Value<String?> exerciseId;
  final Value<String> exerciseNameSnapshot;
  final Value<int> plannedSets;
  final Value<String> repsRange;
  final Value<int> rowid;
  const ExercisePrescriptionsCompanion({
    this.id = const Value.absent(),
    this.sessionTemplateId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.exerciseNameSnapshot = const Value.absent(),
    this.plannedSets = const Value.absent(),
    this.repsRange = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisePrescriptionsCompanion.insert({
    required String id,
    required String sessionTemplateId,
    required int ordinal,
    this.exerciseId = const Value.absent(),
    required String exerciseNameSnapshot,
    required int plannedSets,
    required String repsRange,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionTemplateId = Value(sessionTemplateId),
        ordinal = Value(ordinal),
        exerciseNameSnapshot = Value(exerciseNameSnapshot),
        plannedSets = Value(plannedSets),
        repsRange = Value(repsRange);
  static Insertable<ExercisePrescription> custom({
    Expression<String>? id,
    Expression<String>? sessionTemplateId,
    Expression<int>? ordinal,
    Expression<String>? exerciseId,
    Expression<String>? exerciseNameSnapshot,
    Expression<int>? plannedSets,
    Expression<String>? repsRange,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionTemplateId != null) 'session_template_id': sessionTemplateId,
      if (ordinal != null) 'ordinal': ordinal,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (exerciseNameSnapshot != null)
        'exercise_name_snapshot': exerciseNameSnapshot,
      if (plannedSets != null) 'planned_sets': plannedSets,
      if (repsRange != null) 'reps_range': repsRange,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisePrescriptionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionTemplateId,
      Value<int>? ordinal,
      Value<String?>? exerciseId,
      Value<String>? exerciseNameSnapshot,
      Value<int>? plannedSets,
      Value<String>? repsRange,
      Value<int>? rowid}) {
    return ExercisePrescriptionsCompanion(
      id: id ?? this.id,
      sessionTemplateId: sessionTemplateId ?? this.sessionTemplateId,
      ordinal: ordinal ?? this.ordinal,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseNameSnapshot: exerciseNameSnapshot ?? this.exerciseNameSnapshot,
      plannedSets: plannedSets ?? this.plannedSets,
      repsRange: repsRange ?? this.repsRange,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionTemplateId.present) {
      map['session_template_id'] = Variable<String>(sessionTemplateId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (exerciseNameSnapshot.present) {
      map['exercise_name_snapshot'] =
          Variable<String>(exerciseNameSnapshot.value);
    }
    if (plannedSets.present) {
      map['planned_sets'] = Variable<int>(plannedSets.value);
    }
    if (repsRange.present) {
      map['reps_range'] = Variable<String>(repsRange.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisePrescriptionsCompanion(')
          ..write('id: $id, ')
          ..write('sessionTemplateId: $sessionTemplateId, ')
          ..write('ordinal: $ordinal, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseNameSnapshot: $exerciseNameSnapshot, ')
          ..write('plannedSets: $plannedSets, ')
          ..write('repsRange: $repsRange, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduledSessionOccurrencesTable extends ScheduledSessionOccurrences
    with
        TableInfo<$ScheduledSessionOccurrencesTable,
            ScheduledSessionOccurrence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledSessionOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _programVersionIdMeta =
      const VerificationMeta('programVersionId');
  @override
  late final GeneratedColumn<String> programVersionId = GeneratedColumn<String>(
      'program_version_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES program_versions (id)'));
  static const VerificationMeta _sessionTemplateIdMeta =
      const VerificationMeta('sessionTemplateId');
  @override
  late final GeneratedColumn<String> sessionTemplateId =
      GeneratedColumn<String>('session_template_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES session_templates (id)'));
  static const VerificationMeta _programBlockOrdinalMeta =
      const VerificationMeta('programBlockOrdinal');
  @override
  late final GeneratedColumn<int> programBlockOrdinal = GeneratedColumn<int>(
      'program_block_ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _programWeekOrdinalMeta =
      const VerificationMeta('programWeekOrdinal');
  @override
  late final GeneratedColumn<int> programWeekOrdinal = GeneratedColumn<int>(
      'program_week_ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sessionOrdinalMeta =
      const VerificationMeta('sessionOrdinal');
  @override
  late final GeneratedColumn<int> sessionOrdinal = GeneratedColumn<int>(
      'session_ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _repeatOrdinalMeta =
      const VerificationMeta('repeatOrdinal');
  @override
  late final GeneratedColumn<int> repeatOrdinal = GeneratedColumn<int>(
      'repeat_ordinal', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _originalLocalDateMeta =
      const VerificationMeta('originalLocalDate');
  @override
  late final GeneratedColumn<String> originalLocalDate =
      GeneratedColumn<String>('original_local_date', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalTimezoneIdMeta =
      const VerificationMeta('originalTimezoneId');
  @override
  late final GeneratedColumn<String> originalTimezoneId =
      GeneratedColumn<String>('original_timezone_id', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _effectiveLocalDateMeta =
      const VerificationMeta('effectiveLocalDate');
  @override
  late final GeneratedColumn<String> effectiveLocalDate =
      GeneratedColumn<String>('effective_local_date', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _effectiveTimezoneIdMeta =
      const VerificationMeta('effectiveTimezoneId');
  @override
  late final GeneratedColumn<String> effectiveTimezoneId =
      GeneratedColumn<String>('effective_timezone_id', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('planned'));
  static const VerificationMeta _progressionDispositionMeta =
      const VerificationMeta('progressionDisposition');
  @override
  late final GeneratedColumn<String> progressionDisposition =
      GeneratedColumn<String>('progression_disposition', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('pending'));
  static const VerificationMeta _skipModeMeta =
      const VerificationMeta('skipMode');
  @override
  late final GeneratedColumn<String> skipMode = GeneratedColumn<String>(
      'skip_mode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _repeatPurposeMeta =
      const VerificationMeta('repeatPurpose');
  @override
  late final GeneratedColumn<String> repeatPurpose = GeneratedColumn<String>(
      'repeat_purpose', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _repeatedFromOccurrenceIdMeta =
      const VerificationMeta('repeatedFromOccurrenceId');
  @override
  late final GeneratedColumn<String> repeatedFromOccurrenceId =
      GeneratedColumn<String>('repeated_from_occurrence_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES scheduled_session_occurrences (id)'));
  static const VerificationMeta _executionSnapshotJsonMeta =
      const VerificationMeta('executionSnapshotJson');
  @override
  late final GeneratedColumn<String> executionSnapshotJson =
      GeneratedColumn<String>('execution_snapshot_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedAtUtcMeta =
      const VerificationMeta('startedAtUtc');
  @override
  late final GeneratedColumn<DateTime> startedAtUtc = GeneratedColumn<DateTime>(
      'started_at_utc', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _terminalAtUtcMeta =
      const VerificationMeta('terminalAtUtc');
  @override
  late final GeneratedColumn<DateTime> terminalAtUtc =
      GeneratedColumn<DateTime>('terminal_at_utc', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        programVersionId,
        sessionTemplateId,
        programBlockOrdinal,
        programWeekOrdinal,
        sessionOrdinal,
        repeatOrdinal,
        originalLocalDate,
        originalTimezoneId,
        effectiveLocalDate,
        effectiveTimezoneId,
        status,
        progressionDisposition,
        skipMode,
        repeatPurpose,
        repeatedFromOccurrenceId,
        executionSnapshotJson,
        startedAtUtc,
        terminalAtUtc,
        createdAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_session_occurrences';
  @override
  VerificationContext validateIntegrity(
      Insertable<ScheduledSessionOccurrence> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('program_version_id')) {
      context.handle(
          _programVersionIdMeta,
          programVersionId.isAcceptableOrUnknown(
              data['program_version_id']!, _programVersionIdMeta));
    } else if (isInserting) {
      context.missing(_programVersionIdMeta);
    }
    if (data.containsKey('session_template_id')) {
      context.handle(
          _sessionTemplateIdMeta,
          sessionTemplateId.isAcceptableOrUnknown(
              data['session_template_id']!, _sessionTemplateIdMeta));
    } else if (isInserting) {
      context.missing(_sessionTemplateIdMeta);
    }
    if (data.containsKey('program_block_ordinal')) {
      context.handle(
          _programBlockOrdinalMeta,
          programBlockOrdinal.isAcceptableOrUnknown(
              data['program_block_ordinal']!, _programBlockOrdinalMeta));
    } else if (isInserting) {
      context.missing(_programBlockOrdinalMeta);
    }
    if (data.containsKey('program_week_ordinal')) {
      context.handle(
          _programWeekOrdinalMeta,
          programWeekOrdinal.isAcceptableOrUnknown(
              data['program_week_ordinal']!, _programWeekOrdinalMeta));
    } else if (isInserting) {
      context.missing(_programWeekOrdinalMeta);
    }
    if (data.containsKey('session_ordinal')) {
      context.handle(
          _sessionOrdinalMeta,
          sessionOrdinal.isAcceptableOrUnknown(
              data['session_ordinal']!, _sessionOrdinalMeta));
    } else if (isInserting) {
      context.missing(_sessionOrdinalMeta);
    }
    if (data.containsKey('repeat_ordinal')) {
      context.handle(
          _repeatOrdinalMeta,
          repeatOrdinal.isAcceptableOrUnknown(
              data['repeat_ordinal']!, _repeatOrdinalMeta));
    }
    if (data.containsKey('original_local_date')) {
      context.handle(
          _originalLocalDateMeta,
          originalLocalDate.isAcceptableOrUnknown(
              data['original_local_date']!, _originalLocalDateMeta));
    } else if (isInserting) {
      context.missing(_originalLocalDateMeta);
    }
    if (data.containsKey('original_timezone_id')) {
      context.handle(
          _originalTimezoneIdMeta,
          originalTimezoneId.isAcceptableOrUnknown(
              data['original_timezone_id']!, _originalTimezoneIdMeta));
    } else if (isInserting) {
      context.missing(_originalTimezoneIdMeta);
    }
    if (data.containsKey('effective_local_date')) {
      context.handle(
          _effectiveLocalDateMeta,
          effectiveLocalDate.isAcceptableOrUnknown(
              data['effective_local_date']!, _effectiveLocalDateMeta));
    } else if (isInserting) {
      context.missing(_effectiveLocalDateMeta);
    }
    if (data.containsKey('effective_timezone_id')) {
      context.handle(
          _effectiveTimezoneIdMeta,
          effectiveTimezoneId.isAcceptableOrUnknown(
              data['effective_timezone_id']!, _effectiveTimezoneIdMeta));
    } else if (isInserting) {
      context.missing(_effectiveTimezoneIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('progression_disposition')) {
      context.handle(
          _progressionDispositionMeta,
          progressionDisposition.isAcceptableOrUnknown(
              data['progression_disposition']!, _progressionDispositionMeta));
    }
    if (data.containsKey('skip_mode')) {
      context.handle(_skipModeMeta,
          skipMode.isAcceptableOrUnknown(data['skip_mode']!, _skipModeMeta));
    }
    if (data.containsKey('repeat_purpose')) {
      context.handle(
          _repeatPurposeMeta,
          repeatPurpose.isAcceptableOrUnknown(
              data['repeat_purpose']!, _repeatPurposeMeta));
    }
    if (data.containsKey('repeated_from_occurrence_id')) {
      context.handle(
          _repeatedFromOccurrenceIdMeta,
          repeatedFromOccurrenceId.isAcceptableOrUnknown(
              data['repeated_from_occurrence_id']!,
              _repeatedFromOccurrenceIdMeta));
    }
    if (data.containsKey('execution_snapshot_json')) {
      context.handle(
          _executionSnapshotJsonMeta,
          executionSnapshotJson.isAcceptableOrUnknown(
              data['execution_snapshot_json']!, _executionSnapshotJsonMeta));
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
          _startedAtUtcMeta,
          startedAtUtc.isAcceptableOrUnknown(
              data['started_at_utc']!, _startedAtUtcMeta));
    }
    if (data.containsKey('terminal_at_utc')) {
      context.handle(
          _terminalAtUtcMeta,
          terminalAtUtc.isAcceptableOrUnknown(
              data['terminal_at_utc']!, _terminalAtUtcMeta));
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {
          programVersionId,
          programWeekOrdinal,
          sessionTemplateId,
          repeatOrdinal
        },
      ];
  @override
  ScheduledSessionOccurrence map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledSessionOccurrence(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      programVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}program_version_id'])!,
      sessionTemplateId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}session_template_id'])!,
      programBlockOrdinal: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}program_block_ordinal'])!,
      programWeekOrdinal: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}program_week_ordinal'])!,
      sessionOrdinal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_ordinal'])!,
      repeatOrdinal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}repeat_ordinal'])!,
      originalLocalDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}original_local_date'])!,
      originalTimezoneId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}original_timezone_id'])!,
      effectiveLocalDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}effective_local_date'])!,
      effectiveTimezoneId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}effective_timezone_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      progressionDisposition: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}progression_disposition'])!,
      skipMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skip_mode']),
      repeatPurpose: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}repeat_purpose']),
      repeatedFromOccurrenceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}repeated_from_occurrence_id']),
      executionSnapshotJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}execution_snapshot_json']),
      startedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}started_at_utc']),
      terminalAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}terminal_at_utc']),
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
    );
  }

  @override
  $ScheduledSessionOccurrencesTable createAlias(String alias) {
    return $ScheduledSessionOccurrencesTable(attachedDatabase, alias);
  }
}

class ScheduledSessionOccurrence extends DataClass
    implements Insertable<ScheduledSessionOccurrence> {
  final String id;
  final String programVersionId;
  final String sessionTemplateId;
  final int programBlockOrdinal;
  final int programWeekOrdinal;
  final int sessionOrdinal;
  final int repeatOrdinal;
  final String originalLocalDate;
  final String originalTimezoneId;
  final String effectiveLocalDate;
  final String effectiveTimezoneId;
  final String status;
  final String progressionDisposition;
  final String? skipMode;
  final String? repeatPurpose;
  final String? repeatedFromOccurrenceId;
  final String? executionSnapshotJson;
  final DateTime? startedAtUtc;
  final DateTime? terminalAtUtc;
  final DateTime createdAtUtc;
  const ScheduledSessionOccurrence(
      {required this.id,
      required this.programVersionId,
      required this.sessionTemplateId,
      required this.programBlockOrdinal,
      required this.programWeekOrdinal,
      required this.sessionOrdinal,
      required this.repeatOrdinal,
      required this.originalLocalDate,
      required this.originalTimezoneId,
      required this.effectiveLocalDate,
      required this.effectiveTimezoneId,
      required this.status,
      required this.progressionDisposition,
      this.skipMode,
      this.repeatPurpose,
      this.repeatedFromOccurrenceId,
      this.executionSnapshotJson,
      this.startedAtUtc,
      this.terminalAtUtc,
      required this.createdAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['program_version_id'] = Variable<String>(programVersionId);
    map['session_template_id'] = Variable<String>(sessionTemplateId);
    map['program_block_ordinal'] = Variable<int>(programBlockOrdinal);
    map['program_week_ordinal'] = Variable<int>(programWeekOrdinal);
    map['session_ordinal'] = Variable<int>(sessionOrdinal);
    map['repeat_ordinal'] = Variable<int>(repeatOrdinal);
    map['original_local_date'] = Variable<String>(originalLocalDate);
    map['original_timezone_id'] = Variable<String>(originalTimezoneId);
    map['effective_local_date'] = Variable<String>(effectiveLocalDate);
    map['effective_timezone_id'] = Variable<String>(effectiveTimezoneId);
    map['status'] = Variable<String>(status);
    map['progression_disposition'] = Variable<String>(progressionDisposition);
    if (!nullToAbsent || skipMode != null) {
      map['skip_mode'] = Variable<String>(skipMode);
    }
    if (!nullToAbsent || repeatPurpose != null) {
      map['repeat_purpose'] = Variable<String>(repeatPurpose);
    }
    if (!nullToAbsent || repeatedFromOccurrenceId != null) {
      map['repeated_from_occurrence_id'] =
          Variable<String>(repeatedFromOccurrenceId);
    }
    if (!nullToAbsent || executionSnapshotJson != null) {
      map['execution_snapshot_json'] = Variable<String>(executionSnapshotJson);
    }
    if (!nullToAbsent || startedAtUtc != null) {
      map['started_at_utc'] = Variable<DateTime>(startedAtUtc);
    }
    if (!nullToAbsent || terminalAtUtc != null) {
      map['terminal_at_utc'] = Variable<DateTime>(terminalAtUtc);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    return map;
  }

  ScheduledSessionOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return ScheduledSessionOccurrencesCompanion(
      id: Value(id),
      programVersionId: Value(programVersionId),
      sessionTemplateId: Value(sessionTemplateId),
      programBlockOrdinal: Value(programBlockOrdinal),
      programWeekOrdinal: Value(programWeekOrdinal),
      sessionOrdinal: Value(sessionOrdinal),
      repeatOrdinal: Value(repeatOrdinal),
      originalLocalDate: Value(originalLocalDate),
      originalTimezoneId: Value(originalTimezoneId),
      effectiveLocalDate: Value(effectiveLocalDate),
      effectiveTimezoneId: Value(effectiveTimezoneId),
      status: Value(status),
      progressionDisposition: Value(progressionDisposition),
      skipMode: skipMode == null && nullToAbsent
          ? const Value.absent()
          : Value(skipMode),
      repeatPurpose: repeatPurpose == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatPurpose),
      repeatedFromOccurrenceId: repeatedFromOccurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatedFromOccurrenceId),
      executionSnapshotJson: executionSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(executionSnapshotJson),
      startedAtUtc: startedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAtUtc),
      terminalAtUtc: terminalAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(terminalAtUtc),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory ScheduledSessionOccurrence.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledSessionOccurrence(
      id: serializer.fromJson<String>(json['id']),
      programVersionId: serializer.fromJson<String>(json['programVersionId']),
      sessionTemplateId: serializer.fromJson<String>(json['sessionTemplateId']),
      programBlockOrdinal:
          serializer.fromJson<int>(json['programBlockOrdinal']),
      programWeekOrdinal: serializer.fromJson<int>(json['programWeekOrdinal']),
      sessionOrdinal: serializer.fromJson<int>(json['sessionOrdinal']),
      repeatOrdinal: serializer.fromJson<int>(json['repeatOrdinal']),
      originalLocalDate: serializer.fromJson<String>(json['originalLocalDate']),
      originalTimezoneId:
          serializer.fromJson<String>(json['originalTimezoneId']),
      effectiveLocalDate:
          serializer.fromJson<String>(json['effectiveLocalDate']),
      effectiveTimezoneId:
          serializer.fromJson<String>(json['effectiveTimezoneId']),
      status: serializer.fromJson<String>(json['status']),
      progressionDisposition:
          serializer.fromJson<String>(json['progressionDisposition']),
      skipMode: serializer.fromJson<String?>(json['skipMode']),
      repeatPurpose: serializer.fromJson<String?>(json['repeatPurpose']),
      repeatedFromOccurrenceId:
          serializer.fromJson<String?>(json['repeatedFromOccurrenceId']),
      executionSnapshotJson:
          serializer.fromJson<String?>(json['executionSnapshotJson']),
      startedAtUtc: serializer.fromJson<DateTime?>(json['startedAtUtc']),
      terminalAtUtc: serializer.fromJson<DateTime?>(json['terminalAtUtc']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'programVersionId': serializer.toJson<String>(programVersionId),
      'sessionTemplateId': serializer.toJson<String>(sessionTemplateId),
      'programBlockOrdinal': serializer.toJson<int>(programBlockOrdinal),
      'programWeekOrdinal': serializer.toJson<int>(programWeekOrdinal),
      'sessionOrdinal': serializer.toJson<int>(sessionOrdinal),
      'repeatOrdinal': serializer.toJson<int>(repeatOrdinal),
      'originalLocalDate': serializer.toJson<String>(originalLocalDate),
      'originalTimezoneId': serializer.toJson<String>(originalTimezoneId),
      'effectiveLocalDate': serializer.toJson<String>(effectiveLocalDate),
      'effectiveTimezoneId': serializer.toJson<String>(effectiveTimezoneId),
      'status': serializer.toJson<String>(status),
      'progressionDisposition':
          serializer.toJson<String>(progressionDisposition),
      'skipMode': serializer.toJson<String?>(skipMode),
      'repeatPurpose': serializer.toJson<String?>(repeatPurpose),
      'repeatedFromOccurrenceId':
          serializer.toJson<String?>(repeatedFromOccurrenceId),
      'executionSnapshotJson':
          serializer.toJson<String?>(executionSnapshotJson),
      'startedAtUtc': serializer.toJson<DateTime?>(startedAtUtc),
      'terminalAtUtc': serializer.toJson<DateTime?>(terminalAtUtc),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
    };
  }

  ScheduledSessionOccurrence copyWith(
          {String? id,
          String? programVersionId,
          String? sessionTemplateId,
          int? programBlockOrdinal,
          int? programWeekOrdinal,
          int? sessionOrdinal,
          int? repeatOrdinal,
          String? originalLocalDate,
          String? originalTimezoneId,
          String? effectiveLocalDate,
          String? effectiveTimezoneId,
          String? status,
          String? progressionDisposition,
          Value<String?> skipMode = const Value.absent(),
          Value<String?> repeatPurpose = const Value.absent(),
          Value<String?> repeatedFromOccurrenceId = const Value.absent(),
          Value<String?> executionSnapshotJson = const Value.absent(),
          Value<DateTime?> startedAtUtc = const Value.absent(),
          Value<DateTime?> terminalAtUtc = const Value.absent(),
          DateTime? createdAtUtc}) =>
      ScheduledSessionOccurrence(
        id: id ?? this.id,
        programVersionId: programVersionId ?? this.programVersionId,
        sessionTemplateId: sessionTemplateId ?? this.sessionTemplateId,
        programBlockOrdinal: programBlockOrdinal ?? this.programBlockOrdinal,
        programWeekOrdinal: programWeekOrdinal ?? this.programWeekOrdinal,
        sessionOrdinal: sessionOrdinal ?? this.sessionOrdinal,
        repeatOrdinal: repeatOrdinal ?? this.repeatOrdinal,
        originalLocalDate: originalLocalDate ?? this.originalLocalDate,
        originalTimezoneId: originalTimezoneId ?? this.originalTimezoneId,
        effectiveLocalDate: effectiveLocalDate ?? this.effectiveLocalDate,
        effectiveTimezoneId: effectiveTimezoneId ?? this.effectiveTimezoneId,
        status: status ?? this.status,
        progressionDisposition:
            progressionDisposition ?? this.progressionDisposition,
        skipMode: skipMode.present ? skipMode.value : this.skipMode,
        repeatPurpose:
            repeatPurpose.present ? repeatPurpose.value : this.repeatPurpose,
        repeatedFromOccurrenceId: repeatedFromOccurrenceId.present
            ? repeatedFromOccurrenceId.value
            : this.repeatedFromOccurrenceId,
        executionSnapshotJson: executionSnapshotJson.present
            ? executionSnapshotJson.value
            : this.executionSnapshotJson,
        startedAtUtc:
            startedAtUtc.present ? startedAtUtc.value : this.startedAtUtc,
        terminalAtUtc:
            terminalAtUtc.present ? terminalAtUtc.value : this.terminalAtUtc,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      );
  ScheduledSessionOccurrence copyWithCompanion(
      ScheduledSessionOccurrencesCompanion data) {
    return ScheduledSessionOccurrence(
      id: data.id.present ? data.id.value : this.id,
      programVersionId: data.programVersionId.present
          ? data.programVersionId.value
          : this.programVersionId,
      sessionTemplateId: data.sessionTemplateId.present
          ? data.sessionTemplateId.value
          : this.sessionTemplateId,
      programBlockOrdinal: data.programBlockOrdinal.present
          ? data.programBlockOrdinal.value
          : this.programBlockOrdinal,
      programWeekOrdinal: data.programWeekOrdinal.present
          ? data.programWeekOrdinal.value
          : this.programWeekOrdinal,
      sessionOrdinal: data.sessionOrdinal.present
          ? data.sessionOrdinal.value
          : this.sessionOrdinal,
      repeatOrdinal: data.repeatOrdinal.present
          ? data.repeatOrdinal.value
          : this.repeatOrdinal,
      originalLocalDate: data.originalLocalDate.present
          ? data.originalLocalDate.value
          : this.originalLocalDate,
      originalTimezoneId: data.originalTimezoneId.present
          ? data.originalTimezoneId.value
          : this.originalTimezoneId,
      effectiveLocalDate: data.effectiveLocalDate.present
          ? data.effectiveLocalDate.value
          : this.effectiveLocalDate,
      effectiveTimezoneId: data.effectiveTimezoneId.present
          ? data.effectiveTimezoneId.value
          : this.effectiveTimezoneId,
      status: data.status.present ? data.status.value : this.status,
      progressionDisposition: data.progressionDisposition.present
          ? data.progressionDisposition.value
          : this.progressionDisposition,
      skipMode: data.skipMode.present ? data.skipMode.value : this.skipMode,
      repeatPurpose: data.repeatPurpose.present
          ? data.repeatPurpose.value
          : this.repeatPurpose,
      repeatedFromOccurrenceId: data.repeatedFromOccurrenceId.present
          ? data.repeatedFromOccurrenceId.value
          : this.repeatedFromOccurrenceId,
      executionSnapshotJson: data.executionSnapshotJson.present
          ? data.executionSnapshotJson.value
          : this.executionSnapshotJson,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      terminalAtUtc: data.terminalAtUtc.present
          ? data.terminalAtUtc.value
          : this.terminalAtUtc,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledSessionOccurrence(')
          ..write('id: $id, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('sessionTemplateId: $sessionTemplateId, ')
          ..write('programBlockOrdinal: $programBlockOrdinal, ')
          ..write('programWeekOrdinal: $programWeekOrdinal, ')
          ..write('sessionOrdinal: $sessionOrdinal, ')
          ..write('repeatOrdinal: $repeatOrdinal, ')
          ..write('originalLocalDate: $originalLocalDate, ')
          ..write('originalTimezoneId: $originalTimezoneId, ')
          ..write('effectiveLocalDate: $effectiveLocalDate, ')
          ..write('effectiveTimezoneId: $effectiveTimezoneId, ')
          ..write('status: $status, ')
          ..write('progressionDisposition: $progressionDisposition, ')
          ..write('skipMode: $skipMode, ')
          ..write('repeatPurpose: $repeatPurpose, ')
          ..write('repeatedFromOccurrenceId: $repeatedFromOccurrenceId, ')
          ..write('executionSnapshotJson: $executionSnapshotJson, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('terminalAtUtc: $terminalAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      programVersionId,
      sessionTemplateId,
      programBlockOrdinal,
      programWeekOrdinal,
      sessionOrdinal,
      repeatOrdinal,
      originalLocalDate,
      originalTimezoneId,
      effectiveLocalDate,
      effectiveTimezoneId,
      status,
      progressionDisposition,
      skipMode,
      repeatPurpose,
      repeatedFromOccurrenceId,
      executionSnapshotJson,
      startedAtUtc,
      terminalAtUtc,
      createdAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledSessionOccurrence &&
          other.id == this.id &&
          other.programVersionId == this.programVersionId &&
          other.sessionTemplateId == this.sessionTemplateId &&
          other.programBlockOrdinal == this.programBlockOrdinal &&
          other.programWeekOrdinal == this.programWeekOrdinal &&
          other.sessionOrdinal == this.sessionOrdinal &&
          other.repeatOrdinal == this.repeatOrdinal &&
          other.originalLocalDate == this.originalLocalDate &&
          other.originalTimezoneId == this.originalTimezoneId &&
          other.effectiveLocalDate == this.effectiveLocalDate &&
          other.effectiveTimezoneId == this.effectiveTimezoneId &&
          other.status == this.status &&
          other.progressionDisposition == this.progressionDisposition &&
          other.skipMode == this.skipMode &&
          other.repeatPurpose == this.repeatPurpose &&
          other.repeatedFromOccurrenceId == this.repeatedFromOccurrenceId &&
          other.executionSnapshotJson == this.executionSnapshotJson &&
          other.startedAtUtc == this.startedAtUtc &&
          other.terminalAtUtc == this.terminalAtUtc &&
          other.createdAtUtc == this.createdAtUtc);
}

class ScheduledSessionOccurrencesCompanion
    extends UpdateCompanion<ScheduledSessionOccurrence> {
  final Value<String> id;
  final Value<String> programVersionId;
  final Value<String> sessionTemplateId;
  final Value<int> programBlockOrdinal;
  final Value<int> programWeekOrdinal;
  final Value<int> sessionOrdinal;
  final Value<int> repeatOrdinal;
  final Value<String> originalLocalDate;
  final Value<String> originalTimezoneId;
  final Value<String> effectiveLocalDate;
  final Value<String> effectiveTimezoneId;
  final Value<String> status;
  final Value<String> progressionDisposition;
  final Value<String?> skipMode;
  final Value<String?> repeatPurpose;
  final Value<String?> repeatedFromOccurrenceId;
  final Value<String?> executionSnapshotJson;
  final Value<DateTime?> startedAtUtc;
  final Value<DateTime?> terminalAtUtc;
  final Value<DateTime> createdAtUtc;
  final Value<int> rowid;
  const ScheduledSessionOccurrencesCompanion({
    this.id = const Value.absent(),
    this.programVersionId = const Value.absent(),
    this.sessionTemplateId = const Value.absent(),
    this.programBlockOrdinal = const Value.absent(),
    this.programWeekOrdinal = const Value.absent(),
    this.sessionOrdinal = const Value.absent(),
    this.repeatOrdinal = const Value.absent(),
    this.originalLocalDate = const Value.absent(),
    this.originalTimezoneId = const Value.absent(),
    this.effectiveLocalDate = const Value.absent(),
    this.effectiveTimezoneId = const Value.absent(),
    this.status = const Value.absent(),
    this.progressionDisposition = const Value.absent(),
    this.skipMode = const Value.absent(),
    this.repeatPurpose = const Value.absent(),
    this.repeatedFromOccurrenceId = const Value.absent(),
    this.executionSnapshotJson = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.terminalAtUtc = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduledSessionOccurrencesCompanion.insert({
    required String id,
    required String programVersionId,
    required String sessionTemplateId,
    required int programBlockOrdinal,
    required int programWeekOrdinal,
    required int sessionOrdinal,
    this.repeatOrdinal = const Value.absent(),
    required String originalLocalDate,
    required String originalTimezoneId,
    required String effectiveLocalDate,
    required String effectiveTimezoneId,
    this.status = const Value.absent(),
    this.progressionDisposition = const Value.absent(),
    this.skipMode = const Value.absent(),
    this.repeatPurpose = const Value.absent(),
    this.repeatedFromOccurrenceId = const Value.absent(),
    this.executionSnapshotJson = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.terminalAtUtc = const Value.absent(),
    required DateTime createdAtUtc,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        programVersionId = Value(programVersionId),
        sessionTemplateId = Value(sessionTemplateId),
        programBlockOrdinal = Value(programBlockOrdinal),
        programWeekOrdinal = Value(programWeekOrdinal),
        sessionOrdinal = Value(sessionOrdinal),
        originalLocalDate = Value(originalLocalDate),
        originalTimezoneId = Value(originalTimezoneId),
        effectiveLocalDate = Value(effectiveLocalDate),
        effectiveTimezoneId = Value(effectiveTimezoneId),
        createdAtUtc = Value(createdAtUtc);
  static Insertable<ScheduledSessionOccurrence> custom({
    Expression<String>? id,
    Expression<String>? programVersionId,
    Expression<String>? sessionTemplateId,
    Expression<int>? programBlockOrdinal,
    Expression<int>? programWeekOrdinal,
    Expression<int>? sessionOrdinal,
    Expression<int>? repeatOrdinal,
    Expression<String>? originalLocalDate,
    Expression<String>? originalTimezoneId,
    Expression<String>? effectiveLocalDate,
    Expression<String>? effectiveTimezoneId,
    Expression<String>? status,
    Expression<String>? progressionDisposition,
    Expression<String>? skipMode,
    Expression<String>? repeatPurpose,
    Expression<String>? repeatedFromOccurrenceId,
    Expression<String>? executionSnapshotJson,
    Expression<DateTime>? startedAtUtc,
    Expression<DateTime>? terminalAtUtc,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programVersionId != null) 'program_version_id': programVersionId,
      if (sessionTemplateId != null) 'session_template_id': sessionTemplateId,
      if (programBlockOrdinal != null)
        'program_block_ordinal': programBlockOrdinal,
      if (programWeekOrdinal != null)
        'program_week_ordinal': programWeekOrdinal,
      if (sessionOrdinal != null) 'session_ordinal': sessionOrdinal,
      if (repeatOrdinal != null) 'repeat_ordinal': repeatOrdinal,
      if (originalLocalDate != null) 'original_local_date': originalLocalDate,
      if (originalTimezoneId != null)
        'original_timezone_id': originalTimezoneId,
      if (effectiveLocalDate != null)
        'effective_local_date': effectiveLocalDate,
      if (effectiveTimezoneId != null)
        'effective_timezone_id': effectiveTimezoneId,
      if (status != null) 'status': status,
      if (progressionDisposition != null)
        'progression_disposition': progressionDisposition,
      if (skipMode != null) 'skip_mode': skipMode,
      if (repeatPurpose != null) 'repeat_purpose': repeatPurpose,
      if (repeatedFromOccurrenceId != null)
        'repeated_from_occurrence_id': repeatedFromOccurrenceId,
      if (executionSnapshotJson != null)
        'execution_snapshot_json': executionSnapshotJson,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (terminalAtUtc != null) 'terminal_at_utc': terminalAtUtc,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduledSessionOccurrencesCompanion copyWith(
      {Value<String>? id,
      Value<String>? programVersionId,
      Value<String>? sessionTemplateId,
      Value<int>? programBlockOrdinal,
      Value<int>? programWeekOrdinal,
      Value<int>? sessionOrdinal,
      Value<int>? repeatOrdinal,
      Value<String>? originalLocalDate,
      Value<String>? originalTimezoneId,
      Value<String>? effectiveLocalDate,
      Value<String>? effectiveTimezoneId,
      Value<String>? status,
      Value<String>? progressionDisposition,
      Value<String?>? skipMode,
      Value<String?>? repeatPurpose,
      Value<String?>? repeatedFromOccurrenceId,
      Value<String?>? executionSnapshotJson,
      Value<DateTime?>? startedAtUtc,
      Value<DateTime?>? terminalAtUtc,
      Value<DateTime>? createdAtUtc,
      Value<int>? rowid}) {
    return ScheduledSessionOccurrencesCompanion(
      id: id ?? this.id,
      programVersionId: programVersionId ?? this.programVersionId,
      sessionTemplateId: sessionTemplateId ?? this.sessionTemplateId,
      programBlockOrdinal: programBlockOrdinal ?? this.programBlockOrdinal,
      programWeekOrdinal: programWeekOrdinal ?? this.programWeekOrdinal,
      sessionOrdinal: sessionOrdinal ?? this.sessionOrdinal,
      repeatOrdinal: repeatOrdinal ?? this.repeatOrdinal,
      originalLocalDate: originalLocalDate ?? this.originalLocalDate,
      originalTimezoneId: originalTimezoneId ?? this.originalTimezoneId,
      effectiveLocalDate: effectiveLocalDate ?? this.effectiveLocalDate,
      effectiveTimezoneId: effectiveTimezoneId ?? this.effectiveTimezoneId,
      status: status ?? this.status,
      progressionDisposition:
          progressionDisposition ?? this.progressionDisposition,
      skipMode: skipMode ?? this.skipMode,
      repeatPurpose: repeatPurpose ?? this.repeatPurpose,
      repeatedFromOccurrenceId:
          repeatedFromOccurrenceId ?? this.repeatedFromOccurrenceId,
      executionSnapshotJson:
          executionSnapshotJson ?? this.executionSnapshotJson,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      terminalAtUtc: terminalAtUtc ?? this.terminalAtUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (programVersionId.present) {
      map['program_version_id'] = Variable<String>(programVersionId.value);
    }
    if (sessionTemplateId.present) {
      map['session_template_id'] = Variable<String>(sessionTemplateId.value);
    }
    if (programBlockOrdinal.present) {
      map['program_block_ordinal'] = Variable<int>(programBlockOrdinal.value);
    }
    if (programWeekOrdinal.present) {
      map['program_week_ordinal'] = Variable<int>(programWeekOrdinal.value);
    }
    if (sessionOrdinal.present) {
      map['session_ordinal'] = Variable<int>(sessionOrdinal.value);
    }
    if (repeatOrdinal.present) {
      map['repeat_ordinal'] = Variable<int>(repeatOrdinal.value);
    }
    if (originalLocalDate.present) {
      map['original_local_date'] = Variable<String>(originalLocalDate.value);
    }
    if (originalTimezoneId.present) {
      map['original_timezone_id'] = Variable<String>(originalTimezoneId.value);
    }
    if (effectiveLocalDate.present) {
      map['effective_local_date'] = Variable<String>(effectiveLocalDate.value);
    }
    if (effectiveTimezoneId.present) {
      map['effective_timezone_id'] =
          Variable<String>(effectiveTimezoneId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progressionDisposition.present) {
      map['progression_disposition'] =
          Variable<String>(progressionDisposition.value);
    }
    if (skipMode.present) {
      map['skip_mode'] = Variable<String>(skipMode.value);
    }
    if (repeatPurpose.present) {
      map['repeat_purpose'] = Variable<String>(repeatPurpose.value);
    }
    if (repeatedFromOccurrenceId.present) {
      map['repeated_from_occurrence_id'] =
          Variable<String>(repeatedFromOccurrenceId.value);
    }
    if (executionSnapshotJson.present) {
      map['execution_snapshot_json'] =
          Variable<String>(executionSnapshotJson.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<DateTime>(startedAtUtc.value);
    }
    if (terminalAtUtc.present) {
      map['terminal_at_utc'] = Variable<DateTime>(terminalAtUtc.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledSessionOccurrencesCompanion(')
          ..write('id: $id, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('sessionTemplateId: $sessionTemplateId, ')
          ..write('programBlockOrdinal: $programBlockOrdinal, ')
          ..write('programWeekOrdinal: $programWeekOrdinal, ')
          ..write('sessionOrdinal: $sessionOrdinal, ')
          ..write('repeatOrdinal: $repeatOrdinal, ')
          ..write('originalLocalDate: $originalLocalDate, ')
          ..write('originalTimezoneId: $originalTimezoneId, ')
          ..write('effectiveLocalDate: $effectiveLocalDate, ')
          ..write('effectiveTimezoneId: $effectiveTimezoneId, ')
          ..write('status: $status, ')
          ..write('progressionDisposition: $progressionDisposition, ')
          ..write('skipMode: $skipMode, ')
          ..write('repeatPurpose: $repeatPurpose, ')
          ..write('repeatedFromOccurrenceId: $repeatedFromOccurrenceId, ')
          ..write('executionSnapshotJson: $executionSnapshotJson, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('terminalAtUtc: $terminalAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OccurrenceEventsTable extends OccurrenceEvents
    with TableInfo<$OccurrenceEventsTable, OccurrenceEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OccurrenceEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occurrenceIdMeta =
      const VerificationMeta('occurrenceId');
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
      'occurrence_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES scheduled_session_occurrences (id)'));
  static const VerificationMeta _commandIdMeta =
      const VerificationMeta('commandId');
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
      'command_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fromStatusMeta =
      const VerificationMeta('fromStatus');
  @override
  late final GeneratedColumn<String> fromStatus = GeneratedColumn<String>(
      'from_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _toStatusMeta =
      const VerificationMeta('toStatus');
  @override
  late final GeneratedColumn<String> toStatus = GeneratedColumn<String>(
      'to_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _beforeLocalDateMeta =
      const VerificationMeta('beforeLocalDate');
  @override
  late final GeneratedColumn<String> beforeLocalDate = GeneratedColumn<String>(
      'before_local_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _beforeTimezoneIdMeta =
      const VerificationMeta('beforeTimezoneId');
  @override
  late final GeneratedColumn<String> beforeTimezoneId = GeneratedColumn<String>(
      'before_timezone_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _afterLocalDateMeta =
      const VerificationMeta('afterLocalDate');
  @override
  late final GeneratedColumn<String> afterLocalDate = GeneratedColumn<String>(
      'after_local_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _afterTimezoneIdMeta =
      const VerificationMeta('afterTimezoneId');
  @override
  late final GeneratedColumn<String> afterTimezoneId = GeneratedColumn<String>(
      'after_timezone_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _metadataJsonMeta =
      const VerificationMeta('metadataJson');
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
      'metadata_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtUtcMeta =
      const VerificationMeta('occurredAtUtc');
  @override
  late final GeneratedColumn<DateTime> occurredAtUtc =
      GeneratedColumn<DateTime>('occurred_at_utc', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        occurrenceId,
        commandId,
        eventType,
        fromStatus,
        toStatus,
        beforeLocalDate,
        beforeTimezoneId,
        afterLocalDate,
        afterTimezoneId,
        reason,
        metadataJson,
        occurredAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'occurrence_events';
  @override
  VerificationContext validateIntegrity(Insertable<OccurrenceEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
          _occurrenceIdMeta,
          occurrenceId.isAcceptableOrUnknown(
              data['occurrence_id']!, _occurrenceIdMeta));
    } else if (isInserting) {
      context.missing(_occurrenceIdMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(_commandIdMeta,
          commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta));
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('from_status')) {
      context.handle(
          _fromStatusMeta,
          fromStatus.isAcceptableOrUnknown(
              data['from_status']!, _fromStatusMeta));
    }
    if (data.containsKey('to_status')) {
      context.handle(_toStatusMeta,
          toStatus.isAcceptableOrUnknown(data['to_status']!, _toStatusMeta));
    }
    if (data.containsKey('before_local_date')) {
      context.handle(
          _beforeLocalDateMeta,
          beforeLocalDate.isAcceptableOrUnknown(
              data['before_local_date']!, _beforeLocalDateMeta));
    }
    if (data.containsKey('before_timezone_id')) {
      context.handle(
          _beforeTimezoneIdMeta,
          beforeTimezoneId.isAcceptableOrUnknown(
              data['before_timezone_id']!, _beforeTimezoneIdMeta));
    }
    if (data.containsKey('after_local_date')) {
      context.handle(
          _afterLocalDateMeta,
          afterLocalDate.isAcceptableOrUnknown(
              data['after_local_date']!, _afterLocalDateMeta));
    }
    if (data.containsKey('after_timezone_id')) {
      context.handle(
          _afterTimezoneIdMeta,
          afterTimezoneId.isAcceptableOrUnknown(
              data['after_timezone_id']!, _afterTimezoneIdMeta));
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
          _metadataJsonMeta,
          metadataJson.isAcceptableOrUnknown(
              data['metadata_json']!, _metadataJsonMeta));
    }
    if (data.containsKey('occurred_at_utc')) {
      context.handle(
          _occurredAtUtcMeta,
          occurredAtUtc.isAcceptableOrUnknown(
              data['occurred_at_utc']!, _occurredAtUtcMeta));
    } else if (isInserting) {
      context.missing(_occurredAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {occurrenceId, commandId},
      ];
  @override
  OccurrenceEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OccurrenceEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      occurrenceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occurrence_id'])!,
      commandId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}command_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      fromStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_status']),
      toStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_status']),
      beforeLocalDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}before_local_date']),
      beforeTimezoneId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}before_timezone_id']),
      afterLocalDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}after_local_date']),
      afterTimezoneId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}after_timezone_id']),
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason']),
      metadataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata_json']),
      occurredAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}occurred_at_utc'])!,
    );
  }

  @override
  $OccurrenceEventsTable createAlias(String alias) {
    return $OccurrenceEventsTable(attachedDatabase, alias);
  }
}

class OccurrenceEvent extends DataClass implements Insertable<OccurrenceEvent> {
  final String id;
  final String occurrenceId;
  final String commandId;
  final String eventType;
  final String? fromStatus;
  final String? toStatus;
  final String? beforeLocalDate;
  final String? beforeTimezoneId;
  final String? afterLocalDate;
  final String? afterTimezoneId;
  final String? reason;
  final String? metadataJson;
  final DateTime occurredAtUtc;
  const OccurrenceEvent(
      {required this.id,
      required this.occurrenceId,
      required this.commandId,
      required this.eventType,
      this.fromStatus,
      this.toStatus,
      this.beforeLocalDate,
      this.beforeTimezoneId,
      this.afterLocalDate,
      this.afterTimezoneId,
      this.reason,
      this.metadataJson,
      required this.occurredAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['occurrence_id'] = Variable<String>(occurrenceId);
    map['command_id'] = Variable<String>(commandId);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || fromStatus != null) {
      map['from_status'] = Variable<String>(fromStatus);
    }
    if (!nullToAbsent || toStatus != null) {
      map['to_status'] = Variable<String>(toStatus);
    }
    if (!nullToAbsent || beforeLocalDate != null) {
      map['before_local_date'] = Variable<String>(beforeLocalDate);
    }
    if (!nullToAbsent || beforeTimezoneId != null) {
      map['before_timezone_id'] = Variable<String>(beforeTimezoneId);
    }
    if (!nullToAbsent || afterLocalDate != null) {
      map['after_local_date'] = Variable<String>(afterLocalDate);
    }
    if (!nullToAbsent || afterTimezoneId != null) {
      map['after_timezone_id'] = Variable<String>(afterTimezoneId);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    map['occurred_at_utc'] = Variable<DateTime>(occurredAtUtc);
    return map;
  }

  OccurrenceEventsCompanion toCompanion(bool nullToAbsent) {
    return OccurrenceEventsCompanion(
      id: Value(id),
      occurrenceId: Value(occurrenceId),
      commandId: Value(commandId),
      eventType: Value(eventType),
      fromStatus: fromStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(fromStatus),
      toStatus: toStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(toStatus),
      beforeLocalDate: beforeLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeLocalDate),
      beforeTimezoneId: beforeTimezoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeTimezoneId),
      afterLocalDate: afterLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(afterLocalDate),
      afterTimezoneId: afterTimezoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(afterTimezoneId),
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      occurredAtUtc: Value(occurredAtUtc),
    );
  }

  factory OccurrenceEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OccurrenceEvent(
      id: serializer.fromJson<String>(json['id']),
      occurrenceId: serializer.fromJson<String>(json['occurrenceId']),
      commandId: serializer.fromJson<String>(json['commandId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      fromStatus: serializer.fromJson<String?>(json['fromStatus']),
      toStatus: serializer.fromJson<String?>(json['toStatus']),
      beforeLocalDate: serializer.fromJson<String?>(json['beforeLocalDate']),
      beforeTimezoneId: serializer.fromJson<String?>(json['beforeTimezoneId']),
      afterLocalDate: serializer.fromJson<String?>(json['afterLocalDate']),
      afterTimezoneId: serializer.fromJson<String?>(json['afterTimezoneId']),
      reason: serializer.fromJson<String?>(json['reason']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      occurredAtUtc: serializer.fromJson<DateTime>(json['occurredAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'occurrenceId': serializer.toJson<String>(occurrenceId),
      'commandId': serializer.toJson<String>(commandId),
      'eventType': serializer.toJson<String>(eventType),
      'fromStatus': serializer.toJson<String?>(fromStatus),
      'toStatus': serializer.toJson<String?>(toStatus),
      'beforeLocalDate': serializer.toJson<String?>(beforeLocalDate),
      'beforeTimezoneId': serializer.toJson<String?>(beforeTimezoneId),
      'afterLocalDate': serializer.toJson<String?>(afterLocalDate),
      'afterTimezoneId': serializer.toJson<String?>(afterTimezoneId),
      'reason': serializer.toJson<String?>(reason),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'occurredAtUtc': serializer.toJson<DateTime>(occurredAtUtc),
    };
  }

  OccurrenceEvent copyWith(
          {String? id,
          String? occurrenceId,
          String? commandId,
          String? eventType,
          Value<String?> fromStatus = const Value.absent(),
          Value<String?> toStatus = const Value.absent(),
          Value<String?> beforeLocalDate = const Value.absent(),
          Value<String?> beforeTimezoneId = const Value.absent(),
          Value<String?> afterLocalDate = const Value.absent(),
          Value<String?> afterTimezoneId = const Value.absent(),
          Value<String?> reason = const Value.absent(),
          Value<String?> metadataJson = const Value.absent(),
          DateTime? occurredAtUtc}) =>
      OccurrenceEvent(
        id: id ?? this.id,
        occurrenceId: occurrenceId ?? this.occurrenceId,
        commandId: commandId ?? this.commandId,
        eventType: eventType ?? this.eventType,
        fromStatus: fromStatus.present ? fromStatus.value : this.fromStatus,
        toStatus: toStatus.present ? toStatus.value : this.toStatus,
        beforeLocalDate: beforeLocalDate.present
            ? beforeLocalDate.value
            : this.beforeLocalDate,
        beforeTimezoneId: beforeTimezoneId.present
            ? beforeTimezoneId.value
            : this.beforeTimezoneId,
        afterLocalDate:
            afterLocalDate.present ? afterLocalDate.value : this.afterLocalDate,
        afterTimezoneId: afterTimezoneId.present
            ? afterTimezoneId.value
            : this.afterTimezoneId,
        reason: reason.present ? reason.value : this.reason,
        metadataJson:
            metadataJson.present ? metadataJson.value : this.metadataJson,
        occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      );
  OccurrenceEvent copyWithCompanion(OccurrenceEventsCompanion data) {
    return OccurrenceEvent(
      id: data.id.present ? data.id.value : this.id,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      fromStatus:
          data.fromStatus.present ? data.fromStatus.value : this.fromStatus,
      toStatus: data.toStatus.present ? data.toStatus.value : this.toStatus,
      beforeLocalDate: data.beforeLocalDate.present
          ? data.beforeLocalDate.value
          : this.beforeLocalDate,
      beforeTimezoneId: data.beforeTimezoneId.present
          ? data.beforeTimezoneId.value
          : this.beforeTimezoneId,
      afterLocalDate: data.afterLocalDate.present
          ? data.afterLocalDate.value
          : this.afterLocalDate,
      afterTimezoneId: data.afterTimezoneId.present
          ? data.afterTimezoneId.value
          : this.afterTimezoneId,
      reason: data.reason.present ? data.reason.value : this.reason,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      occurredAtUtc: data.occurredAtUtc.present
          ? data.occurredAtUtc.value
          : this.occurredAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceEvent(')
          ..write('id: $id, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('commandId: $commandId, ')
          ..write('eventType: $eventType, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('beforeLocalDate: $beforeLocalDate, ')
          ..write('beforeTimezoneId: $beforeTimezoneId, ')
          ..write('afterLocalDate: $afterLocalDate, ')
          ..write('afterTimezoneId: $afterTimezoneId, ')
          ..write('reason: $reason, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('occurredAtUtc: $occurredAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      occurrenceId,
      commandId,
      eventType,
      fromStatus,
      toStatus,
      beforeLocalDate,
      beforeTimezoneId,
      afterLocalDate,
      afterTimezoneId,
      reason,
      metadataJson,
      occurredAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OccurrenceEvent &&
          other.id == this.id &&
          other.occurrenceId == this.occurrenceId &&
          other.commandId == this.commandId &&
          other.eventType == this.eventType &&
          other.fromStatus == this.fromStatus &&
          other.toStatus == this.toStatus &&
          other.beforeLocalDate == this.beforeLocalDate &&
          other.beforeTimezoneId == this.beforeTimezoneId &&
          other.afterLocalDate == this.afterLocalDate &&
          other.afterTimezoneId == this.afterTimezoneId &&
          other.reason == this.reason &&
          other.metadataJson == this.metadataJson &&
          other.occurredAtUtc == this.occurredAtUtc);
}

class OccurrenceEventsCompanion extends UpdateCompanion<OccurrenceEvent> {
  final Value<String> id;
  final Value<String> occurrenceId;
  final Value<String> commandId;
  final Value<String> eventType;
  final Value<String?> fromStatus;
  final Value<String?> toStatus;
  final Value<String?> beforeLocalDate;
  final Value<String?> beforeTimezoneId;
  final Value<String?> afterLocalDate;
  final Value<String?> afterTimezoneId;
  final Value<String?> reason;
  final Value<String?> metadataJson;
  final Value<DateTime> occurredAtUtc;
  final Value<int> rowid;
  const OccurrenceEventsCompanion({
    this.id = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.commandId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.fromStatus = const Value.absent(),
    this.toStatus = const Value.absent(),
    this.beforeLocalDate = const Value.absent(),
    this.beforeTimezoneId = const Value.absent(),
    this.afterLocalDate = const Value.absent(),
    this.afterTimezoneId = const Value.absent(),
    this.reason = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.occurredAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OccurrenceEventsCompanion.insert({
    required String id,
    required String occurrenceId,
    required String commandId,
    required String eventType,
    this.fromStatus = const Value.absent(),
    this.toStatus = const Value.absent(),
    this.beforeLocalDate = const Value.absent(),
    this.beforeTimezoneId = const Value.absent(),
    this.afterLocalDate = const Value.absent(),
    this.afterTimezoneId = const Value.absent(),
    this.reason = const Value.absent(),
    this.metadataJson = const Value.absent(),
    required DateTime occurredAtUtc,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        occurrenceId = Value(occurrenceId),
        commandId = Value(commandId),
        eventType = Value(eventType),
        occurredAtUtc = Value(occurredAtUtc);
  static Insertable<OccurrenceEvent> custom({
    Expression<String>? id,
    Expression<String>? occurrenceId,
    Expression<String>? commandId,
    Expression<String>? eventType,
    Expression<String>? fromStatus,
    Expression<String>? toStatus,
    Expression<String>? beforeLocalDate,
    Expression<String>? beforeTimezoneId,
    Expression<String>? afterLocalDate,
    Expression<String>? afterTimezoneId,
    Expression<String>? reason,
    Expression<String>? metadataJson,
    Expression<DateTime>? occurredAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (commandId != null) 'command_id': commandId,
      if (eventType != null) 'event_type': eventType,
      if (fromStatus != null) 'from_status': fromStatus,
      if (toStatus != null) 'to_status': toStatus,
      if (beforeLocalDate != null) 'before_local_date': beforeLocalDate,
      if (beforeTimezoneId != null) 'before_timezone_id': beforeTimezoneId,
      if (afterLocalDate != null) 'after_local_date': afterLocalDate,
      if (afterTimezoneId != null) 'after_timezone_id': afterTimezoneId,
      if (reason != null) 'reason': reason,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (occurredAtUtc != null) 'occurred_at_utc': occurredAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OccurrenceEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? occurrenceId,
      Value<String>? commandId,
      Value<String>? eventType,
      Value<String?>? fromStatus,
      Value<String?>? toStatus,
      Value<String?>? beforeLocalDate,
      Value<String?>? beforeTimezoneId,
      Value<String?>? afterLocalDate,
      Value<String?>? afterTimezoneId,
      Value<String?>? reason,
      Value<String?>? metadataJson,
      Value<DateTime>? occurredAtUtc,
      Value<int>? rowid}) {
    return OccurrenceEventsCompanion(
      id: id ?? this.id,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      commandId: commandId ?? this.commandId,
      eventType: eventType ?? this.eventType,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      beforeLocalDate: beforeLocalDate ?? this.beforeLocalDate,
      beforeTimezoneId: beforeTimezoneId ?? this.beforeTimezoneId,
      afterLocalDate: afterLocalDate ?? this.afterLocalDate,
      afterTimezoneId: afterTimezoneId ?? this.afterTimezoneId,
      reason: reason ?? this.reason,
      metadataJson: metadataJson ?? this.metadataJson,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (fromStatus.present) {
      map['from_status'] = Variable<String>(fromStatus.value);
    }
    if (toStatus.present) {
      map['to_status'] = Variable<String>(toStatus.value);
    }
    if (beforeLocalDate.present) {
      map['before_local_date'] = Variable<String>(beforeLocalDate.value);
    }
    if (beforeTimezoneId.present) {
      map['before_timezone_id'] = Variable<String>(beforeTimezoneId.value);
    }
    if (afterLocalDate.present) {
      map['after_local_date'] = Variable<String>(afterLocalDate.value);
    }
    if (afterTimezoneId.present) {
      map['after_timezone_id'] = Variable<String>(afterTimezoneId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (occurredAtUtc.present) {
      map['occurred_at_utc'] = Variable<DateTime>(occurredAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceEventsCompanion(')
          ..write('id: $id, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('commandId: $commandId, ')
          ..write('eventType: $eventType, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('beforeLocalDate: $beforeLocalDate, ')
          ..write('beforeTimezoneId: $beforeTimezoneId, ')
          ..write('afterLocalDate: $afterLocalDate, ')
          ..write('afterTimezoneId: $afterTimezoneId, ')
          ..write('reason: $reason, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('occurredAtUtc: $occurredAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EquipmentProfilesTable extends EquipmentProfiles
    with TableInfo<$EquipmentProfilesTable, EquipmentProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _defaultWeightIncrementKgMeta =
      const VerificationMeta('defaultWeightIncrementKg');
  @override
  late final GeneratedColumn<double> defaultWeightIncrementKg =
      GeneratedColumn<double>('default_weight_increment_kg', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _legacyAccessCodeMeta =
      const VerificationMeta('legacyAccessCode');
  @override
  late final GeneratedColumn<String> legacyAccessCode = GeneratedColumn<String>(
      'legacy_access_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _archivedAtUtcMeta =
      const VerificationMeta('archivedAtUtc');
  @override
  late final GeneratedColumn<DateTime> archivedAtUtc =
      GeneratedColumn<DateTime>('archived_at_utc', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtUtcMeta =
      const VerificationMeta('updatedAtUtc');
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
      'updated_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        defaultWeightIncrementKg,
        legacyAccessCode,
        note,
        archivedAtUtc,
        createdAtUtc,
        updatedAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<EquipmentProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('default_weight_increment_kg')) {
      context.handle(
          _defaultWeightIncrementKgMeta,
          defaultWeightIncrementKg.isAcceptableOrUnknown(
              data['default_weight_increment_kg']!,
              _defaultWeightIncrementKgMeta));
    }
    if (data.containsKey('legacy_access_code')) {
      context.handle(
          _legacyAccessCodeMeta,
          legacyAccessCode.isAcceptableOrUnknown(
              data['legacy_access_code']!, _legacyAccessCodeMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('archived_at_utc')) {
      context.handle(
          _archivedAtUtcMeta,
          archivedAtUtc.isAcceptableOrUnknown(
              data['archived_at_utc']!, _archivedAtUtcMeta));
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
          _updatedAtUtcMeta,
          updatedAtUtc.isAcceptableOrUnknown(
              data['updated_at_utc']!, _updatedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EquipmentProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      defaultWeightIncrementKg: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}default_weight_increment_kg']),
      legacyAccessCode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}legacy_access_code']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      archivedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}archived_at_utc']),
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}updated_at_utc'])!,
    );
  }

  @override
  $EquipmentProfilesTable createAlias(String alias) {
    return $EquipmentProfilesTable(attachedDatabase, alias);
  }
}

class EquipmentProfile extends DataClass
    implements Insertable<EquipmentProfile> {
  final String id;
  final String name;
  final double? defaultWeightIncrementKg;
  final String? legacyAccessCode;
  final String? note;
  final DateTime? archivedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const EquipmentProfile(
      {required this.id,
      required this.name,
      this.defaultWeightIncrementKg,
      this.legacyAccessCode,
      this.note,
      this.archivedAtUtc,
      required this.createdAtUtc,
      required this.updatedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || defaultWeightIncrementKg != null) {
      map['default_weight_increment_kg'] =
          Variable<double>(defaultWeightIncrementKg);
    }
    if (!nullToAbsent || legacyAccessCode != null) {
      map['legacy_access_code'] = Variable<String>(legacyAccessCode);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || archivedAtUtc != null) {
      map['archived_at_utc'] = Variable<DateTime>(archivedAtUtc);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  EquipmentProfilesCompanion toCompanion(bool nullToAbsent) {
    return EquipmentProfilesCompanion(
      id: Value(id),
      name: Value(name),
      defaultWeightIncrementKg: defaultWeightIncrementKg == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultWeightIncrementKg),
      legacyAccessCode: legacyAccessCode == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyAccessCode),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      archivedAtUtc: archivedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtUtc),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory EquipmentProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      defaultWeightIncrementKg:
          serializer.fromJson<double?>(json['defaultWeightIncrementKg']),
      legacyAccessCode: serializer.fromJson<String?>(json['legacyAccessCode']),
      note: serializer.fromJson<String?>(json['note']),
      archivedAtUtc: serializer.fromJson<DateTime?>(json['archivedAtUtc']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'defaultWeightIncrementKg':
          serializer.toJson<double?>(defaultWeightIncrementKg),
      'legacyAccessCode': serializer.toJson<String?>(legacyAccessCode),
      'note': serializer.toJson<String?>(note),
      'archivedAtUtc': serializer.toJson<DateTime?>(archivedAtUtc),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  EquipmentProfile copyWith(
          {String? id,
          String? name,
          Value<double?> defaultWeightIncrementKg = const Value.absent(),
          Value<String?> legacyAccessCode = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<DateTime?> archivedAtUtc = const Value.absent(),
          DateTime? createdAtUtc,
          DateTime? updatedAtUtc}) =>
      EquipmentProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        defaultWeightIncrementKg: defaultWeightIncrementKg.present
            ? defaultWeightIncrementKg.value
            : this.defaultWeightIncrementKg,
        legacyAccessCode: legacyAccessCode.present
            ? legacyAccessCode.value
            : this.legacyAccessCode,
        note: note.present ? note.value : this.note,
        archivedAtUtc:
            archivedAtUtc.present ? archivedAtUtc.value : this.archivedAtUtc,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      );
  EquipmentProfile copyWithCompanion(EquipmentProfilesCompanion data) {
    return EquipmentProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      defaultWeightIncrementKg: data.defaultWeightIncrementKg.present
          ? data.defaultWeightIncrementKg.value
          : this.defaultWeightIncrementKg,
      legacyAccessCode: data.legacyAccessCode.present
          ? data.legacyAccessCode.value
          : this.legacyAccessCode,
      note: data.note.present ? data.note.value : this.note,
      archivedAtUtc: data.archivedAtUtc.present
          ? data.archivedAtUtc.value
          : this.archivedAtUtc,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('defaultWeightIncrementKg: $defaultWeightIncrementKg, ')
          ..write('legacyAccessCode: $legacyAccessCode, ')
          ..write('note: $note, ')
          ..write('archivedAtUtc: $archivedAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, defaultWeightIncrementKg,
      legacyAccessCode, note, archivedAtUtc, createdAtUtc, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.defaultWeightIncrementKg == this.defaultWeightIncrementKg &&
          other.legacyAccessCode == this.legacyAccessCode &&
          other.note == this.note &&
          other.archivedAtUtc == this.archivedAtUtc &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class EquipmentProfilesCompanion extends UpdateCompanion<EquipmentProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<double?> defaultWeightIncrementKg;
  final Value<String?> legacyAccessCode;
  final Value<String?> note;
  final Value<DateTime?> archivedAtUtc;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const EquipmentProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.defaultWeightIncrementKg = const Value.absent(),
    this.legacyAccessCode = const Value.absent(),
    this.note = const Value.absent(),
    this.archivedAtUtc = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EquipmentProfilesCompanion.insert({
    required String id,
    required String name,
    this.defaultWeightIncrementKg = const Value.absent(),
    this.legacyAccessCode = const Value.absent(),
    this.note = const Value.absent(),
    this.archivedAtUtc = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAtUtc = Value(createdAtUtc),
        updatedAtUtc = Value(updatedAtUtc);
  static Insertable<EquipmentProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? defaultWeightIncrementKg,
    Expression<String>? legacyAccessCode,
    Expression<String>? note,
    Expression<DateTime>? archivedAtUtc,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (defaultWeightIncrementKg != null)
        'default_weight_increment_kg': defaultWeightIncrementKg,
      if (legacyAccessCode != null) 'legacy_access_code': legacyAccessCode,
      if (note != null) 'note': note,
      if (archivedAtUtc != null) 'archived_at_utc': archivedAtUtc,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EquipmentProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double?>? defaultWeightIncrementKg,
      Value<String?>? legacyAccessCode,
      Value<String?>? note,
      Value<DateTime?>? archivedAtUtc,
      Value<DateTime>? createdAtUtc,
      Value<DateTime>? updatedAtUtc,
      Value<int>? rowid}) {
    return EquipmentProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultWeightIncrementKg:
          defaultWeightIncrementKg ?? this.defaultWeightIncrementKg,
      legacyAccessCode: legacyAccessCode ?? this.legacyAccessCode,
      note: note ?? this.note,
      archivedAtUtc: archivedAtUtc ?? this.archivedAtUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (defaultWeightIncrementKg.present) {
      map['default_weight_increment_kg'] =
          Variable<double>(defaultWeightIncrementKg.value);
    }
    if (legacyAccessCode.present) {
      map['legacy_access_code'] = Variable<String>(legacyAccessCode.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (archivedAtUtc.present) {
      map['archived_at_utc'] = Variable<DateTime>(archivedAtUtc.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('defaultWeightIncrementKg: $defaultWeightIncrementKg, ')
          ..write('legacyAccessCode: $legacyAccessCode, ')
          ..write('note: $note, ')
          ..write('archivedAtUtc: $archivedAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingPlanSettingsTable extends TrainingPlanSettings
    with TableInfo<$TrainingPlanSettingsTable, TrainingPlanSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingPlanSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _activeProgramVersionIdMeta =
      const VerificationMeta('activeProgramVersionId');
  @override
  late final GeneratedColumn<String> activeProgramVersionId =
      GeneratedColumn<String>('active_program_version_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES program_versions (id)'));
  static const VerificationMeta _activeSinceLocalDateMeta =
      const VerificationMeta('activeSinceLocalDate');
  @override
  late final GeneratedColumn<String> activeSinceLocalDate =
      GeneratedColumn<String>('active_since_local_date', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _activeSinceTimezoneIdMeta =
      const VerificationMeta('activeSinceTimezoneId');
  @override
  late final GeneratedColumn<String> activeSinceTimezoneId =
      GeneratedColumn<String>('active_since_timezone_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _defaultEquipmentProfileIdMeta =
      const VerificationMeta('defaultEquipmentProfileId');
  @override
  late final GeneratedColumn<String> defaultEquipmentProfileId =
      GeneratedColumn<String>('default_equipment_profile_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES equipment_profiles (id)'));
  static const VerificationMeta _updatedAtUtcMeta =
      const VerificationMeta('updatedAtUtc');
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
      'updated_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        activeProgramVersionId,
        activeSinceLocalDate,
        activeSinceTimezoneId,
        defaultEquipmentProfileId,
        updatedAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_plan_settings';
  @override
  VerificationContext validateIntegrity(
      Insertable<TrainingPlanSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('active_program_version_id')) {
      context.handle(
          _activeProgramVersionIdMeta,
          activeProgramVersionId.isAcceptableOrUnknown(
              data['active_program_version_id']!, _activeProgramVersionIdMeta));
    }
    if (data.containsKey('active_since_local_date')) {
      context.handle(
          _activeSinceLocalDateMeta,
          activeSinceLocalDate.isAcceptableOrUnknown(
              data['active_since_local_date']!, _activeSinceLocalDateMeta));
    }
    if (data.containsKey('active_since_timezone_id')) {
      context.handle(
          _activeSinceTimezoneIdMeta,
          activeSinceTimezoneId.isAcceptableOrUnknown(
              data['active_since_timezone_id']!, _activeSinceTimezoneIdMeta));
    }
    if (data.containsKey('default_equipment_profile_id')) {
      context.handle(
          _defaultEquipmentProfileIdMeta,
          defaultEquipmentProfileId.isAcceptableOrUnknown(
              data['default_equipment_profile_id']!,
              _defaultEquipmentProfileIdMeta));
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
          _updatedAtUtcMeta,
          updatedAtUtc.isAcceptableOrUnknown(
              data['updated_at_utc']!, _updatedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainingPlanSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingPlanSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      activeProgramVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}active_program_version_id']),
      activeSinceLocalDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}active_since_local_date']),
      activeSinceTimezoneId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}active_since_timezone_id']),
      defaultEquipmentProfileId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}default_equipment_profile_id']),
      updatedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}updated_at_utc'])!,
    );
  }

  @override
  $TrainingPlanSettingsTable createAlias(String alias) {
    return $TrainingPlanSettingsTable(attachedDatabase, alias);
  }
}

class TrainingPlanSetting extends DataClass
    implements Insertable<TrainingPlanSetting> {
  final int id;
  final String? activeProgramVersionId;
  final String? activeSinceLocalDate;
  final String? activeSinceTimezoneId;
  final String? defaultEquipmentProfileId;
  final DateTime updatedAtUtc;
  const TrainingPlanSetting(
      {required this.id,
      this.activeProgramVersionId,
      this.activeSinceLocalDate,
      this.activeSinceTimezoneId,
      this.defaultEquipmentProfileId,
      required this.updatedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || activeProgramVersionId != null) {
      map['active_program_version_id'] =
          Variable<String>(activeProgramVersionId);
    }
    if (!nullToAbsent || activeSinceLocalDate != null) {
      map['active_since_local_date'] = Variable<String>(activeSinceLocalDate);
    }
    if (!nullToAbsent || activeSinceTimezoneId != null) {
      map['active_since_timezone_id'] = Variable<String>(activeSinceTimezoneId);
    }
    if (!nullToAbsent || defaultEquipmentProfileId != null) {
      map['default_equipment_profile_id'] =
          Variable<String>(defaultEquipmentProfileId);
    }
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  TrainingPlanSettingsCompanion toCompanion(bool nullToAbsent) {
    return TrainingPlanSettingsCompanion(
      id: Value(id),
      activeProgramVersionId: activeProgramVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeProgramVersionId),
      activeSinceLocalDate: activeSinceLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(activeSinceLocalDate),
      activeSinceTimezoneId: activeSinceTimezoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeSinceTimezoneId),
      defaultEquipmentProfileId:
          defaultEquipmentProfileId == null && nullToAbsent
              ? const Value.absent()
              : Value(defaultEquipmentProfileId),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory TrainingPlanSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingPlanSetting(
      id: serializer.fromJson<int>(json['id']),
      activeProgramVersionId:
          serializer.fromJson<String?>(json['activeProgramVersionId']),
      activeSinceLocalDate:
          serializer.fromJson<String?>(json['activeSinceLocalDate']),
      activeSinceTimezoneId:
          serializer.fromJson<String?>(json['activeSinceTimezoneId']),
      defaultEquipmentProfileId:
          serializer.fromJson<String?>(json['defaultEquipmentProfileId']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activeProgramVersionId':
          serializer.toJson<String?>(activeProgramVersionId),
      'activeSinceLocalDate': serializer.toJson<String?>(activeSinceLocalDate),
      'activeSinceTimezoneId':
          serializer.toJson<String?>(activeSinceTimezoneId),
      'defaultEquipmentProfileId':
          serializer.toJson<String?>(defaultEquipmentProfileId),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  TrainingPlanSetting copyWith(
          {int? id,
          Value<String?> activeProgramVersionId = const Value.absent(),
          Value<String?> activeSinceLocalDate = const Value.absent(),
          Value<String?> activeSinceTimezoneId = const Value.absent(),
          Value<String?> defaultEquipmentProfileId = const Value.absent(),
          DateTime? updatedAtUtc}) =>
      TrainingPlanSetting(
        id: id ?? this.id,
        activeProgramVersionId: activeProgramVersionId.present
            ? activeProgramVersionId.value
            : this.activeProgramVersionId,
        activeSinceLocalDate: activeSinceLocalDate.present
            ? activeSinceLocalDate.value
            : this.activeSinceLocalDate,
        activeSinceTimezoneId: activeSinceTimezoneId.present
            ? activeSinceTimezoneId.value
            : this.activeSinceTimezoneId,
        defaultEquipmentProfileId: defaultEquipmentProfileId.present
            ? defaultEquipmentProfileId.value
            : this.defaultEquipmentProfileId,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      );
  TrainingPlanSetting copyWithCompanion(TrainingPlanSettingsCompanion data) {
    return TrainingPlanSetting(
      id: data.id.present ? data.id.value : this.id,
      activeProgramVersionId: data.activeProgramVersionId.present
          ? data.activeProgramVersionId.value
          : this.activeProgramVersionId,
      activeSinceLocalDate: data.activeSinceLocalDate.present
          ? data.activeSinceLocalDate.value
          : this.activeSinceLocalDate,
      activeSinceTimezoneId: data.activeSinceTimezoneId.present
          ? data.activeSinceTimezoneId.value
          : this.activeSinceTimezoneId,
      defaultEquipmentProfileId: data.defaultEquipmentProfileId.present
          ? data.defaultEquipmentProfileId.value
          : this.defaultEquipmentProfileId,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingPlanSetting(')
          ..write('id: $id, ')
          ..write('activeProgramVersionId: $activeProgramVersionId, ')
          ..write('activeSinceLocalDate: $activeSinceLocalDate, ')
          ..write('activeSinceTimezoneId: $activeSinceTimezoneId, ')
          ..write('defaultEquipmentProfileId: $defaultEquipmentProfileId, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      activeProgramVersionId,
      activeSinceLocalDate,
      activeSinceTimezoneId,
      defaultEquipmentProfileId,
      updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingPlanSetting &&
          other.id == this.id &&
          other.activeProgramVersionId == this.activeProgramVersionId &&
          other.activeSinceLocalDate == this.activeSinceLocalDate &&
          other.activeSinceTimezoneId == this.activeSinceTimezoneId &&
          other.defaultEquipmentProfileId == this.defaultEquipmentProfileId &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class TrainingPlanSettingsCompanion
    extends UpdateCompanion<TrainingPlanSetting> {
  final Value<int> id;
  final Value<String?> activeProgramVersionId;
  final Value<String?> activeSinceLocalDate;
  final Value<String?> activeSinceTimezoneId;
  final Value<String?> defaultEquipmentProfileId;
  final Value<DateTime> updatedAtUtc;
  const TrainingPlanSettingsCompanion({
    this.id = const Value.absent(),
    this.activeProgramVersionId = const Value.absent(),
    this.activeSinceLocalDate = const Value.absent(),
    this.activeSinceTimezoneId = const Value.absent(),
    this.defaultEquipmentProfileId = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
  });
  TrainingPlanSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.activeProgramVersionId = const Value.absent(),
    this.activeSinceLocalDate = const Value.absent(),
    this.activeSinceTimezoneId = const Value.absent(),
    this.defaultEquipmentProfileId = const Value.absent(),
    required DateTime updatedAtUtc,
  }) : updatedAtUtc = Value(updatedAtUtc);
  static Insertable<TrainingPlanSetting> custom({
    Expression<int>? id,
    Expression<String>? activeProgramVersionId,
    Expression<String>? activeSinceLocalDate,
    Expression<String>? activeSinceTimezoneId,
    Expression<String>? defaultEquipmentProfileId,
    Expression<DateTime>? updatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activeProgramVersionId != null)
        'active_program_version_id': activeProgramVersionId,
      if (activeSinceLocalDate != null)
        'active_since_local_date': activeSinceLocalDate,
      if (activeSinceTimezoneId != null)
        'active_since_timezone_id': activeSinceTimezoneId,
      if (defaultEquipmentProfileId != null)
        'default_equipment_profile_id': defaultEquipmentProfileId,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
    });
  }

  TrainingPlanSettingsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? activeProgramVersionId,
      Value<String?>? activeSinceLocalDate,
      Value<String?>? activeSinceTimezoneId,
      Value<String?>? defaultEquipmentProfileId,
      Value<DateTime>? updatedAtUtc}) {
    return TrainingPlanSettingsCompanion(
      id: id ?? this.id,
      activeProgramVersionId:
          activeProgramVersionId ?? this.activeProgramVersionId,
      activeSinceLocalDate: activeSinceLocalDate ?? this.activeSinceLocalDate,
      activeSinceTimezoneId:
          activeSinceTimezoneId ?? this.activeSinceTimezoneId,
      defaultEquipmentProfileId:
          defaultEquipmentProfileId ?? this.defaultEquipmentProfileId,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activeProgramVersionId.present) {
      map['active_program_version_id'] =
          Variable<String>(activeProgramVersionId.value);
    }
    if (activeSinceLocalDate.present) {
      map['active_since_local_date'] =
          Variable<String>(activeSinceLocalDate.value);
    }
    if (activeSinceTimezoneId.present) {
      map['active_since_timezone_id'] =
          Variable<String>(activeSinceTimezoneId.value);
    }
    if (defaultEquipmentProfileId.present) {
      map['default_equipment_profile_id'] =
          Variable<String>(defaultEquipmentProfileId.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingPlanSettingsCompanion(')
          ..write('id: $id, ')
          ..write('activeProgramVersionId: $activeProgramVersionId, ')
          ..write('activeSinceLocalDate: $activeSinceLocalDate, ')
          ..write('activeSinceTimezoneId: $activeSinceTimezoneId, ')
          ..write('defaultEquipmentProfileId: $defaultEquipmentProfileId, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }
}

class $EquipmentProfileItemsTable extends EquipmentProfileItems
    with TableInfo<$EquipmentProfileItemsTable, EquipmentProfileItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentProfileItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _equipmentProfileIdMeta =
      const VerificationMeta('equipmentProfileId');
  @override
  late final GeneratedColumn<String> equipmentProfileId =
      GeneratedColumn<String>('equipment_profile_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES equipment_profiles (id)'));
  static const VerificationMeta _equipmentCodeMeta =
      const VerificationMeta('equipmentCode');
  @override
  late final GeneratedColumn<String> equipmentCode = GeneratedColumn<String>(
      'equipment_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isAvailableMeta =
      const VerificationMeta('isAvailable');
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
      'is_available', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_available" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _weightIncrementKgMeta =
      const VerificationMeta('weightIncrementKg');
  @override
  late final GeneratedColumn<double> weightIncrementKg =
      GeneratedColumn<double>('weight_increment_kg', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, equipmentProfileId, equipmentCode, isAvailable, weightIncrementKg];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_profile_items';
  @override
  VerificationContext validateIntegrity(
      Insertable<EquipmentProfileItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('equipment_profile_id')) {
      context.handle(
          _equipmentProfileIdMeta,
          equipmentProfileId.isAcceptableOrUnknown(
              data['equipment_profile_id']!, _equipmentProfileIdMeta));
    } else if (isInserting) {
      context.missing(_equipmentProfileIdMeta);
    }
    if (data.containsKey('equipment_code')) {
      context.handle(
          _equipmentCodeMeta,
          equipmentCode.isAcceptableOrUnknown(
              data['equipment_code']!, _equipmentCodeMeta));
    } else if (isInserting) {
      context.missing(_equipmentCodeMeta);
    }
    if (data.containsKey('is_available')) {
      context.handle(
          _isAvailableMeta,
          isAvailable.isAcceptableOrUnknown(
              data['is_available']!, _isAvailableMeta));
    }
    if (data.containsKey('weight_increment_kg')) {
      context.handle(
          _weightIncrementKgMeta,
          weightIncrementKg.isAcceptableOrUnknown(
              data['weight_increment_kg']!, _weightIncrementKgMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {equipmentProfileId, equipmentCode},
      ];
  @override
  EquipmentProfileItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentProfileItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      equipmentProfileId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}equipment_profile_id'])!,
      equipmentCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment_code'])!,
      isAvailable: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_available'])!,
      weightIncrementKg: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}weight_increment_kg']),
    );
  }

  @override
  $EquipmentProfileItemsTable createAlias(String alias) {
    return $EquipmentProfileItemsTable(attachedDatabase, alias);
  }
}

class EquipmentProfileItem extends DataClass
    implements Insertable<EquipmentProfileItem> {
  final String id;
  final String equipmentProfileId;
  final String equipmentCode;
  final bool isAvailable;
  final double? weightIncrementKg;
  const EquipmentProfileItem(
      {required this.id,
      required this.equipmentProfileId,
      required this.equipmentCode,
      required this.isAvailable,
      this.weightIncrementKg});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['equipment_profile_id'] = Variable<String>(equipmentProfileId);
    map['equipment_code'] = Variable<String>(equipmentCode);
    map['is_available'] = Variable<bool>(isAvailable);
    if (!nullToAbsent || weightIncrementKg != null) {
      map['weight_increment_kg'] = Variable<double>(weightIncrementKg);
    }
    return map;
  }

  EquipmentProfileItemsCompanion toCompanion(bool nullToAbsent) {
    return EquipmentProfileItemsCompanion(
      id: Value(id),
      equipmentProfileId: Value(equipmentProfileId),
      equipmentCode: Value(equipmentCode),
      isAvailable: Value(isAvailable),
      weightIncrementKg: weightIncrementKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightIncrementKg),
    );
  }

  factory EquipmentProfileItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentProfileItem(
      id: serializer.fromJson<String>(json['id']),
      equipmentProfileId:
          serializer.fromJson<String>(json['equipmentProfileId']),
      equipmentCode: serializer.fromJson<String>(json['equipmentCode']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
      weightIncrementKg:
          serializer.fromJson<double?>(json['weightIncrementKg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'equipmentProfileId': serializer.toJson<String>(equipmentProfileId),
      'equipmentCode': serializer.toJson<String>(equipmentCode),
      'isAvailable': serializer.toJson<bool>(isAvailable),
      'weightIncrementKg': serializer.toJson<double?>(weightIncrementKg),
    };
  }

  EquipmentProfileItem copyWith(
          {String? id,
          String? equipmentProfileId,
          String? equipmentCode,
          bool? isAvailable,
          Value<double?> weightIncrementKg = const Value.absent()}) =>
      EquipmentProfileItem(
        id: id ?? this.id,
        equipmentProfileId: equipmentProfileId ?? this.equipmentProfileId,
        equipmentCode: equipmentCode ?? this.equipmentCode,
        isAvailable: isAvailable ?? this.isAvailable,
        weightIncrementKg: weightIncrementKg.present
            ? weightIncrementKg.value
            : this.weightIncrementKg,
      );
  EquipmentProfileItem copyWithCompanion(EquipmentProfileItemsCompanion data) {
    return EquipmentProfileItem(
      id: data.id.present ? data.id.value : this.id,
      equipmentProfileId: data.equipmentProfileId.present
          ? data.equipmentProfileId.value
          : this.equipmentProfileId,
      equipmentCode: data.equipmentCode.present
          ? data.equipmentCode.value
          : this.equipmentCode,
      isAvailable:
          data.isAvailable.present ? data.isAvailable.value : this.isAvailable,
      weightIncrementKg: data.weightIncrementKg.present
          ? data.weightIncrementKg.value
          : this.weightIncrementKg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentProfileItem(')
          ..write('id: $id, ')
          ..write('equipmentProfileId: $equipmentProfileId, ')
          ..write('equipmentCode: $equipmentCode, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('weightIncrementKg: $weightIncrementKg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, equipmentProfileId, equipmentCode, isAvailable, weightIncrementKg);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentProfileItem &&
          other.id == this.id &&
          other.equipmentProfileId == this.equipmentProfileId &&
          other.equipmentCode == this.equipmentCode &&
          other.isAvailable == this.isAvailable &&
          other.weightIncrementKg == this.weightIncrementKg);
}

class EquipmentProfileItemsCompanion
    extends UpdateCompanion<EquipmentProfileItem> {
  final Value<String> id;
  final Value<String> equipmentProfileId;
  final Value<String> equipmentCode;
  final Value<bool> isAvailable;
  final Value<double?> weightIncrementKg;
  final Value<int> rowid;
  const EquipmentProfileItemsCompanion({
    this.id = const Value.absent(),
    this.equipmentProfileId = const Value.absent(),
    this.equipmentCode = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.weightIncrementKg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EquipmentProfileItemsCompanion.insert({
    required String id,
    required String equipmentProfileId,
    required String equipmentCode,
    this.isAvailable = const Value.absent(),
    this.weightIncrementKg = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        equipmentProfileId = Value(equipmentProfileId),
        equipmentCode = Value(equipmentCode);
  static Insertable<EquipmentProfileItem> custom({
    Expression<String>? id,
    Expression<String>? equipmentProfileId,
    Expression<String>? equipmentCode,
    Expression<bool>? isAvailable,
    Expression<double>? weightIncrementKg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (equipmentProfileId != null)
        'equipment_profile_id': equipmentProfileId,
      if (equipmentCode != null) 'equipment_code': equipmentCode,
      if (isAvailable != null) 'is_available': isAvailable,
      if (weightIncrementKg != null) 'weight_increment_kg': weightIncrementKg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EquipmentProfileItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? equipmentProfileId,
      Value<String>? equipmentCode,
      Value<bool>? isAvailable,
      Value<double?>? weightIncrementKg,
      Value<int>? rowid}) {
    return EquipmentProfileItemsCompanion(
      id: id ?? this.id,
      equipmentProfileId: equipmentProfileId ?? this.equipmentProfileId,
      equipmentCode: equipmentCode ?? this.equipmentCode,
      isAvailable: isAvailable ?? this.isAvailable,
      weightIncrementKg: weightIncrementKg ?? this.weightIncrementKg,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (equipmentProfileId.present) {
      map['equipment_profile_id'] = Variable<String>(equipmentProfileId.value);
    }
    if (equipmentCode.present) {
      map['equipment_code'] = Variable<String>(equipmentCode.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    if (weightIncrementKg.present) {
      map['weight_increment_kg'] = Variable<double>(weightIncrementKg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentProfileItemsCompanion(')
          ..write('id: $id, ')
          ..write('equipmentProfileId: $equipmentProfileId, ')
          ..write('equipmentCode: $equipmentCode, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('weightIncrementKg: $weightIncrementKg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TravelContextsTable extends TravelContexts
    with TableInfo<$TravelContextsTable, TravelContext> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TravelContextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startLocalDateMeta =
      const VerificationMeta('startLocalDate');
  @override
  late final GeneratedColumn<String> startLocalDate = GeneratedColumn<String>(
      'start_local_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endLocalDateMeta =
      const VerificationMeta('endLocalDate');
  @override
  late final GeneratedColumn<String> endLocalDate = GeneratedColumn<String>(
      'end_local_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timezoneIdMeta =
      const VerificationMeta('timezoneId');
  @override
  late final GeneratedColumn<String> timezoneId = GeneratedColumn<String>(
      'timezone_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _equipmentProfileIdMeta =
      const VerificationMeta('equipmentProfileId');
  @override
  late final GeneratedColumn<String> equipmentProfileId =
      GeneratedColumn<String>('equipment_profile_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES equipment_profiles (id)'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endedAtUtcMeta =
      const VerificationMeta('endedAtUtc');
  @override
  late final GeneratedColumn<DateTime> endedAtUtc = GeneratedColumn<DateTime>(
      'ended_at_utc', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        startLocalDate,
        endLocalDate,
        timezoneId,
        equipmentProfileId,
        status,
        note,
        createdAtUtc,
        endedAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'travel_contexts';
  @override
  VerificationContext validateIntegrity(Insertable<TravelContext> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('start_local_date')) {
      context.handle(
          _startLocalDateMeta,
          startLocalDate.isAcceptableOrUnknown(
              data['start_local_date']!, _startLocalDateMeta));
    } else if (isInserting) {
      context.missing(_startLocalDateMeta);
    }
    if (data.containsKey('end_local_date')) {
      context.handle(
          _endLocalDateMeta,
          endLocalDate.isAcceptableOrUnknown(
              data['end_local_date']!, _endLocalDateMeta));
    } else if (isInserting) {
      context.missing(_endLocalDateMeta);
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
          _timezoneIdMeta,
          timezoneId.isAcceptableOrUnknown(
              data['timezone_id']!, _timezoneIdMeta));
    } else if (isInserting) {
      context.missing(_timezoneIdMeta);
    }
    if (data.containsKey('equipment_profile_id')) {
      context.handle(
          _equipmentProfileIdMeta,
          equipmentProfileId.isAcceptableOrUnknown(
              data['equipment_profile_id']!, _equipmentProfileIdMeta));
    } else if (isInserting) {
      context.missing(_equipmentProfileIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('ended_at_utc')) {
      context.handle(
          _endedAtUtcMeta,
          endedAtUtc.isAcceptableOrUnknown(
              data['ended_at_utc']!, _endedAtUtcMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TravelContext map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TravelContext(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      startLocalDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}start_local_date'])!,
      endLocalDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_local_date'])!,
      timezoneId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timezone_id'])!,
      equipmentProfileId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}equipment_profile_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      endedAtUtc: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at_utc']),
    );
  }

  @override
  $TravelContextsTable createAlias(String alias) {
    return $TravelContextsTable(attachedDatabase, alias);
  }
}

class TravelContext extends DataClass implements Insertable<TravelContext> {
  final String id;
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final String equipmentProfileId;
  final String status;
  final String? note;
  final DateTime createdAtUtc;
  final DateTime? endedAtUtc;
  const TravelContext(
      {required this.id,
      required this.startLocalDate,
      required this.endLocalDate,
      required this.timezoneId,
      required this.equipmentProfileId,
      required this.status,
      this.note,
      required this.createdAtUtc,
      this.endedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['start_local_date'] = Variable<String>(startLocalDate);
    map['end_local_date'] = Variable<String>(endLocalDate);
    map['timezone_id'] = Variable<String>(timezoneId);
    map['equipment_profile_id'] = Variable<String>(equipmentProfileId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    if (!nullToAbsent || endedAtUtc != null) {
      map['ended_at_utc'] = Variable<DateTime>(endedAtUtc);
    }
    return map;
  }

  TravelContextsCompanion toCompanion(bool nullToAbsent) {
    return TravelContextsCompanion(
      id: Value(id),
      startLocalDate: Value(startLocalDate),
      endLocalDate: Value(endLocalDate),
      timezoneId: Value(timezoneId),
      equipmentProfileId: Value(equipmentProfileId),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAtUtc: Value(createdAtUtc),
      endedAtUtc: endedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUtc),
    );
  }

  factory TravelContext.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TravelContext(
      id: serializer.fromJson<String>(json['id']),
      startLocalDate: serializer.fromJson<String>(json['startLocalDate']),
      endLocalDate: serializer.fromJson<String>(json['endLocalDate']),
      timezoneId: serializer.fromJson<String>(json['timezoneId']),
      equipmentProfileId:
          serializer.fromJson<String>(json['equipmentProfileId']),
      status: serializer.fromJson<String>(json['status']),
      note: serializer.fromJson<String?>(json['note']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      endedAtUtc: serializer.fromJson<DateTime?>(json['endedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startLocalDate': serializer.toJson<String>(startLocalDate),
      'endLocalDate': serializer.toJson<String>(endLocalDate),
      'timezoneId': serializer.toJson<String>(timezoneId),
      'equipmentProfileId': serializer.toJson<String>(equipmentProfileId),
      'status': serializer.toJson<String>(status),
      'note': serializer.toJson<String?>(note),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'endedAtUtc': serializer.toJson<DateTime?>(endedAtUtc),
    };
  }

  TravelContext copyWith(
          {String? id,
          String? startLocalDate,
          String? endLocalDate,
          String? timezoneId,
          String? equipmentProfileId,
          String? status,
          Value<String?> note = const Value.absent(),
          DateTime? createdAtUtc,
          Value<DateTime?> endedAtUtc = const Value.absent()}) =>
      TravelContext(
        id: id ?? this.id,
        startLocalDate: startLocalDate ?? this.startLocalDate,
        endLocalDate: endLocalDate ?? this.endLocalDate,
        timezoneId: timezoneId ?? this.timezoneId,
        equipmentProfileId: equipmentProfileId ?? this.equipmentProfileId,
        status: status ?? this.status,
        note: note.present ? note.value : this.note,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        endedAtUtc: endedAtUtc.present ? endedAtUtc.value : this.endedAtUtc,
      );
  TravelContext copyWithCompanion(TravelContextsCompanion data) {
    return TravelContext(
      id: data.id.present ? data.id.value : this.id,
      startLocalDate: data.startLocalDate.present
          ? data.startLocalDate.value
          : this.startLocalDate,
      endLocalDate: data.endLocalDate.present
          ? data.endLocalDate.value
          : this.endLocalDate,
      timezoneId:
          data.timezoneId.present ? data.timezoneId.value : this.timezoneId,
      equipmentProfileId: data.equipmentProfileId.present
          ? data.equipmentProfileId.value
          : this.equipmentProfileId,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      endedAtUtc:
          data.endedAtUtc.present ? data.endedAtUtc.value : this.endedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TravelContext(')
          ..write('id: $id, ')
          ..write('startLocalDate: $startLocalDate, ')
          ..write('endLocalDate: $endLocalDate, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('equipmentProfileId: $equipmentProfileId, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startLocalDate, endLocalDate, timezoneId,
      equipmentProfileId, status, note, createdAtUtc, endedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TravelContext &&
          other.id == this.id &&
          other.startLocalDate == this.startLocalDate &&
          other.endLocalDate == this.endLocalDate &&
          other.timezoneId == this.timezoneId &&
          other.equipmentProfileId == this.equipmentProfileId &&
          other.status == this.status &&
          other.note == this.note &&
          other.createdAtUtc == this.createdAtUtc &&
          other.endedAtUtc == this.endedAtUtc);
}

class TravelContextsCompanion extends UpdateCompanion<TravelContext> {
  final Value<String> id;
  final Value<String> startLocalDate;
  final Value<String> endLocalDate;
  final Value<String> timezoneId;
  final Value<String> equipmentProfileId;
  final Value<String> status;
  final Value<String?> note;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime?> endedAtUtc;
  final Value<int> rowid;
  const TravelContextsCompanion({
    this.id = const Value.absent(),
    this.startLocalDate = const Value.absent(),
    this.endLocalDate = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.equipmentProfileId = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.endedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TravelContextsCompanion.insert({
    required String id,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required String equipmentProfileId,
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAtUtc,
    this.endedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        startLocalDate = Value(startLocalDate),
        endLocalDate = Value(endLocalDate),
        timezoneId = Value(timezoneId),
        equipmentProfileId = Value(equipmentProfileId),
        createdAtUtc = Value(createdAtUtc);
  static Insertable<TravelContext> custom({
    Expression<String>? id,
    Expression<String>? startLocalDate,
    Expression<String>? endLocalDate,
    Expression<String>? timezoneId,
    Expression<String>? equipmentProfileId,
    Expression<String>? status,
    Expression<String>? note,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? endedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startLocalDate != null) 'start_local_date': startLocalDate,
      if (endLocalDate != null) 'end_local_date': endLocalDate,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (equipmentProfileId != null)
        'equipment_profile_id': equipmentProfileId,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (endedAtUtc != null) 'ended_at_utc': endedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TravelContextsCompanion copyWith(
      {Value<String>? id,
      Value<String>? startLocalDate,
      Value<String>? endLocalDate,
      Value<String>? timezoneId,
      Value<String>? equipmentProfileId,
      Value<String>? status,
      Value<String?>? note,
      Value<DateTime>? createdAtUtc,
      Value<DateTime?>? endedAtUtc,
      Value<int>? rowid}) {
    return TravelContextsCompanion(
      id: id ?? this.id,
      startLocalDate: startLocalDate ?? this.startLocalDate,
      endLocalDate: endLocalDate ?? this.endLocalDate,
      timezoneId: timezoneId ?? this.timezoneId,
      equipmentProfileId: equipmentProfileId ?? this.equipmentProfileId,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startLocalDate.present) {
      map['start_local_date'] = Variable<String>(startLocalDate.value);
    }
    if (endLocalDate.present) {
      map['end_local_date'] = Variable<String>(endLocalDate.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (equipmentProfileId.present) {
      map['equipment_profile_id'] = Variable<String>(equipmentProfileId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (endedAtUtc.present) {
      map['ended_at_utc'] = Variable<DateTime>(endedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TravelContextsCompanion(')
          ..write('id: $id, ')
          ..write('startLocalDate: $startLocalDate, ')
          ..write('endLocalDate: $endLocalDate, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('equipmentProfileId: $equipmentProfileId, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TravelContextOccurrencesTable extends TravelContextOccurrences
    with TableInfo<$TravelContextOccurrencesTable, TravelContextOccurrence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TravelContextOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _travelContextIdMeta =
      const VerificationMeta('travelContextId');
  @override
  late final GeneratedColumn<String> travelContextId = GeneratedColumn<String>(
      'travel_context_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES travel_contexts (id)'));
  static const VerificationMeta _occurrenceIdMeta =
      const VerificationMeta('occurrenceId');
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
      'occurrence_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES scheduled_session_occurrences (id)'));
  static const VerificationMeta _confirmedAtUtcMeta =
      const VerificationMeta('confirmedAtUtc');
  @override
  late final GeneratedColumn<DateTime> confirmedAtUtc =
      GeneratedColumn<DateTime>('confirmed_at_utc', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [travelContextId, occurrenceId, confirmedAtUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'travel_context_occurrences';
  @override
  VerificationContext validateIntegrity(
      Insertable<TravelContextOccurrence> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('travel_context_id')) {
      context.handle(
          _travelContextIdMeta,
          travelContextId.isAcceptableOrUnknown(
              data['travel_context_id']!, _travelContextIdMeta));
    } else if (isInserting) {
      context.missing(_travelContextIdMeta);
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
          _occurrenceIdMeta,
          occurrenceId.isAcceptableOrUnknown(
              data['occurrence_id']!, _occurrenceIdMeta));
    } else if (isInserting) {
      context.missing(_occurrenceIdMeta);
    }
    if (data.containsKey('confirmed_at_utc')) {
      context.handle(
          _confirmedAtUtcMeta,
          confirmedAtUtc.isAcceptableOrUnknown(
              data['confirmed_at_utc']!, _confirmedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_confirmedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {travelContextId, occurrenceId};
  @override
  TravelContextOccurrence map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TravelContextOccurrence(
      travelContextId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}travel_context_id'])!,
      occurrenceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occurrence_id'])!,
      confirmedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}confirmed_at_utc'])!,
    );
  }

  @override
  $TravelContextOccurrencesTable createAlias(String alias) {
    return $TravelContextOccurrencesTable(attachedDatabase, alias);
  }
}

class TravelContextOccurrence extends DataClass
    implements Insertable<TravelContextOccurrence> {
  final String travelContextId;
  final String occurrenceId;
  final DateTime confirmedAtUtc;
  const TravelContextOccurrence(
      {required this.travelContextId,
      required this.occurrenceId,
      required this.confirmedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['travel_context_id'] = Variable<String>(travelContextId);
    map['occurrence_id'] = Variable<String>(occurrenceId);
    map['confirmed_at_utc'] = Variable<DateTime>(confirmedAtUtc);
    return map;
  }

  TravelContextOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return TravelContextOccurrencesCompanion(
      travelContextId: Value(travelContextId),
      occurrenceId: Value(occurrenceId),
      confirmedAtUtc: Value(confirmedAtUtc),
    );
  }

  factory TravelContextOccurrence.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TravelContextOccurrence(
      travelContextId: serializer.fromJson<String>(json['travelContextId']),
      occurrenceId: serializer.fromJson<String>(json['occurrenceId']),
      confirmedAtUtc: serializer.fromJson<DateTime>(json['confirmedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'travelContextId': serializer.toJson<String>(travelContextId),
      'occurrenceId': serializer.toJson<String>(occurrenceId),
      'confirmedAtUtc': serializer.toJson<DateTime>(confirmedAtUtc),
    };
  }

  TravelContextOccurrence copyWith(
          {String? travelContextId,
          String? occurrenceId,
          DateTime? confirmedAtUtc}) =>
      TravelContextOccurrence(
        travelContextId: travelContextId ?? this.travelContextId,
        occurrenceId: occurrenceId ?? this.occurrenceId,
        confirmedAtUtc: confirmedAtUtc ?? this.confirmedAtUtc,
      );
  TravelContextOccurrence copyWithCompanion(
      TravelContextOccurrencesCompanion data) {
    return TravelContextOccurrence(
      travelContextId: data.travelContextId.present
          ? data.travelContextId.value
          : this.travelContextId,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      confirmedAtUtc: data.confirmedAtUtc.present
          ? data.confirmedAtUtc.value
          : this.confirmedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TravelContextOccurrence(')
          ..write('travelContextId: $travelContextId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('confirmedAtUtc: $confirmedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(travelContextId, occurrenceId, confirmedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TravelContextOccurrence &&
          other.travelContextId == this.travelContextId &&
          other.occurrenceId == this.occurrenceId &&
          other.confirmedAtUtc == this.confirmedAtUtc);
}

class TravelContextOccurrencesCompanion
    extends UpdateCompanion<TravelContextOccurrence> {
  final Value<String> travelContextId;
  final Value<String> occurrenceId;
  final Value<DateTime> confirmedAtUtc;
  final Value<int> rowid;
  const TravelContextOccurrencesCompanion({
    this.travelContextId = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.confirmedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TravelContextOccurrencesCompanion.insert({
    required String travelContextId,
    required String occurrenceId,
    required DateTime confirmedAtUtc,
    this.rowid = const Value.absent(),
  })  : travelContextId = Value(travelContextId),
        occurrenceId = Value(occurrenceId),
        confirmedAtUtc = Value(confirmedAtUtc);
  static Insertable<TravelContextOccurrence> custom({
    Expression<String>? travelContextId,
    Expression<String>? occurrenceId,
    Expression<DateTime>? confirmedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (travelContextId != null) 'travel_context_id': travelContextId,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (confirmedAtUtc != null) 'confirmed_at_utc': confirmedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TravelContextOccurrencesCompanion copyWith(
      {Value<String>? travelContextId,
      Value<String>? occurrenceId,
      Value<DateTime>? confirmedAtUtc,
      Value<int>? rowid}) {
    return TravelContextOccurrencesCompanion(
      travelContextId: travelContextId ?? this.travelContextId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      confirmedAtUtc: confirmedAtUtc ?? this.confirmedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (travelContextId.present) {
      map['travel_context_id'] = Variable<String>(travelContextId.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (confirmedAtUtc.present) {
      map['confirmed_at_utc'] = Variable<DateTime>(confirmedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TravelContextOccurrencesCompanion(')
          ..write('travelContextId: $travelContextId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('confirmedAtUtc: $confirmedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseUserPreferencesTable extends ExerciseUserPreferences
    with TableInfo<$ExerciseUserPreferencesTable, ExerciseUserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseUserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _identityKeyMeta =
      const VerificationMeta('identityKey');
  @override
  late final GeneratedColumn<String> identityKey = GeneratedColumn<String>(
      'identity_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _exerciseIdMeta =
      const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
      'exercise_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES exercises (stable_id)'));
  static const VerificationMeta _exerciseNameFallbackMeta =
      const VerificationMeta('exerciseNameFallback');
  @override
  late final GeneratedColumn<String> exerciseNameFallback =
      GeneratedColumn<String>('exercise_name_fallback', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _generalNoteMeta =
      const VerificationMeta('generalNote');
  @override
  late final GeneratedColumn<String> generalNote = GeneratedColumn<String>(
      'general_note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtUtcMeta =
      const VerificationMeta('updatedAtUtc');
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
      'updated_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        identityKey,
        exerciseId,
        exerciseNameFallback,
        generalNote,
        createdAtUtc,
        updatedAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_user_preferences';
  @override
  VerificationContext validateIntegrity(
      Insertable<ExerciseUserPreference> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('identity_key')) {
      context.handle(
          _identityKeyMeta,
          identityKey.isAcceptableOrUnknown(
              data['identity_key']!, _identityKeyMeta));
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
          _exerciseIdMeta,
          exerciseId.isAcceptableOrUnknown(
              data['exercise_id']!, _exerciseIdMeta));
    }
    if (data.containsKey('exercise_name_fallback')) {
      context.handle(
          _exerciseNameFallbackMeta,
          exerciseNameFallback.isAcceptableOrUnknown(
              data['exercise_name_fallback']!, _exerciseNameFallbackMeta));
    }
    if (data.containsKey('general_note')) {
      context.handle(
          _generalNoteMeta,
          generalNote.isAcceptableOrUnknown(
              data['general_note']!, _generalNoteMeta));
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
          _updatedAtUtcMeta,
          updatedAtUtc.isAcceptableOrUnknown(
              data['updated_at_utc']!, _updatedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {identityKey},
      ];
  @override
  ExerciseUserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseUserPreference(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      identityKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}identity_key'])!,
      exerciseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_id']),
      exerciseNameFallback: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}exercise_name_fallback']),
      generalNote: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}general_note']),
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}updated_at_utc'])!,
    );
  }

  @override
  $ExerciseUserPreferencesTable createAlias(String alias) {
    return $ExerciseUserPreferencesTable(attachedDatabase, alias);
  }
}

class ExerciseUserPreference extends DataClass
    implements Insertable<ExerciseUserPreference> {
  final String id;
  final String identityKey;
  final String? exerciseId;
  final String? exerciseNameFallback;
  final String? generalNote;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const ExerciseUserPreference(
      {required this.id,
      required this.identityKey,
      this.exerciseId,
      this.exerciseNameFallback,
      this.generalNote,
      required this.createdAtUtc,
      required this.updatedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['identity_key'] = Variable<String>(identityKey);
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<String>(exerciseId);
    }
    if (!nullToAbsent || exerciseNameFallback != null) {
      map['exercise_name_fallback'] = Variable<String>(exerciseNameFallback);
    }
    if (!nullToAbsent || generalNote != null) {
      map['general_note'] = Variable<String>(generalNote);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  ExerciseUserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return ExerciseUserPreferencesCompanion(
      id: Value(id),
      identityKey: Value(identityKey),
      exerciseId: exerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseId),
      exerciseNameFallback: exerciseNameFallback == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseNameFallback),
      generalNote: generalNote == null && nullToAbsent
          ? const Value.absent()
          : Value(generalNote),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory ExerciseUserPreference.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseUserPreference(
      id: serializer.fromJson<String>(json['id']),
      identityKey: serializer.fromJson<String>(json['identityKey']),
      exerciseId: serializer.fromJson<String?>(json['exerciseId']),
      exerciseNameFallback:
          serializer.fromJson<String?>(json['exerciseNameFallback']),
      generalNote: serializer.fromJson<String?>(json['generalNote']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'identityKey': serializer.toJson<String>(identityKey),
      'exerciseId': serializer.toJson<String?>(exerciseId),
      'exerciseNameFallback': serializer.toJson<String?>(exerciseNameFallback),
      'generalNote': serializer.toJson<String?>(generalNote),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  ExerciseUserPreference copyWith(
          {String? id,
          String? identityKey,
          Value<String?> exerciseId = const Value.absent(),
          Value<String?> exerciseNameFallback = const Value.absent(),
          Value<String?> generalNote = const Value.absent(),
          DateTime? createdAtUtc,
          DateTime? updatedAtUtc}) =>
      ExerciseUserPreference(
        id: id ?? this.id,
        identityKey: identityKey ?? this.identityKey,
        exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
        exerciseNameFallback: exerciseNameFallback.present
            ? exerciseNameFallback.value
            : this.exerciseNameFallback,
        generalNote: generalNote.present ? generalNote.value : this.generalNote,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      );
  ExerciseUserPreference copyWithCompanion(
      ExerciseUserPreferencesCompanion data) {
    return ExerciseUserPreference(
      id: data.id.present ? data.id.value : this.id,
      identityKey:
          data.identityKey.present ? data.identityKey.value : this.identityKey,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      exerciseNameFallback: data.exerciseNameFallback.present
          ? data.exerciseNameFallback.value
          : this.exerciseNameFallback,
      generalNote:
          data.generalNote.present ? data.generalNote.value : this.generalNote,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseUserPreference(')
          ..write('id: $id, ')
          ..write('identityKey: $identityKey, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseNameFallback: $exerciseNameFallback, ')
          ..write('generalNote: $generalNote, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, identityKey, exerciseId,
      exerciseNameFallback, generalNote, createdAtUtc, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseUserPreference &&
          other.id == this.id &&
          other.identityKey == this.identityKey &&
          other.exerciseId == this.exerciseId &&
          other.exerciseNameFallback == this.exerciseNameFallback &&
          other.generalNote == this.generalNote &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class ExerciseUserPreferencesCompanion
    extends UpdateCompanion<ExerciseUserPreference> {
  final Value<String> id;
  final Value<String> identityKey;
  final Value<String?> exerciseId;
  final Value<String?> exerciseNameFallback;
  final Value<String?> generalNote;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const ExerciseUserPreferencesCompanion({
    this.id = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.exerciseNameFallback = const Value.absent(),
    this.generalNote = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseUserPreferencesCompanion.insert({
    required String id,
    required String identityKey,
    this.exerciseId = const Value.absent(),
    this.exerciseNameFallback = const Value.absent(),
    this.generalNote = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        identityKey = Value(identityKey),
        createdAtUtc = Value(createdAtUtc),
        updatedAtUtc = Value(updatedAtUtc);
  static Insertable<ExerciseUserPreference> custom({
    Expression<String>? id,
    Expression<String>? identityKey,
    Expression<String>? exerciseId,
    Expression<String>? exerciseNameFallback,
    Expression<String>? generalNote,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (identityKey != null) 'identity_key': identityKey,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (exerciseNameFallback != null)
        'exercise_name_fallback': exerciseNameFallback,
      if (generalNote != null) 'general_note': generalNote,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseUserPreferencesCompanion copyWith(
      {Value<String>? id,
      Value<String>? identityKey,
      Value<String?>? exerciseId,
      Value<String?>? exerciseNameFallback,
      Value<String?>? generalNote,
      Value<DateTime>? createdAtUtc,
      Value<DateTime>? updatedAtUtc,
      Value<int>? rowid}) {
    return ExerciseUserPreferencesCompanion(
      id: id ?? this.id,
      identityKey: identityKey ?? this.identityKey,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseNameFallback: exerciseNameFallback ?? this.exerciseNameFallback,
      generalNote: generalNote ?? this.generalNote,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<String>(identityKey.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (exerciseNameFallback.present) {
      map['exercise_name_fallback'] =
          Variable<String>(exerciseNameFallback.value);
    }
    if (generalNote.present) {
      map['general_note'] = Variable<String>(generalNote.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseUserPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('identityKey: $identityKey, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseNameFallback: $exerciseNameFallback, ')
          ..write('generalNote: $generalNote, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseSetupValuesTable extends ExerciseSetupValues
    with TableInfo<$ExerciseSetupValuesTable, ExerciseSetupValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseSetupValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _exerciseUserPreferenceIdMeta =
      const VerificationMeta('exerciseUserPreferenceId');
  @override
  late final GeneratedColumn<String> exerciseUserPreferenceId =
      GeneratedColumn<String>('exercise_user_preference_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES exercise_user_preferences (id)'));
  static const VerificationMeta _ordinalMeta =
      const VerificationMeta('ordinal');
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
      'ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, exerciseUserPreferenceId, ordinal, label, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_setup_values';
  @override
  VerificationContext validateIntegrity(Insertable<ExerciseSetupValue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exercise_user_preference_id')) {
      context.handle(
          _exerciseUserPreferenceIdMeta,
          exerciseUserPreferenceId.isAcceptableOrUnknown(
              data['exercise_user_preference_id']!,
              _exerciseUserPreferenceIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseUserPreferenceIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(_ordinalMeta,
          ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta));
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {exerciseUserPreferenceId, ordinal},
      ];
  @override
  ExerciseSetupValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseSetupValue(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      exerciseUserPreferenceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}exercise_user_preference_id'])!,
      ordinal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ordinal'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $ExerciseSetupValuesTable createAlias(String alias) {
    return $ExerciseSetupValuesTable(attachedDatabase, alias);
  }
}

class ExerciseSetupValue extends DataClass
    implements Insertable<ExerciseSetupValue> {
  final String id;
  final String exerciseUserPreferenceId;
  final int ordinal;
  final String label;
  final String value;
  const ExerciseSetupValue(
      {required this.id,
      required this.exerciseUserPreferenceId,
      required this.ordinal,
      required this.label,
      required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exercise_user_preference_id'] =
        Variable<String>(exerciseUserPreferenceId);
    map['ordinal'] = Variable<int>(ordinal);
    map['label'] = Variable<String>(label);
    map['value'] = Variable<String>(value);
    return map;
  }

  ExerciseSetupValuesCompanion toCompanion(bool nullToAbsent) {
    return ExerciseSetupValuesCompanion(
      id: Value(id),
      exerciseUserPreferenceId: Value(exerciseUserPreferenceId),
      ordinal: Value(ordinal),
      label: Value(label),
      value: Value(value),
    );
  }

  factory ExerciseSetupValue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseSetupValue(
      id: serializer.fromJson<String>(json['id']),
      exerciseUserPreferenceId:
          serializer.fromJson<String>(json['exerciseUserPreferenceId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      label: serializer.fromJson<String>(json['label']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'exerciseUserPreferenceId':
          serializer.toJson<String>(exerciseUserPreferenceId),
      'ordinal': serializer.toJson<int>(ordinal),
      'label': serializer.toJson<String>(label),
      'value': serializer.toJson<String>(value),
    };
  }

  ExerciseSetupValue copyWith(
          {String? id,
          String? exerciseUserPreferenceId,
          int? ordinal,
          String? label,
          String? value}) =>
      ExerciseSetupValue(
        id: id ?? this.id,
        exerciseUserPreferenceId:
            exerciseUserPreferenceId ?? this.exerciseUserPreferenceId,
        ordinal: ordinal ?? this.ordinal,
        label: label ?? this.label,
        value: value ?? this.value,
      );
  ExerciseSetupValue copyWithCompanion(ExerciseSetupValuesCompanion data) {
    return ExerciseSetupValue(
      id: data.id.present ? data.id.value : this.id,
      exerciseUserPreferenceId: data.exerciseUserPreferenceId.present
          ? data.exerciseUserPreferenceId.value
          : this.exerciseUserPreferenceId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSetupValue(')
          ..write('id: $id, ')
          ..write('exerciseUserPreferenceId: $exerciseUserPreferenceId, ')
          ..write('ordinal: $ordinal, ')
          ..write('label: $label, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, exerciseUserPreferenceId, ordinal, label, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseSetupValue &&
          other.id == this.id &&
          other.exerciseUserPreferenceId == this.exerciseUserPreferenceId &&
          other.ordinal == this.ordinal &&
          other.label == this.label &&
          other.value == this.value);
}

class ExerciseSetupValuesCompanion extends UpdateCompanion<ExerciseSetupValue> {
  final Value<String> id;
  final Value<String> exerciseUserPreferenceId;
  final Value<int> ordinal;
  final Value<String> label;
  final Value<String> value;
  final Value<int> rowid;
  const ExerciseSetupValuesCompanion({
    this.id = const Value.absent(),
    this.exerciseUserPreferenceId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseSetupValuesCompanion.insert({
    required String id,
    required String exerciseUserPreferenceId,
    required int ordinal,
    required String label,
    required String value,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        exerciseUserPreferenceId = Value(exerciseUserPreferenceId),
        ordinal = Value(ordinal),
        label = Value(label),
        value = Value(value);
  static Insertable<ExerciseSetupValue> custom({
    Expression<String>? id,
    Expression<String>? exerciseUserPreferenceId,
    Expression<int>? ordinal,
    Expression<String>? label,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseUserPreferenceId != null)
        'exercise_user_preference_id': exerciseUserPreferenceId,
      if (ordinal != null) 'ordinal': ordinal,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseSetupValuesCompanion copyWith(
      {Value<String>? id,
      Value<String>? exerciseUserPreferenceId,
      Value<int>? ordinal,
      Value<String>? label,
      Value<String>? value,
      Value<int>? rowid}) {
    return ExerciseSetupValuesCompanion(
      id: id ?? this.id,
      exerciseUserPreferenceId:
          exerciseUserPreferenceId ?? this.exerciseUserPreferenceId,
      ordinal: ordinal ?? this.ordinal,
      label: label ?? this.label,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (exerciseUserPreferenceId.present) {
      map['exercise_user_preference_id'] =
          Variable<String>(exerciseUserPreferenceId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSetupValuesCompanion(')
          ..write('id: $id, ')
          ..write('exerciseUserPreferenceId: $exerciseUserPreferenceId, ')
          ..write('ordinal: $ordinal, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisePersonalCuesTable extends ExercisePersonalCues
    with TableInfo<$ExercisePersonalCuesTable, ExercisePersonalCue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisePersonalCuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _exerciseUserPreferenceIdMeta =
      const VerificationMeta('exerciseUserPreferenceId');
  @override
  late final GeneratedColumn<String> exerciseUserPreferenceId =
      GeneratedColumn<String>('exercise_user_preference_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES exercise_user_preferences (id)'));
  static const VerificationMeta _ordinalMeta =
      const VerificationMeta('ordinal');
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
      'ordinal', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cueTextMeta =
      const VerificationMeta('cueText');
  @override
  late final GeneratedColumn<String> cueText = GeneratedColumn<String>(
      'cue_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, exerciseUserPreferenceId, ordinal, cueText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_personal_cues';
  @override
  VerificationContext validateIntegrity(
      Insertable<ExercisePersonalCue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exercise_user_preference_id')) {
      context.handle(
          _exerciseUserPreferenceIdMeta,
          exerciseUserPreferenceId.isAcceptableOrUnknown(
              data['exercise_user_preference_id']!,
              _exerciseUserPreferenceIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseUserPreferenceIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(_ordinalMeta,
          ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta));
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('cue_text')) {
      context.handle(_cueTextMeta,
          cueText.isAcceptableOrUnknown(data['cue_text']!, _cueTextMeta));
    } else if (isInserting) {
      context.missing(_cueTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {exerciseUserPreferenceId, ordinal},
      ];
  @override
  ExercisePersonalCue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExercisePersonalCue(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      exerciseUserPreferenceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}exercise_user_preference_id'])!,
      ordinal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ordinal'])!,
      cueText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cue_text'])!,
    );
  }

  @override
  $ExercisePersonalCuesTable createAlias(String alias) {
    return $ExercisePersonalCuesTable(attachedDatabase, alias);
  }
}

class ExercisePersonalCue extends DataClass
    implements Insertable<ExercisePersonalCue> {
  final String id;
  final String exerciseUserPreferenceId;
  final int ordinal;
  final String cueText;
  const ExercisePersonalCue(
      {required this.id,
      required this.exerciseUserPreferenceId,
      required this.ordinal,
      required this.cueText});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exercise_user_preference_id'] =
        Variable<String>(exerciseUserPreferenceId);
    map['ordinal'] = Variable<int>(ordinal);
    map['cue_text'] = Variable<String>(cueText);
    return map;
  }

  ExercisePersonalCuesCompanion toCompanion(bool nullToAbsent) {
    return ExercisePersonalCuesCompanion(
      id: Value(id),
      exerciseUserPreferenceId: Value(exerciseUserPreferenceId),
      ordinal: Value(ordinal),
      cueText: Value(cueText),
    );
  }

  factory ExercisePersonalCue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExercisePersonalCue(
      id: serializer.fromJson<String>(json['id']),
      exerciseUserPreferenceId:
          serializer.fromJson<String>(json['exerciseUserPreferenceId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      cueText: serializer.fromJson<String>(json['cueText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'exerciseUserPreferenceId':
          serializer.toJson<String>(exerciseUserPreferenceId),
      'ordinal': serializer.toJson<int>(ordinal),
      'cueText': serializer.toJson<String>(cueText),
    };
  }

  ExercisePersonalCue copyWith(
          {String? id,
          String? exerciseUserPreferenceId,
          int? ordinal,
          String? cueText}) =>
      ExercisePersonalCue(
        id: id ?? this.id,
        exerciseUserPreferenceId:
            exerciseUserPreferenceId ?? this.exerciseUserPreferenceId,
        ordinal: ordinal ?? this.ordinal,
        cueText: cueText ?? this.cueText,
      );
  ExercisePersonalCue copyWithCompanion(ExercisePersonalCuesCompanion data) {
    return ExercisePersonalCue(
      id: data.id.present ? data.id.value : this.id,
      exerciseUserPreferenceId: data.exerciseUserPreferenceId.present
          ? data.exerciseUserPreferenceId.value
          : this.exerciseUserPreferenceId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      cueText: data.cueText.present ? data.cueText.value : this.cueText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExercisePersonalCue(')
          ..write('id: $id, ')
          ..write('exerciseUserPreferenceId: $exerciseUserPreferenceId, ')
          ..write('ordinal: $ordinal, ')
          ..write('cueText: $cueText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, exerciseUserPreferenceId, ordinal, cueText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExercisePersonalCue &&
          other.id == this.id &&
          other.exerciseUserPreferenceId == this.exerciseUserPreferenceId &&
          other.ordinal == this.ordinal &&
          other.cueText == this.cueText);
}

class ExercisePersonalCuesCompanion
    extends UpdateCompanion<ExercisePersonalCue> {
  final Value<String> id;
  final Value<String> exerciseUserPreferenceId;
  final Value<int> ordinal;
  final Value<String> cueText;
  final Value<int> rowid;
  const ExercisePersonalCuesCompanion({
    this.id = const Value.absent(),
    this.exerciseUserPreferenceId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.cueText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisePersonalCuesCompanion.insert({
    required String id,
    required String exerciseUserPreferenceId,
    required int ordinal,
    required String cueText,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        exerciseUserPreferenceId = Value(exerciseUserPreferenceId),
        ordinal = Value(ordinal),
        cueText = Value(cueText);
  static Insertable<ExercisePersonalCue> custom({
    Expression<String>? id,
    Expression<String>? exerciseUserPreferenceId,
    Expression<int>? ordinal,
    Expression<String>? cueText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseUserPreferenceId != null)
        'exercise_user_preference_id': exerciseUserPreferenceId,
      if (ordinal != null) 'ordinal': ordinal,
      if (cueText != null) 'cue_text': cueText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisePersonalCuesCompanion copyWith(
      {Value<String>? id,
      Value<String>? exerciseUserPreferenceId,
      Value<int>? ordinal,
      Value<String>? cueText,
      Value<int>? rowid}) {
    return ExercisePersonalCuesCompanion(
      id: id ?? this.id,
      exerciseUserPreferenceId:
          exerciseUserPreferenceId ?? this.exerciseUserPreferenceId,
      ordinal: ordinal ?? this.ordinal,
      cueText: cueText ?? this.cueText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (exerciseUserPreferenceId.present) {
      map['exercise_user_preference_id'] =
          Variable<String>(exerciseUserPreferenceId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (cueText.present) {
      map['cue_text'] = Variable<String>(cueText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisePersonalCuesCompanion(')
          ..write('id: $id, ')
          ..write('exerciseUserPreferenceId: $exerciseUserPreferenceId, ')
          ..write('ordinal: $ordinal, ')
          ..write('cueText: $cueText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LegacyRoutineProgramMappingsTable extends LegacyRoutineProgramMappings
    with
        TableInfo<$LegacyRoutineProgramMappingsTable,
            LegacyRoutineProgramMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LegacyRoutineProgramMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _legacyRoutineIdMeta =
      const VerificationMeta('legacyRoutineId');
  @override
  late final GeneratedColumn<int> legacyRoutineId = GeneratedColumn<int>(
      'legacy_routine_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES workout_routines (id)'));
  static const VerificationMeta _programIdMeta =
      const VerificationMeta('programId');
  @override
  late final GeneratedColumn<String> programId = GeneratedColumn<String>(
      'program_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES programs (id)'));
  static const VerificationMeta _programVersionIdMeta =
      const VerificationMeta('programVersionId');
  @override
  late final GeneratedColumn<String> programVersionId = GeneratedColumn<String>(
      'program_version_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES program_versions (id)'));
  static const VerificationMeta _importedAtUtcMeta =
      const VerificationMeta('importedAtUtc');
  @override
  late final GeneratedColumn<DateTime> importedAtUtc =
      GeneratedColumn<DateTime>('imported_at_utc', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [legacyRoutineId, programId, programVersionId, importedAtUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'legacy_routine_program_mappings';
  @override
  VerificationContext validateIntegrity(
      Insertable<LegacyRoutineProgramMapping> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('legacy_routine_id')) {
      context.handle(
          _legacyRoutineIdMeta,
          legacyRoutineId.isAcceptableOrUnknown(
              data['legacy_routine_id']!, _legacyRoutineIdMeta));
    }
    if (data.containsKey('program_id')) {
      context.handle(_programIdMeta,
          programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta));
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('program_version_id')) {
      context.handle(
          _programVersionIdMeta,
          programVersionId.isAcceptableOrUnknown(
              data['program_version_id']!, _programVersionIdMeta));
    } else if (isInserting) {
      context.missing(_programVersionIdMeta);
    }
    if (data.containsKey('imported_at_utc')) {
      context.handle(
          _importedAtUtcMeta,
          importedAtUtc.isAcceptableOrUnknown(
              data['imported_at_utc']!, _importedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_importedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {legacyRoutineId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {programId},
        {programVersionId},
      ];
  @override
  LegacyRoutineProgramMapping map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LegacyRoutineProgramMapping(
      legacyRoutineId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}legacy_routine_id'])!,
      programId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}program_id'])!,
      programVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}program_version_id'])!,
      importedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}imported_at_utc'])!,
    );
  }

  @override
  $LegacyRoutineProgramMappingsTable createAlias(String alias) {
    return $LegacyRoutineProgramMappingsTable(attachedDatabase, alias);
  }
}

class LegacyRoutineProgramMapping extends DataClass
    implements Insertable<LegacyRoutineProgramMapping> {
  final int legacyRoutineId;
  final String programId;
  final String programVersionId;
  final DateTime importedAtUtc;
  const LegacyRoutineProgramMapping(
      {required this.legacyRoutineId,
      required this.programId,
      required this.programVersionId,
      required this.importedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['legacy_routine_id'] = Variable<int>(legacyRoutineId);
    map['program_id'] = Variable<String>(programId);
    map['program_version_id'] = Variable<String>(programVersionId);
    map['imported_at_utc'] = Variable<DateTime>(importedAtUtc);
    return map;
  }

  LegacyRoutineProgramMappingsCompanion toCompanion(bool nullToAbsent) {
    return LegacyRoutineProgramMappingsCompanion(
      legacyRoutineId: Value(legacyRoutineId),
      programId: Value(programId),
      programVersionId: Value(programVersionId),
      importedAtUtc: Value(importedAtUtc),
    );
  }

  factory LegacyRoutineProgramMapping.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LegacyRoutineProgramMapping(
      legacyRoutineId: serializer.fromJson<int>(json['legacyRoutineId']),
      programId: serializer.fromJson<String>(json['programId']),
      programVersionId: serializer.fromJson<String>(json['programVersionId']),
      importedAtUtc: serializer.fromJson<DateTime>(json['importedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'legacyRoutineId': serializer.toJson<int>(legacyRoutineId),
      'programId': serializer.toJson<String>(programId),
      'programVersionId': serializer.toJson<String>(programVersionId),
      'importedAtUtc': serializer.toJson<DateTime>(importedAtUtc),
    };
  }

  LegacyRoutineProgramMapping copyWith(
          {int? legacyRoutineId,
          String? programId,
          String? programVersionId,
          DateTime? importedAtUtc}) =>
      LegacyRoutineProgramMapping(
        legacyRoutineId: legacyRoutineId ?? this.legacyRoutineId,
        programId: programId ?? this.programId,
        programVersionId: programVersionId ?? this.programVersionId,
        importedAtUtc: importedAtUtc ?? this.importedAtUtc,
      );
  LegacyRoutineProgramMapping copyWithCompanion(
      LegacyRoutineProgramMappingsCompanion data) {
    return LegacyRoutineProgramMapping(
      legacyRoutineId: data.legacyRoutineId.present
          ? data.legacyRoutineId.value
          : this.legacyRoutineId,
      programId: data.programId.present ? data.programId.value : this.programId,
      programVersionId: data.programVersionId.present
          ? data.programVersionId.value
          : this.programVersionId,
      importedAtUtc: data.importedAtUtc.present
          ? data.importedAtUtc.value
          : this.importedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LegacyRoutineProgramMapping(')
          ..write('legacyRoutineId: $legacyRoutineId, ')
          ..write('programId: $programId, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('importedAtUtc: $importedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(legacyRoutineId, programId, programVersionId, importedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LegacyRoutineProgramMapping &&
          other.legacyRoutineId == this.legacyRoutineId &&
          other.programId == this.programId &&
          other.programVersionId == this.programVersionId &&
          other.importedAtUtc == this.importedAtUtc);
}

class LegacyRoutineProgramMappingsCompanion
    extends UpdateCompanion<LegacyRoutineProgramMapping> {
  final Value<int> legacyRoutineId;
  final Value<String> programId;
  final Value<String> programVersionId;
  final Value<DateTime> importedAtUtc;
  const LegacyRoutineProgramMappingsCompanion({
    this.legacyRoutineId = const Value.absent(),
    this.programId = const Value.absent(),
    this.programVersionId = const Value.absent(),
    this.importedAtUtc = const Value.absent(),
  });
  LegacyRoutineProgramMappingsCompanion.insert({
    this.legacyRoutineId = const Value.absent(),
    required String programId,
    required String programVersionId,
    required DateTime importedAtUtc,
  })  : programId = Value(programId),
        programVersionId = Value(programVersionId),
        importedAtUtc = Value(importedAtUtc);
  static Insertable<LegacyRoutineProgramMapping> custom({
    Expression<int>? legacyRoutineId,
    Expression<String>? programId,
    Expression<String>? programVersionId,
    Expression<DateTime>? importedAtUtc,
  }) {
    return RawValuesInsertable({
      if (legacyRoutineId != null) 'legacy_routine_id': legacyRoutineId,
      if (programId != null) 'program_id': programId,
      if (programVersionId != null) 'program_version_id': programVersionId,
      if (importedAtUtc != null) 'imported_at_utc': importedAtUtc,
    });
  }

  LegacyRoutineProgramMappingsCompanion copyWith(
      {Value<int>? legacyRoutineId,
      Value<String>? programId,
      Value<String>? programVersionId,
      Value<DateTime>? importedAtUtc}) {
    return LegacyRoutineProgramMappingsCompanion(
      legacyRoutineId: legacyRoutineId ?? this.legacyRoutineId,
      programId: programId ?? this.programId,
      programVersionId: programVersionId ?? this.programVersionId,
      importedAtUtc: importedAtUtc ?? this.importedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (legacyRoutineId.present) {
      map['legacy_routine_id'] = Variable<int>(legacyRoutineId.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<String>(programId.value);
    }
    if (programVersionId.present) {
      map['program_version_id'] = Variable<String>(programVersionId.value);
    }
    if (importedAtUtc.present) {
      map['imported_at_utc'] = Variable<DateTime>(importedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LegacyRoutineProgramMappingsCompanion(')
          ..write('legacyRoutineId: $legacyRoutineId, ')
          ..write('programId: $programId, ')
          ..write('programVersionId: $programVersionId, ')
          ..write('importedAtUtc: $importedAtUtc')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoodItemsTable foodItems = $FoodItemsTable(this);
  late final $FoodLogsTable foodLogs = $FoodLogsTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $WorkoutSessionsTable workoutSessions =
      $WorkoutSessionsTable(this);
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $BodyMeasurementsTable bodyMeasurements =
      $BodyMeasurementsTable(this);
  late final $WorkoutRoutinesTable workoutRoutines =
      $WorkoutRoutinesTable(this);
  late final $RoutineDaysTable routineDays = $RoutineDaysTable(this);
  late final $RoutineExercisesTable routineExercises =
      $RoutineExercisesTable(this);
  late final $WorkoutDraftsTable workoutDrafts = $WorkoutDraftsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $MealTemplatesTable mealTemplates = $MealTemplatesTable(this);
  late final $MealTemplateItemsTable mealTemplateItems =
      $MealTemplateItemsTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $DailyHydrationsTable dailyHydrations =
      $DailyHydrationsTable(this);
  late final $HealthProvenancesTable healthProvenances =
      $HealthProvenancesTable(this);
  late final $AchievementUnlocksTable achievementUnlocks =
      $AchievementUnlocksTable(this);
  late final $ProgramsTable programs = $ProgramsTable(this);
  late final $ProgramVersionsTable programVersions =
      $ProgramVersionsTable(this);
  late final $ProgramBlocksTable programBlocks = $ProgramBlocksTable(this);
  late final $ProgramWeeksTable programWeeks = $ProgramWeeksTable(this);
  late final $SessionTemplatesTable sessionTemplates =
      $SessionTemplatesTable(this);
  late final $ExercisePrescriptionsTable exercisePrescriptions =
      $ExercisePrescriptionsTable(this);
  late final $ScheduledSessionOccurrencesTable scheduledSessionOccurrences =
      $ScheduledSessionOccurrencesTable(this);
  late final $OccurrenceEventsTable occurrenceEvents =
      $OccurrenceEventsTable(this);
  late final $EquipmentProfilesTable equipmentProfiles =
      $EquipmentProfilesTable(this);
  late final $TrainingPlanSettingsTable trainingPlanSettings =
      $TrainingPlanSettingsTable(this);
  late final $EquipmentProfileItemsTable equipmentProfileItems =
      $EquipmentProfileItemsTable(this);
  late final $TravelContextsTable travelContexts = $TravelContextsTable(this);
  late final $TravelContextOccurrencesTable travelContextOccurrences =
      $TravelContextOccurrencesTable(this);
  late final $ExerciseUserPreferencesTable exerciseUserPreferences =
      $ExerciseUserPreferencesTable(this);
  late final $ExerciseSetupValuesTable exerciseSetupValues =
      $ExerciseSetupValuesTable(this);
  late final $ExercisePersonalCuesTable exercisePersonalCues =
      $ExercisePersonalCuesTable(this);
  late final $LegacyRoutineProgramMappingsTable legacyRoutineProgramMappings =
      $LegacyRoutineProgramMappingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        foodItems,
        foodLogs,
        exercises,
        workoutSessions,
        workoutSets,
        bodyMeasurements,
        workoutRoutines,
        routineDays,
        routineExercises,
        workoutDrafts,
        userProfiles,
        mealTemplates,
        mealTemplateItems,
        userSettings,
        dailyHydrations,
        healthProvenances,
        achievementUnlocks,
        programs,
        programVersions,
        programBlocks,
        programWeeks,
        sessionTemplates,
        exercisePrescriptions,
        scheduledSessionOccurrences,
        occurrenceEvents,
        equipmentProfiles,
        trainingPlanSettings,
        equipmentProfileItems,
        travelContexts,
        travelContextOccurrences,
        exerciseUserPreferences,
        exerciseSetupValues,
        exercisePersonalCues,
        legacyRoutineProgramMappings
      ];
}

typedef $$FoodItemsTableCreateCompanionBuilder = FoodItemsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> nameHindi,
  required int calories,
  required double proteinG,
  required double carbsG,
  required double fatG,
  Value<double?> fiberG,
  required double servingSize,
  required String servingUnit,
  required String category,
  Value<bool> isCustom,
  Value<String?> brand,
  Value<String?> regionPack,
});
typedef $$FoodItemsTableUpdateCompanionBuilder = FoodItemsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> nameHindi,
  Value<int> calories,
  Value<double> proteinG,
  Value<double> carbsG,
  Value<double> fatG,
  Value<double?> fiberG,
  Value<double> servingSize,
  Value<String> servingUnit,
  Value<String> category,
  Value<bool> isCustom,
  Value<String?> brand,
  Value<String?> regionPack,
});

class $$FoodItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FoodItemsTable,
    FoodItem,
    $$FoodItemsTableFilterComposer,
    $$FoodItemsTableOrderingComposer,
    $$FoodItemsTableCreateCompanionBuilder,
    $$FoodItemsTableUpdateCompanionBuilder> {
  $$FoodItemsTableTableManager(_$AppDatabase db, $FoodItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$FoodItemsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$FoodItemsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> nameHindi = const Value.absent(),
            Value<int> calories = const Value.absent(),
            Value<double> proteinG = const Value.absent(),
            Value<double> carbsG = const Value.absent(),
            Value<double> fatG = const Value.absent(),
            Value<double?> fiberG = const Value.absent(),
            Value<double> servingSize = const Value.absent(),
            Value<String> servingUnit = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<bool> isCustom = const Value.absent(),
            Value<String?> brand = const Value.absent(),
            Value<String?> regionPack = const Value.absent(),
          }) =>
              FoodItemsCompanion(
            id: id,
            name: name,
            nameHindi: nameHindi,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            servingSize: servingSize,
            servingUnit: servingUnit,
            category: category,
            isCustom: isCustom,
            brand: brand,
            regionPack: regionPack,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> nameHindi = const Value.absent(),
            required int calories,
            required double proteinG,
            required double carbsG,
            required double fatG,
            Value<double?> fiberG = const Value.absent(),
            required double servingSize,
            required String servingUnit,
            required String category,
            Value<bool> isCustom = const Value.absent(),
            Value<String?> brand = const Value.absent(),
            Value<String?> regionPack = const Value.absent(),
          }) =>
              FoodItemsCompanion.insert(
            id: id,
            name: name,
            nameHindi: nameHindi,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            servingSize: servingSize,
            servingUnit: servingUnit,
            category: category,
            isCustom: isCustom,
            brand: brand,
            regionPack: regionPack,
          ),
        ));
}

class $$FoodItemsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get nameHindi => $state.composableBuilder(
      column: $state.table.nameHindi,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get calories => $state.composableBuilder(
      column: $state.table.calories,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get proteinG => $state.composableBuilder(
      column: $state.table.proteinG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get carbsG => $state.composableBuilder(
      column: $state.table.carbsG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get fatG => $state.composableBuilder(
      column: $state.table.fatG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get fiberG => $state.composableBuilder(
      column: $state.table.fiberG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get servingSize => $state.composableBuilder(
      column: $state.table.servingSize,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get servingUnit => $state.composableBuilder(
      column: $state.table.servingUnit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isCustom => $state.composableBuilder(
      column: $state.table.isCustom,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get regionPack => $state.composableBuilder(
      column: $state.table.regionPack,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter foodLogsRefs(
      ComposableFilter Function($$FoodLogsTableFilterComposer f) f) {
    final $$FoodLogsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.foodLogs,
        getReferencedColumn: (t) => t.foodItemId,
        builder: (joinBuilder, parentComposers) =>
            $$FoodLogsTableFilterComposer(ComposerState(
                $state.db, $state.db.foodLogs, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$FoodItemsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get nameHindi => $state.composableBuilder(
      column: $state.table.nameHindi,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get calories => $state.composableBuilder(
      column: $state.table.calories,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get proteinG => $state.composableBuilder(
      column: $state.table.proteinG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get carbsG => $state.composableBuilder(
      column: $state.table.carbsG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get fatG => $state.composableBuilder(
      column: $state.table.fatG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get fiberG => $state.composableBuilder(
      column: $state.table.fiberG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get servingSize => $state.composableBuilder(
      column: $state.table.servingSize,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get servingUnit => $state.composableBuilder(
      column: $state.table.servingUnit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isCustom => $state.composableBuilder(
      column: $state.table.isCustom,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get brand => $state.composableBuilder(
      column: $state.table.brand,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get regionPack => $state.composableBuilder(
      column: $state.table.regionPack,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$FoodLogsTableCreateCompanionBuilder = FoodLogsCompanion Function({
  Value<int> id,
  Value<int?> foodItemId,
  required String name,
  required int calories,
  required double proteinG,
  required double carbsG,
  required double fatG,
  required double servingLogged,
  required String servingUnit,
  required String mealType,
  Value<DateTime> loggedAt,
  Value<bool> isSynced,
  Value<String?> mealGroupId,
  Value<String?> uuid,
});
typedef $$FoodLogsTableUpdateCompanionBuilder = FoodLogsCompanion Function({
  Value<int> id,
  Value<int?> foodItemId,
  Value<String> name,
  Value<int> calories,
  Value<double> proteinG,
  Value<double> carbsG,
  Value<double> fatG,
  Value<double> servingLogged,
  Value<String> servingUnit,
  Value<String> mealType,
  Value<DateTime> loggedAt,
  Value<bool> isSynced,
  Value<String?> mealGroupId,
  Value<String?> uuid,
});

class $$FoodLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FoodLogsTable,
    FoodLog,
    $$FoodLogsTableFilterComposer,
    $$FoodLogsTableOrderingComposer,
    $$FoodLogsTableCreateCompanionBuilder,
    $$FoodLogsTableUpdateCompanionBuilder> {
  $$FoodLogsTableTableManager(_$AppDatabase db, $FoodLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$FoodLogsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$FoodLogsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> foodItemId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> calories = const Value.absent(),
            Value<double> proteinG = const Value.absent(),
            Value<double> carbsG = const Value.absent(),
            Value<double> fatG = const Value.absent(),
            Value<double> servingLogged = const Value.absent(),
            Value<String> servingUnit = const Value.absent(),
            Value<String> mealType = const Value.absent(),
            Value<DateTime> loggedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<String?> mealGroupId = const Value.absent(),
            Value<String?> uuid = const Value.absent(),
          }) =>
              FoodLogsCompanion(
            id: id,
            foodItemId: foodItemId,
            name: name,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            servingLogged: servingLogged,
            servingUnit: servingUnit,
            mealType: mealType,
            loggedAt: loggedAt,
            isSynced: isSynced,
            mealGroupId: mealGroupId,
            uuid: uuid,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> foodItemId = const Value.absent(),
            required String name,
            required int calories,
            required double proteinG,
            required double carbsG,
            required double fatG,
            required double servingLogged,
            required String servingUnit,
            required String mealType,
            Value<DateTime> loggedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<String?> mealGroupId = const Value.absent(),
            Value<String?> uuid = const Value.absent(),
          }) =>
              FoodLogsCompanion.insert(
            id: id,
            foodItemId: foodItemId,
            name: name,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            servingLogged: servingLogged,
            servingUnit: servingUnit,
            mealType: mealType,
            loggedAt: loggedAt,
            isSynced: isSynced,
            mealGroupId: mealGroupId,
            uuid: uuid,
          ),
        ));
}

class $$FoodLogsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $FoodLogsTable> {
  $$FoodLogsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get calories => $state.composableBuilder(
      column: $state.table.calories,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get proteinG => $state.composableBuilder(
      column: $state.table.proteinG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get carbsG => $state.composableBuilder(
      column: $state.table.carbsG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get fatG => $state.composableBuilder(
      column: $state.table.fatG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get servingLogged => $state.composableBuilder(
      column: $state.table.servingLogged,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get servingUnit => $state.composableBuilder(
      column: $state.table.servingUnit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get mealType => $state.composableBuilder(
      column: $state.table.mealType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get loggedAt => $state.composableBuilder(
      column: $state.table.loggedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get mealGroupId => $state.composableBuilder(
      column: $state.table.mealGroupId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$FoodItemsTableFilterComposer get foodItemId {
    final $$FoodItemsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.foodItemId,
        referencedTable: $state.db.foodItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$FoodItemsTableFilterComposer(ComposerState(
                $state.db, $state.db.foodItems, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$FoodLogsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $FoodLogsTable> {
  $$FoodLogsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get calories => $state.composableBuilder(
      column: $state.table.calories,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get proteinG => $state.composableBuilder(
      column: $state.table.proteinG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get carbsG => $state.composableBuilder(
      column: $state.table.carbsG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get fatG => $state.composableBuilder(
      column: $state.table.fatG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get servingLogged => $state.composableBuilder(
      column: $state.table.servingLogged,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get servingUnit => $state.composableBuilder(
      column: $state.table.servingUnit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get mealType => $state.composableBuilder(
      column: $state.table.mealType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get loggedAt => $state.composableBuilder(
      column: $state.table.loggedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get mealGroupId => $state.composableBuilder(
      column: $state.table.mealGroupId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$FoodItemsTableOrderingComposer get foodItemId {
    final $$FoodItemsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.foodItemId,
        referencedTable: $state.db.foodItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$FoodItemsTableOrderingComposer(ComposerState(
                $state.db, $state.db.foodItems, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ExercisesTableCreateCompanionBuilder = ExercisesCompanion Function({
  Value<int> id,
  Value<String?> stableId,
  required String name,
  required String muscleGroups,
  required String equipment,
  required String difficulty,
  required String formCues,
  required String commonMistakes,
  Value<String?> youtubeId,
  Value<bool> isCustom,
});
typedef $$ExercisesTableUpdateCompanionBuilder = ExercisesCompanion Function({
  Value<int> id,
  Value<String?> stableId,
  Value<String> name,
  Value<String> muscleGroups,
  Value<String> equipment,
  Value<String> difficulty,
  Value<String> formCues,
  Value<String> commonMistakes,
  Value<String?> youtubeId,
  Value<bool> isCustom,
});

class $$ExercisesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExercisesTable,
    Exercise,
    $$ExercisesTableFilterComposer,
    $$ExercisesTableOrderingComposer,
    $$ExercisesTableCreateCompanionBuilder,
    $$ExercisesTableUpdateCompanionBuilder> {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ExercisesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ExercisesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> stableId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> muscleGroups = const Value.absent(),
            Value<String> equipment = const Value.absent(),
            Value<String> difficulty = const Value.absent(),
            Value<String> formCues = const Value.absent(),
            Value<String> commonMistakes = const Value.absent(),
            Value<String?> youtubeId = const Value.absent(),
            Value<bool> isCustom = const Value.absent(),
          }) =>
              ExercisesCompanion(
            id: id,
            stableId: stableId,
            name: name,
            muscleGroups: muscleGroups,
            equipment: equipment,
            difficulty: difficulty,
            formCues: formCues,
            commonMistakes: commonMistakes,
            youtubeId: youtubeId,
            isCustom: isCustom,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> stableId = const Value.absent(),
            required String name,
            required String muscleGroups,
            required String equipment,
            required String difficulty,
            required String formCues,
            required String commonMistakes,
            Value<String?> youtubeId = const Value.absent(),
            Value<bool> isCustom = const Value.absent(),
          }) =>
              ExercisesCompanion.insert(
            id: id,
            stableId: stableId,
            name: name,
            muscleGroups: muscleGroups,
            equipment: equipment,
            difficulty: difficulty,
            formCues: formCues,
            commonMistakes: commonMistakes,
            youtubeId: youtubeId,
            isCustom: isCustom,
          ),
        ));
}

class $$ExercisesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get stableId => $state.composableBuilder(
      column: $state.table.stableId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get muscleGroups => $state.composableBuilder(
      column: $state.table.muscleGroups,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get equipment => $state.composableBuilder(
      column: $state.table.equipment,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get difficulty => $state.composableBuilder(
      column: $state.table.difficulty,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get formCues => $state.composableBuilder(
      column: $state.table.formCues,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get commonMistakes => $state.composableBuilder(
      column: $state.table.commonMistakes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get youtubeId => $state.composableBuilder(
      column: $state.table.youtubeId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isCustom => $state.composableBuilder(
      column: $state.table.isCustom,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter workoutSetsRefs(
      ComposableFilter Function($$WorkoutSetsTableFilterComposer f) f) {
    final $$WorkoutSetsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stableId,
        referencedTable: $state.db.workoutSets,
        getReferencedColumn: (t) => t.exerciseId,
        builder: (joinBuilder, parentComposers) =>
            $$WorkoutSetsTableFilterComposer(ComposerState($state.db,
                $state.db.workoutSets, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter exercisePrescriptionsRefs(
      ComposableFilter Function($$ExercisePrescriptionsTableFilterComposer f)
          f) {
    final $$ExercisePrescriptionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.stableId,
            referencedTable: $state.db.exercisePrescriptions,
            getReferencedColumn: (t) => t.exerciseId,
            builder: (joinBuilder, parentComposers) =>
                $$ExercisePrescriptionsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.exercisePrescriptions,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter exerciseUserPreferencesRefs(
      ComposableFilter Function($$ExerciseUserPreferencesTableFilterComposer f)
          f) {
    final $$ExerciseUserPreferencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.stableId,
            referencedTable: $state.db.exerciseUserPreferences,
            getReferencedColumn: (t) => t.exerciseId,
            builder: (joinBuilder, parentComposers) =>
                $$ExerciseUserPreferencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.exerciseUserPreferences,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ExercisesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get stableId => $state.composableBuilder(
      column: $state.table.stableId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get muscleGroups => $state.composableBuilder(
      column: $state.table.muscleGroups,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get equipment => $state.composableBuilder(
      column: $state.table.equipment,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get difficulty => $state.composableBuilder(
      column: $state.table.difficulty,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get formCues => $state.composableBuilder(
      column: $state.table.formCues,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get commonMistakes => $state.composableBuilder(
      column: $state.table.commonMistakes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get youtubeId => $state.composableBuilder(
      column: $state.table.youtubeId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isCustom => $state.composableBuilder(
      column: $state.table.isCustom,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$WorkoutSessionsTableCreateCompanionBuilder = WorkoutSessionsCompanion
    Function({
  Value<int> id,
  required String name,
  required double totalVolume,
  required int durationSeconds,
  required int estimatedCalories,
  Value<DateTime> completedAt,
  Value<bool> isSynced,
  Value<String?> uuid,
  Value<String?> scheduledOccurrenceId,
  Value<String?> executionSnapshotJson,
  Value<String?> executionTimezoneId,
  Value<String?> completionKind,
});
typedef $$WorkoutSessionsTableUpdateCompanionBuilder = WorkoutSessionsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<double> totalVolume,
  Value<int> durationSeconds,
  Value<int> estimatedCalories,
  Value<DateTime> completedAt,
  Value<bool> isSynced,
  Value<String?> uuid,
  Value<String?> scheduledOccurrenceId,
  Value<String?> executionSnapshotJson,
  Value<String?> executionTimezoneId,
  Value<String?> completionKind,
});

class $$WorkoutSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutSessionsTable,
    WorkoutSession,
    $$WorkoutSessionsTableFilterComposer,
    $$WorkoutSessionsTableOrderingComposer,
    $$WorkoutSessionsTableCreateCompanionBuilder,
    $$WorkoutSessionsTableUpdateCompanionBuilder> {
  $$WorkoutSessionsTableTableManager(
      _$AppDatabase db, $WorkoutSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$WorkoutSessionsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$WorkoutSessionsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> totalVolume = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<int> estimatedCalories = const Value.absent(),
            Value<DateTime> completedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<String?> uuid = const Value.absent(),
            Value<String?> scheduledOccurrenceId = const Value.absent(),
            Value<String?> executionSnapshotJson = const Value.absent(),
            Value<String?> executionTimezoneId = const Value.absent(),
            Value<String?> completionKind = const Value.absent(),
          }) =>
              WorkoutSessionsCompanion(
            id: id,
            name: name,
            totalVolume: totalVolume,
            durationSeconds: durationSeconds,
            estimatedCalories: estimatedCalories,
            completedAt: completedAt,
            isSynced: isSynced,
            uuid: uuid,
            scheduledOccurrenceId: scheduledOccurrenceId,
            executionSnapshotJson: executionSnapshotJson,
            executionTimezoneId: executionTimezoneId,
            completionKind: completionKind,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required double totalVolume,
            required int durationSeconds,
            required int estimatedCalories,
            Value<DateTime> completedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<String?> uuid = const Value.absent(),
            Value<String?> scheduledOccurrenceId = const Value.absent(),
            Value<String?> executionSnapshotJson = const Value.absent(),
            Value<String?> executionTimezoneId = const Value.absent(),
            Value<String?> completionKind = const Value.absent(),
          }) =>
              WorkoutSessionsCompanion.insert(
            id: id,
            name: name,
            totalVolume: totalVolume,
            durationSeconds: durationSeconds,
            estimatedCalories: estimatedCalories,
            completedAt: completedAt,
            isSynced: isSynced,
            uuid: uuid,
            scheduledOccurrenceId: scheduledOccurrenceId,
            executionSnapshotJson: executionSnapshotJson,
            executionTimezoneId: executionTimezoneId,
            completionKind: completionKind,
          ),
        ));
}

class $$WorkoutSessionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get totalVolume => $state.composableBuilder(
      column: $state.table.totalVolume,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get durationSeconds => $state.composableBuilder(
      column: $state.table.durationSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get estimatedCalories => $state.composableBuilder(
      column: $state.table.estimatedCalories,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get completedAt => $state.composableBuilder(
      column: $state.table.completedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scheduledOccurrenceId => $state.composableBuilder(
      column: $state.table.scheduledOccurrenceId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get executionSnapshotJson => $state.composableBuilder(
      column: $state.table.executionSnapshotJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get executionTimezoneId => $state.composableBuilder(
      column: $state.table.executionTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get completionKind => $state.composableBuilder(
      column: $state.table.completionKind,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter workoutSetsRefs(
      ComposableFilter Function($$WorkoutSetsTableFilterComposer f) f) {
    final $$WorkoutSetsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.workoutSets,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) =>
            $$WorkoutSetsTableFilterComposer(ComposerState($state.db,
                $state.db.workoutSets, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter healthProvenancesRefs(
      ComposableFilter Function($$HealthProvenancesTableFilterComposer f) f) {
    final $$HealthProvenancesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.healthProvenances,
            getReferencedColumn: (t) => t.localSessionId,
            builder: (joinBuilder, parentComposers) =>
                $$HealthProvenancesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.healthProvenances,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$WorkoutSessionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get totalVolume => $state.composableBuilder(
      column: $state.table.totalVolume,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get durationSeconds => $state.composableBuilder(
      column: $state.table.durationSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get estimatedCalories => $state.composableBuilder(
      column: $state.table.estimatedCalories,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get completedAt => $state.composableBuilder(
      column: $state.table.completedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scheduledOccurrenceId => $state.composableBuilder(
      column: $state.table.scheduledOccurrenceId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get executionSnapshotJson => $state.composableBuilder(
      column: $state.table.executionSnapshotJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get executionTimezoneId => $state.composableBuilder(
      column: $state.table.executionTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get completionKind => $state.composableBuilder(
      column: $state.table.completionKind,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$WorkoutSetsTableCreateCompanionBuilder = WorkoutSetsCompanion
    Function({
  Value<int> id,
  required int sessionId,
  required String exerciseName,
  required double weight,
  required int reps,
  required int setNumber,
  Value<bool> isPr,
  Value<int?> rpe,
  Value<bool> isWarmUp,
  Value<String?> setNotes,
  Value<String?> uuid,
  Value<String> setType,
  Value<int?> durationSeconds,
  Value<double?> distanceKm,
  Value<double?> inclinePercentage,
  Value<String?> exerciseId,
});
typedef $$WorkoutSetsTableUpdateCompanionBuilder = WorkoutSetsCompanion
    Function({
  Value<int> id,
  Value<int> sessionId,
  Value<String> exerciseName,
  Value<double> weight,
  Value<int> reps,
  Value<int> setNumber,
  Value<bool> isPr,
  Value<int?> rpe,
  Value<bool> isWarmUp,
  Value<String?> setNotes,
  Value<String?> uuid,
  Value<String> setType,
  Value<int?> durationSeconds,
  Value<double?> distanceKm,
  Value<double?> inclinePercentage,
  Value<String?> exerciseId,
});

class $$WorkoutSetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutSetsTable,
    WorkoutSet,
    $$WorkoutSetsTableFilterComposer,
    $$WorkoutSetsTableOrderingComposer,
    $$WorkoutSetsTableCreateCompanionBuilder,
    $$WorkoutSetsTableUpdateCompanionBuilder> {
  $$WorkoutSetsTableTableManager(_$AppDatabase db, $WorkoutSetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$WorkoutSetsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$WorkoutSetsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<String> exerciseName = const Value.absent(),
            Value<double> weight = const Value.absent(),
            Value<int> reps = const Value.absent(),
            Value<int> setNumber = const Value.absent(),
            Value<bool> isPr = const Value.absent(),
            Value<int?> rpe = const Value.absent(),
            Value<bool> isWarmUp = const Value.absent(),
            Value<String?> setNotes = const Value.absent(),
            Value<String?> uuid = const Value.absent(),
            Value<String> setType = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<double?> distanceKm = const Value.absent(),
            Value<double?> inclinePercentage = const Value.absent(),
            Value<String?> exerciseId = const Value.absent(),
          }) =>
              WorkoutSetsCompanion(
            id: id,
            sessionId: sessionId,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            setNumber: setNumber,
            isPr: isPr,
            rpe: rpe,
            isWarmUp: isWarmUp,
            setNotes: setNotes,
            uuid: uuid,
            setType: setType,
            durationSeconds: durationSeconds,
            distanceKm: distanceKm,
            inclinePercentage: inclinePercentage,
            exerciseId: exerciseId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sessionId,
            required String exerciseName,
            required double weight,
            required int reps,
            required int setNumber,
            Value<bool> isPr = const Value.absent(),
            Value<int?> rpe = const Value.absent(),
            Value<bool> isWarmUp = const Value.absent(),
            Value<String?> setNotes = const Value.absent(),
            Value<String?> uuid = const Value.absent(),
            Value<String> setType = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<double?> distanceKm = const Value.absent(),
            Value<double?> inclinePercentage = const Value.absent(),
            Value<String?> exerciseId = const Value.absent(),
          }) =>
              WorkoutSetsCompanion.insert(
            id: id,
            sessionId: sessionId,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            setNumber: setNumber,
            isPr: isPr,
            rpe: rpe,
            isWarmUp: isWarmUp,
            setNotes: setNotes,
            uuid: uuid,
            setType: setType,
            durationSeconds: durationSeconds,
            distanceKm: distanceKm,
            inclinePercentage: inclinePercentage,
            exerciseId: exerciseId,
          ),
        ));
}

class $$WorkoutSetsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get exerciseName => $state.composableBuilder(
      column: $state.table.exerciseName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get reps => $state.composableBuilder(
      column: $state.table.reps,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get setNumber => $state.composableBuilder(
      column: $state.table.setNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isPr => $state.composableBuilder(
      column: $state.table.isPr,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get rpe => $state.composableBuilder(
      column: $state.table.rpe,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isWarmUp => $state.composableBuilder(
      column: $state.table.isWarmUp,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get setNotes => $state.composableBuilder(
      column: $state.table.setNotes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get setType => $state.composableBuilder(
      column: $state.table.setType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get durationSeconds => $state.composableBuilder(
      column: $state.table.durationSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get distanceKm => $state.composableBuilder(
      column: $state.table.distanceKm,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get inclinePercentage => $state.composableBuilder(
      column: $state.table.inclinePercentage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$WorkoutSessionsTableFilterComposer get sessionId {
    final $$WorkoutSessionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sessionId,
            referencedTable: $state.db.workoutSessions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutSessionsTableFilterComposer(ComposerState($state.db,
                    $state.db.workoutSessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $state.db.exercises,
        getReferencedColumn: (t) => t.stableId,
        builder: (joinBuilder, parentComposers) =>
            $$ExercisesTableFilterComposer(ComposerState(
                $state.db, $state.db.exercises, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$WorkoutSetsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get exerciseName => $state.composableBuilder(
      column: $state.table.exerciseName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get reps => $state.composableBuilder(
      column: $state.table.reps,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get setNumber => $state.composableBuilder(
      column: $state.table.setNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isPr => $state.composableBuilder(
      column: $state.table.isPr,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get rpe => $state.composableBuilder(
      column: $state.table.rpe,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isWarmUp => $state.composableBuilder(
      column: $state.table.isWarmUp,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get setNotes => $state.composableBuilder(
      column: $state.table.setNotes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get setType => $state.composableBuilder(
      column: $state.table.setType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get durationSeconds => $state.composableBuilder(
      column: $state.table.durationSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get distanceKm => $state.composableBuilder(
      column: $state.table.distanceKm,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get inclinePercentage => $state.composableBuilder(
      column: $state.table.inclinePercentage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$WorkoutSessionsTableOrderingComposer get sessionId {
    final $$WorkoutSessionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sessionId,
            referencedTable: $state.db.workoutSessions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutSessionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.workoutSessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $state.db.exercises,
        getReferencedColumn: (t) => t.stableId,
        builder: (joinBuilder, parentComposers) =>
            $$ExercisesTableOrderingComposer(ComposerState(
                $state.db, $state.db.exercises, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$BodyMeasurementsTableCreateCompanionBuilder
    = BodyMeasurementsCompanion Function({
  Value<int> id,
  Value<double?> weight,
  Value<double?> waist,
  Value<double?> chest,
  Value<double?> arms,
  Value<DateTime> recordedAt,
  Value<bool> isSynced,
});
typedef $$BodyMeasurementsTableUpdateCompanionBuilder
    = BodyMeasurementsCompanion Function({
  Value<int> id,
  Value<double?> weight,
  Value<double?> waist,
  Value<double?> chest,
  Value<double?> arms,
  Value<DateTime> recordedAt,
  Value<bool> isSynced,
});

class $$BodyMeasurementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BodyMeasurementsTable,
    BodyMeasurement,
    $$BodyMeasurementsTableFilterComposer,
    $$BodyMeasurementsTableOrderingComposer,
    $$BodyMeasurementsTableCreateCompanionBuilder,
    $$BodyMeasurementsTableUpdateCompanionBuilder> {
  $$BodyMeasurementsTableTableManager(
      _$AppDatabase db, $BodyMeasurementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$BodyMeasurementsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$BodyMeasurementsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<double?> weight = const Value.absent(),
            Value<double?> waist = const Value.absent(),
            Value<double?> chest = const Value.absent(),
            Value<double?> arms = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              BodyMeasurementsCompanion(
            id: id,
            weight: weight,
            waist: waist,
            chest: chest,
            arms: arms,
            recordedAt: recordedAt,
            isSynced: isSynced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<double?> weight = const Value.absent(),
            Value<double?> waist = const Value.absent(),
            Value<double?> chest = const Value.absent(),
            Value<double?> arms = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              BodyMeasurementsCompanion.insert(
            id: id,
            weight: weight,
            waist: waist,
            chest: chest,
            arms: arms,
            recordedAt: recordedAt,
            isSynced: isSynced,
          ),
        ));
}

class $$BodyMeasurementsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $BodyMeasurementsTable> {
  $$BodyMeasurementsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get waist => $state.composableBuilder(
      column: $state.table.waist,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get chest => $state.composableBuilder(
      column: $state.table.chest,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get arms => $state.composableBuilder(
      column: $state.table.arms,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get recordedAt => $state.composableBuilder(
      column: $state.table.recordedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$BodyMeasurementsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $BodyMeasurementsTable> {
  $$BodyMeasurementsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get waist => $state.composableBuilder(
      column: $state.table.waist,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get chest => $state.composableBuilder(
      column: $state.table.chest,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get arms => $state.composableBuilder(
      column: $state.table.arms,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get recordedAt => $state.composableBuilder(
      column: $state.table.recordedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$WorkoutRoutinesTableCreateCompanionBuilder = WorkoutRoutinesCompanion
    Function({
  Value<int> id,
  required String name,
  required String goal,
  Value<String?> notes,
  Value<DateTime> createdAt,
});
typedef $$WorkoutRoutinesTableUpdateCompanionBuilder = WorkoutRoutinesCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String> goal,
  Value<String?> notes,
  Value<DateTime> createdAt,
});

class $$WorkoutRoutinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutRoutinesTable,
    WorkoutRoutine,
    $$WorkoutRoutinesTableFilterComposer,
    $$WorkoutRoutinesTableOrderingComposer,
    $$WorkoutRoutinesTableCreateCompanionBuilder,
    $$WorkoutRoutinesTableUpdateCompanionBuilder> {
  $$WorkoutRoutinesTableTableManager(
      _$AppDatabase db, $WorkoutRoutinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$WorkoutRoutinesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$WorkoutRoutinesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> goal = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              WorkoutRoutinesCompanion(
            id: id,
            name: name,
            goal: goal,
            notes: notes,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String goal,
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              WorkoutRoutinesCompanion.insert(
            id: id,
            name: name,
            goal: goal,
            notes: notes,
            createdAt: createdAt,
          ),
        ));
}

class $$WorkoutRoutinesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $WorkoutRoutinesTable> {
  $$WorkoutRoutinesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get goal => $state.composableBuilder(
      column: $state.table.goal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter routineDaysRefs(
      ComposableFilter Function($$RoutineDaysTableFilterComposer f) f) {
    final $$RoutineDaysTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.routineDays,
        getReferencedColumn: (t) => t.routineId,
        builder: (joinBuilder, parentComposers) =>
            $$RoutineDaysTableFilterComposer(ComposerState($state.db,
                $state.db.routineDays, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter legacyRoutineProgramMappingsRefs(
      ComposableFilter Function(
              $$LegacyRoutineProgramMappingsTableFilterComposer f)
          f) {
    final $$LegacyRoutineProgramMappingsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.legacyRoutineProgramMappings,
            getReferencedColumn: (t) => t.legacyRoutineId,
            builder: (joinBuilder, parentComposers) =>
                $$LegacyRoutineProgramMappingsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.legacyRoutineProgramMappings,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$WorkoutRoutinesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $WorkoutRoutinesTable> {
  $$WorkoutRoutinesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get goal => $state.composableBuilder(
      column: $state.table.goal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$RoutineDaysTableCreateCompanionBuilder = RoutineDaysCompanion
    Function({
  Value<int> id,
  required int routineId,
  required int dayOfWeek,
  required String name,
  Value<bool> isRestDay,
});
typedef $$RoutineDaysTableUpdateCompanionBuilder = RoutineDaysCompanion
    Function({
  Value<int> id,
  Value<int> routineId,
  Value<int> dayOfWeek,
  Value<String> name,
  Value<bool> isRestDay,
});

class $$RoutineDaysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoutineDaysTable,
    RoutineDay,
    $$RoutineDaysTableFilterComposer,
    $$RoutineDaysTableOrderingComposer,
    $$RoutineDaysTableCreateCompanionBuilder,
    $$RoutineDaysTableUpdateCompanionBuilder> {
  $$RoutineDaysTableTableManager(_$AppDatabase db, $RoutineDaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$RoutineDaysTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$RoutineDaysTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> routineId = const Value.absent(),
            Value<int> dayOfWeek = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<bool> isRestDay = const Value.absent(),
          }) =>
              RoutineDaysCompanion(
            id: id,
            routineId: routineId,
            dayOfWeek: dayOfWeek,
            name: name,
            isRestDay: isRestDay,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int routineId,
            required int dayOfWeek,
            required String name,
            Value<bool> isRestDay = const Value.absent(),
          }) =>
              RoutineDaysCompanion.insert(
            id: id,
            routineId: routineId,
            dayOfWeek: dayOfWeek,
            name: name,
            isRestDay: isRestDay,
          ),
        ));
}

class $$RoutineDaysTableFilterComposer
    extends FilterComposer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get dayOfWeek => $state.composableBuilder(
      column: $state.table.dayOfWeek,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isRestDay => $state.composableBuilder(
      column: $state.table.isRestDay,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$WorkoutRoutinesTableFilterComposer get routineId {
    final $$WorkoutRoutinesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.routineId,
            referencedTable: $state.db.workoutRoutines,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutRoutinesTableFilterComposer(ComposerState($state.db,
                    $state.db.workoutRoutines, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter routineExercisesRefs(
      ComposableFilter Function($$RoutineExercisesTableFilterComposer f) f) {
    final $$RoutineExercisesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.routineExercises,
            getReferencedColumn: (t) => t.dayId,
            builder: (joinBuilder, parentComposers) =>
                $$RoutineExercisesTableFilterComposer(ComposerState($state.db,
                    $state.db.routineExercises, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$RoutineDaysTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get dayOfWeek => $state.composableBuilder(
      column: $state.table.dayOfWeek,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isRestDay => $state.composableBuilder(
      column: $state.table.isRestDay,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$WorkoutRoutinesTableOrderingComposer get routineId {
    final $$WorkoutRoutinesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.routineId,
            referencedTable: $state.db.workoutRoutines,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutRoutinesTableOrderingComposer(ComposerState($state.db,
                    $state.db.workoutRoutines, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$RoutineExercisesTableCreateCompanionBuilder
    = RoutineExercisesCompanion Function({
  Value<int> id,
  required int dayId,
  required String exerciseName,
  required int sets,
  required String repsRange,
  required int orderIndex,
});
typedef $$RoutineExercisesTableUpdateCompanionBuilder
    = RoutineExercisesCompanion Function({
  Value<int> id,
  Value<int> dayId,
  Value<String> exerciseName,
  Value<int> sets,
  Value<String> repsRange,
  Value<int> orderIndex,
});

class $$RoutineExercisesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoutineExercisesTable,
    RoutineExercise,
    $$RoutineExercisesTableFilterComposer,
    $$RoutineExercisesTableOrderingComposer,
    $$RoutineExercisesTableCreateCompanionBuilder,
    $$RoutineExercisesTableUpdateCompanionBuilder> {
  $$RoutineExercisesTableTableManager(
      _$AppDatabase db, $RoutineExercisesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$RoutineExercisesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$RoutineExercisesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> dayId = const Value.absent(),
            Value<String> exerciseName = const Value.absent(),
            Value<int> sets = const Value.absent(),
            Value<String> repsRange = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
          }) =>
              RoutineExercisesCompanion(
            id: id,
            dayId: dayId,
            exerciseName: exerciseName,
            sets: sets,
            repsRange: repsRange,
            orderIndex: orderIndex,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int dayId,
            required String exerciseName,
            required int sets,
            required String repsRange,
            required int orderIndex,
          }) =>
              RoutineExercisesCompanion.insert(
            id: id,
            dayId: dayId,
            exerciseName: exerciseName,
            sets: sets,
            repsRange: repsRange,
            orderIndex: orderIndex,
          ),
        ));
}

class $$RoutineExercisesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get exerciseName => $state.composableBuilder(
      column: $state.table.exerciseName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sets => $state.composableBuilder(
      column: $state.table.sets,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get repsRange => $state.composableBuilder(
      column: $state.table.repsRange,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get orderIndex => $state.composableBuilder(
      column: $state.table.orderIndex,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$RoutineDaysTableFilterComposer get dayId {
    final $$RoutineDaysTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dayId,
        referencedTable: $state.db.routineDays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$RoutineDaysTableFilterComposer(ComposerState($state.db,
                $state.db.routineDays, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$RoutineExercisesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get exerciseName => $state.composableBuilder(
      column: $state.table.exerciseName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sets => $state.composableBuilder(
      column: $state.table.sets,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get repsRange => $state.composableBuilder(
      column: $state.table.repsRange,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get orderIndex => $state.composableBuilder(
      column: $state.table.orderIndex,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$RoutineDaysTableOrderingComposer get dayId {
    final $$RoutineDaysTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dayId,
        referencedTable: $state.db.routineDays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$RoutineDaysTableOrderingComposer(ComposerState($state.db,
                $state.db.routineDays, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$WorkoutDraftsTableCreateCompanionBuilder = WorkoutDraftsCompanion
    Function({
  Value<int> id,
  required String routineName,
  required int currentExerciseIndex,
  required int currentSetIndex,
  required int elapsedSeconds,
  required String loggedSetsJson,
  Value<DateTime> updatedAt,
  Value<String?> scheduledOccurrenceId,
  Value<String?> executionSnapshotJson,
  Value<int> draftSchemaVersion,
});
typedef $$WorkoutDraftsTableUpdateCompanionBuilder = WorkoutDraftsCompanion
    Function({
  Value<int> id,
  Value<String> routineName,
  Value<int> currentExerciseIndex,
  Value<int> currentSetIndex,
  Value<int> elapsedSeconds,
  Value<String> loggedSetsJson,
  Value<DateTime> updatedAt,
  Value<String?> scheduledOccurrenceId,
  Value<String?> executionSnapshotJson,
  Value<int> draftSchemaVersion,
});

class $$WorkoutDraftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutDraftsTable,
    WorkoutDraft,
    $$WorkoutDraftsTableFilterComposer,
    $$WorkoutDraftsTableOrderingComposer,
    $$WorkoutDraftsTableCreateCompanionBuilder,
    $$WorkoutDraftsTableUpdateCompanionBuilder> {
  $$WorkoutDraftsTableTableManager(_$AppDatabase db, $WorkoutDraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$WorkoutDraftsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$WorkoutDraftsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> routineName = const Value.absent(),
            Value<int> currentExerciseIndex = const Value.absent(),
            Value<int> currentSetIndex = const Value.absent(),
            Value<int> elapsedSeconds = const Value.absent(),
            Value<String> loggedSetsJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> scheduledOccurrenceId = const Value.absent(),
            Value<String?> executionSnapshotJson = const Value.absent(),
            Value<int> draftSchemaVersion = const Value.absent(),
          }) =>
              WorkoutDraftsCompanion(
            id: id,
            routineName: routineName,
            currentExerciseIndex: currentExerciseIndex,
            currentSetIndex: currentSetIndex,
            elapsedSeconds: elapsedSeconds,
            loggedSetsJson: loggedSetsJson,
            updatedAt: updatedAt,
            scheduledOccurrenceId: scheduledOccurrenceId,
            executionSnapshotJson: executionSnapshotJson,
            draftSchemaVersion: draftSchemaVersion,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String routineName,
            required int currentExerciseIndex,
            required int currentSetIndex,
            required int elapsedSeconds,
            required String loggedSetsJson,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> scheduledOccurrenceId = const Value.absent(),
            Value<String?> executionSnapshotJson = const Value.absent(),
            Value<int> draftSchemaVersion = const Value.absent(),
          }) =>
              WorkoutDraftsCompanion.insert(
            id: id,
            routineName: routineName,
            currentExerciseIndex: currentExerciseIndex,
            currentSetIndex: currentSetIndex,
            elapsedSeconds: elapsedSeconds,
            loggedSetsJson: loggedSetsJson,
            updatedAt: updatedAt,
            scheduledOccurrenceId: scheduledOccurrenceId,
            executionSnapshotJson: executionSnapshotJson,
            draftSchemaVersion: draftSchemaVersion,
          ),
        ));
}

class $$WorkoutDraftsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $WorkoutDraftsTable> {
  $$WorkoutDraftsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get routineName => $state.composableBuilder(
      column: $state.table.routineName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get currentExerciseIndex => $state.composableBuilder(
      column: $state.table.currentExerciseIndex,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get currentSetIndex => $state.composableBuilder(
      column: $state.table.currentSetIndex,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get elapsedSeconds => $state.composableBuilder(
      column: $state.table.elapsedSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get loggedSetsJson => $state.composableBuilder(
      column: $state.table.loggedSetsJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get scheduledOccurrenceId => $state.composableBuilder(
      column: $state.table.scheduledOccurrenceId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get executionSnapshotJson => $state.composableBuilder(
      column: $state.table.executionSnapshotJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get draftSchemaVersion => $state.composableBuilder(
      column: $state.table.draftSchemaVersion,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$WorkoutDraftsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $WorkoutDraftsTable> {
  $$WorkoutDraftsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get routineName => $state.composableBuilder(
      column: $state.table.routineName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get currentExerciseIndex => $state.composableBuilder(
      column: $state.table.currentExerciseIndex,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get currentSetIndex => $state.composableBuilder(
      column: $state.table.currentSetIndex,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get elapsedSeconds => $state.composableBuilder(
      column: $state.table.elapsedSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get loggedSetsJson => $state.composableBuilder(
      column: $state.table.loggedSetsJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get scheduledOccurrenceId => $state.composableBuilder(
      column: $state.table.scheduledOccurrenceId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get executionSnapshotJson => $state.composableBuilder(
      column: $state.table.executionSnapshotJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get draftSchemaVersion => $state.composableBuilder(
      column: $state.table.draftSchemaVersion,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$UserProfilesTableCreateCompanionBuilder = UserProfilesCompanion
    Function({
  Value<int> id,
  Value<int> age,
  Value<double> height,
  Value<double> weight,
  Value<String> sex,
  Value<String> activityLevel,
  Value<String> goal,
  Value<String> dietPreference,
  Value<int> calorieGoal,
  Value<double> proteinGoal,
  Value<double> carbsGoal,
  Value<double> fatGoal,
  Value<String> name,
  Value<String> equipmentAccess,
  Value<String> injuriesLimitations,
  Value<DateTime> updatedAt,
});
typedef $$UserProfilesTableUpdateCompanionBuilder = UserProfilesCompanion
    Function({
  Value<int> id,
  Value<int> age,
  Value<double> height,
  Value<double> weight,
  Value<String> sex,
  Value<String> activityLevel,
  Value<String> goal,
  Value<String> dietPreference,
  Value<int> calorieGoal,
  Value<double> proteinGoal,
  Value<double> carbsGoal,
  Value<double> fatGoal,
  Value<String> name,
  Value<String> equipmentAccess,
  Value<String> injuriesLimitations,
  Value<DateTime> updatedAt,
});

class $$UserProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserProfilesTable,
    UserProfile,
    $$UserProfilesTableFilterComposer,
    $$UserProfilesTableOrderingComposer,
    $$UserProfilesTableCreateCompanionBuilder,
    $$UserProfilesTableUpdateCompanionBuilder> {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$UserProfilesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$UserProfilesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> age = const Value.absent(),
            Value<double> height = const Value.absent(),
            Value<double> weight = const Value.absent(),
            Value<String> sex = const Value.absent(),
            Value<String> activityLevel = const Value.absent(),
            Value<String> goal = const Value.absent(),
            Value<String> dietPreference = const Value.absent(),
            Value<int> calorieGoal = const Value.absent(),
            Value<double> proteinGoal = const Value.absent(),
            Value<double> carbsGoal = const Value.absent(),
            Value<double> fatGoal = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> equipmentAccess = const Value.absent(),
            Value<String> injuriesLimitations = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              UserProfilesCompanion(
            id: id,
            age: age,
            height: height,
            weight: weight,
            sex: sex,
            activityLevel: activityLevel,
            goal: goal,
            dietPreference: dietPreference,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatGoal: fatGoal,
            name: name,
            equipmentAccess: equipmentAccess,
            injuriesLimitations: injuriesLimitations,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> age = const Value.absent(),
            Value<double> height = const Value.absent(),
            Value<double> weight = const Value.absent(),
            Value<String> sex = const Value.absent(),
            Value<String> activityLevel = const Value.absent(),
            Value<String> goal = const Value.absent(),
            Value<String> dietPreference = const Value.absent(),
            Value<int> calorieGoal = const Value.absent(),
            Value<double> proteinGoal = const Value.absent(),
            Value<double> carbsGoal = const Value.absent(),
            Value<double> fatGoal = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> equipmentAccess = const Value.absent(),
            Value<String> injuriesLimitations = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              UserProfilesCompanion.insert(
            id: id,
            age: age,
            height: height,
            weight: weight,
            sex: sex,
            activityLevel: activityLevel,
            goal: goal,
            dietPreference: dietPreference,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatGoal: fatGoal,
            name: name,
            equipmentAccess: equipmentAccess,
            injuriesLimitations: injuriesLimitations,
            updatedAt: updatedAt,
          ),
        ));
}

class $$UserProfilesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get age => $state.composableBuilder(
      column: $state.table.age,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get sex => $state.composableBuilder(
      column: $state.table.sex,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get activityLevel => $state.composableBuilder(
      column: $state.table.activityLevel,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get goal => $state.composableBuilder(
      column: $state.table.goal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get dietPreference => $state.composableBuilder(
      column: $state.table.dietPreference,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get calorieGoal => $state.composableBuilder(
      column: $state.table.calorieGoal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get proteinGoal => $state.composableBuilder(
      column: $state.table.proteinGoal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get carbsGoal => $state.composableBuilder(
      column: $state.table.carbsGoal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get fatGoal => $state.composableBuilder(
      column: $state.table.fatGoal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get equipmentAccess => $state.composableBuilder(
      column: $state.table.equipmentAccess,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get injuriesLimitations => $state.composableBuilder(
      column: $state.table.injuriesLimitations,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$UserProfilesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get age => $state.composableBuilder(
      column: $state.table.age,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get sex => $state.composableBuilder(
      column: $state.table.sex,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get activityLevel => $state.composableBuilder(
      column: $state.table.activityLevel,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get goal => $state.composableBuilder(
      column: $state.table.goal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get dietPreference => $state.composableBuilder(
      column: $state.table.dietPreference,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get calorieGoal => $state.composableBuilder(
      column: $state.table.calorieGoal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get proteinGoal => $state.composableBuilder(
      column: $state.table.proteinGoal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get carbsGoal => $state.composableBuilder(
      column: $state.table.carbsGoal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get fatGoal => $state.composableBuilder(
      column: $state.table.fatGoal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get equipmentAccess => $state.composableBuilder(
      column: $state.table.equipmentAccess,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get injuriesLimitations => $state.composableBuilder(
      column: $state.table.injuriesLimitations,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$MealTemplatesTableCreateCompanionBuilder = MealTemplatesCompanion
    Function({
  Value<int> id,
  required String name,
  Value<String> defaultMealType,
  Value<DateTime> createdAt,
});
typedef $$MealTemplatesTableUpdateCompanionBuilder = MealTemplatesCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String> defaultMealType,
  Value<DateTime> createdAt,
});

class $$MealTemplatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MealTemplatesTable,
    MealTemplate,
    $$MealTemplatesTableFilterComposer,
    $$MealTemplatesTableOrderingComposer,
    $$MealTemplatesTableCreateCompanionBuilder,
    $$MealTemplatesTableUpdateCompanionBuilder> {
  $$MealTemplatesTableTableManager(_$AppDatabase db, $MealTemplatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$MealTemplatesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$MealTemplatesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> defaultMealType = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MealTemplatesCompanion(
            id: id,
            name: name,
            defaultMealType: defaultMealType,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> defaultMealType = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MealTemplatesCompanion.insert(
            id: id,
            name: name,
            defaultMealType: defaultMealType,
            createdAt: createdAt,
          ),
        ));
}

class $$MealTemplatesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $MealTemplatesTable> {
  $$MealTemplatesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get defaultMealType => $state.composableBuilder(
      column: $state.table.defaultMealType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter mealTemplateItemsRefs(
      ComposableFilter Function($$MealTemplateItemsTableFilterComposer f) f) {
    final $$MealTemplateItemsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.mealTemplateItems,
            getReferencedColumn: (t) => t.templateId,
            builder: (joinBuilder, parentComposers) =>
                $$MealTemplateItemsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.mealTemplateItems,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$MealTemplatesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $MealTemplatesTable> {
  $$MealTemplatesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get defaultMealType => $state.composableBuilder(
      column: $state.table.defaultMealType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$MealTemplateItemsTableCreateCompanionBuilder
    = MealTemplateItemsCompanion Function({
  Value<int> id,
  required int templateId,
  required String name,
  required int calories,
  required double proteinG,
  required double carbsG,
  required double fatG,
  required double servingLogged,
  required String servingUnit,
});
typedef $$MealTemplateItemsTableUpdateCompanionBuilder
    = MealTemplateItemsCompanion Function({
  Value<int> id,
  Value<int> templateId,
  Value<String> name,
  Value<int> calories,
  Value<double> proteinG,
  Value<double> carbsG,
  Value<double> fatG,
  Value<double> servingLogged,
  Value<String> servingUnit,
});

class $$MealTemplateItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MealTemplateItemsTable,
    MealTemplateItem,
    $$MealTemplateItemsTableFilterComposer,
    $$MealTemplateItemsTableOrderingComposer,
    $$MealTemplateItemsTableCreateCompanionBuilder,
    $$MealTemplateItemsTableUpdateCompanionBuilder> {
  $$MealTemplateItemsTableTableManager(
      _$AppDatabase db, $MealTemplateItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$MealTemplateItemsTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$MealTemplateItemsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> templateId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> calories = const Value.absent(),
            Value<double> proteinG = const Value.absent(),
            Value<double> carbsG = const Value.absent(),
            Value<double> fatG = const Value.absent(),
            Value<double> servingLogged = const Value.absent(),
            Value<String> servingUnit = const Value.absent(),
          }) =>
              MealTemplateItemsCompanion(
            id: id,
            templateId: templateId,
            name: name,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            servingLogged: servingLogged,
            servingUnit: servingUnit,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int templateId,
            required String name,
            required int calories,
            required double proteinG,
            required double carbsG,
            required double fatG,
            required double servingLogged,
            required String servingUnit,
          }) =>
              MealTemplateItemsCompanion.insert(
            id: id,
            templateId: templateId,
            name: name,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            servingLogged: servingLogged,
            servingUnit: servingUnit,
          ),
        ));
}

class $$MealTemplateItemsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $MealTemplateItemsTable> {
  $$MealTemplateItemsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get calories => $state.composableBuilder(
      column: $state.table.calories,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get proteinG => $state.composableBuilder(
      column: $state.table.proteinG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get carbsG => $state.composableBuilder(
      column: $state.table.carbsG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get fatG => $state.composableBuilder(
      column: $state.table.fatG,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get servingLogged => $state.composableBuilder(
      column: $state.table.servingLogged,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get servingUnit => $state.composableBuilder(
      column: $state.table.servingUnit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$MealTemplatesTableFilterComposer get templateId {
    final $$MealTemplatesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.templateId,
        referencedTable: $state.db.mealTemplates,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$MealTemplatesTableFilterComposer(ComposerState($state.db,
                $state.db.mealTemplates, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$MealTemplateItemsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $MealTemplateItemsTable> {
  $$MealTemplateItemsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get calories => $state.composableBuilder(
      column: $state.table.calories,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get proteinG => $state.composableBuilder(
      column: $state.table.proteinG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get carbsG => $state.composableBuilder(
      column: $state.table.carbsG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get fatG => $state.composableBuilder(
      column: $state.table.fatG,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get servingLogged => $state.composableBuilder(
      column: $state.table.servingLogged,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get servingUnit => $state.composableBuilder(
      column: $state.table.servingUnit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$MealTemplatesTableOrderingComposer get templateId {
    final $$MealTemplatesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.templateId,
            referencedTable: $state.db.mealTemplates,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$MealTemplatesTableOrderingComposer(ComposerState($state.db,
                    $state.db.mealTemplates, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$UserSettingsTableCreateCompanionBuilder = UserSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$UserSettingsTableUpdateCompanionBuilder = UserSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$UserSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserSettingsTable,
    UserSetting,
    $$UserSettingsTableFilterComposer,
    $$UserSettingsTableOrderingComposer,
    $$UserSettingsTableCreateCompanionBuilder,
    $$UserSettingsTableUpdateCompanionBuilder> {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$UserSettingsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$UserSettingsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSettingsCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$UserSettingsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer(super.$state);
  ColumnFilters<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$UserSettingsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$DailyHydrationsTableCreateCompanionBuilder = DailyHydrationsCompanion
    Function({
  Value<int> id,
  required String dateString,
  required int totalMl,
  required int goalMl,
  Value<DateTime> updatedAt,
});
typedef $$DailyHydrationsTableUpdateCompanionBuilder = DailyHydrationsCompanion
    Function({
  Value<int> id,
  Value<String> dateString,
  Value<int> totalMl,
  Value<int> goalMl,
  Value<DateTime> updatedAt,
});

class $$DailyHydrationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailyHydrationsTable,
    DailyHydration,
    $$DailyHydrationsTableFilterComposer,
    $$DailyHydrationsTableOrderingComposer,
    $$DailyHydrationsTableCreateCompanionBuilder,
    $$DailyHydrationsTableUpdateCompanionBuilder> {
  $$DailyHydrationsTableTableManager(
      _$AppDatabase db, $DailyHydrationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$DailyHydrationsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$DailyHydrationsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> dateString = const Value.absent(),
            Value<int> totalMl = const Value.absent(),
            Value<int> goalMl = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              DailyHydrationsCompanion(
            id: id,
            dateString: dateString,
            totalMl: totalMl,
            goalMl: goalMl,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String dateString,
            required int totalMl,
            required int goalMl,
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              DailyHydrationsCompanion.insert(
            id: id,
            dateString: dateString,
            totalMl: totalMl,
            goalMl: goalMl,
            updatedAt: updatedAt,
          ),
        ));
}

class $$DailyHydrationsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $DailyHydrationsTable> {
  $$DailyHydrationsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get dateString => $state.composableBuilder(
      column: $state.table.dateString,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get totalMl => $state.composableBuilder(
      column: $state.table.totalMl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get goalMl => $state.composableBuilder(
      column: $state.table.goalMl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$DailyHydrationsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $DailyHydrationsTable> {
  $$DailyHydrationsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get dateString => $state.composableBuilder(
      column: $state.table.dateString,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get totalMl => $state.composableBuilder(
      column: $state.table.totalMl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get goalMl => $state.composableBuilder(
      column: $state.table.goalMl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$HealthProvenancesTableCreateCompanionBuilder
    = HealthProvenancesCompanion Function({
  Value<int> id,
  required String provider,
  Value<String?> externalId,
  required String sourceName,
  Value<DateTime> importedAt,
  Value<int?> localSessionId,
  required String fingerprint,
});
typedef $$HealthProvenancesTableUpdateCompanionBuilder
    = HealthProvenancesCompanion Function({
  Value<int> id,
  Value<String> provider,
  Value<String?> externalId,
  Value<String> sourceName,
  Value<DateTime> importedAt,
  Value<int?> localSessionId,
  Value<String> fingerprint,
});

class $$HealthProvenancesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HealthProvenancesTable,
    HealthProvenance,
    $$HealthProvenancesTableFilterComposer,
    $$HealthProvenancesTableOrderingComposer,
    $$HealthProvenancesTableCreateCompanionBuilder,
    $$HealthProvenancesTableUpdateCompanionBuilder> {
  $$HealthProvenancesTableTableManager(
      _$AppDatabase db, $HealthProvenancesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$HealthProvenancesTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$HealthProvenancesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String?> externalId = const Value.absent(),
            Value<String> sourceName = const Value.absent(),
            Value<DateTime> importedAt = const Value.absent(),
            Value<int?> localSessionId = const Value.absent(),
            Value<String> fingerprint = const Value.absent(),
          }) =>
              HealthProvenancesCompanion(
            id: id,
            provider: provider,
            externalId: externalId,
            sourceName: sourceName,
            importedAt: importedAt,
            localSessionId: localSessionId,
            fingerprint: fingerprint,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String provider,
            Value<String?> externalId = const Value.absent(),
            required String sourceName,
            Value<DateTime> importedAt = const Value.absent(),
            Value<int?> localSessionId = const Value.absent(),
            required String fingerprint,
          }) =>
              HealthProvenancesCompanion.insert(
            id: id,
            provider: provider,
            externalId: externalId,
            sourceName: sourceName,
            importedAt: importedAt,
            localSessionId: localSessionId,
            fingerprint: fingerprint,
          ),
        ));
}

class $$HealthProvenancesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $HealthProvenancesTable> {
  $$HealthProvenancesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get provider => $state.composableBuilder(
      column: $state.table.provider,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get externalId => $state.composableBuilder(
      column: $state.table.externalId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get sourceName => $state.composableBuilder(
      column: $state.table.sourceName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get importedAt => $state.composableBuilder(
      column: $state.table.importedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fingerprint => $state.composableBuilder(
      column: $state.table.fingerprint,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$WorkoutSessionsTableFilterComposer get localSessionId {
    final $$WorkoutSessionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.localSessionId,
            referencedTable: $state.db.workoutSessions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutSessionsTableFilterComposer(ComposerState($state.db,
                    $state.db.workoutSessions, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$HealthProvenancesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $HealthProvenancesTable> {
  $$HealthProvenancesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get provider => $state.composableBuilder(
      column: $state.table.provider,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get externalId => $state.composableBuilder(
      column: $state.table.externalId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get sourceName => $state.composableBuilder(
      column: $state.table.sourceName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get importedAt => $state.composableBuilder(
      column: $state.table.importedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fingerprint => $state.composableBuilder(
      column: $state.table.fingerprint,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$WorkoutSessionsTableOrderingComposer get localSessionId {
    final $$WorkoutSessionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.localSessionId,
            referencedTable: $state.db.workoutSessions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutSessionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.workoutSessions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$AchievementUnlocksTableCreateCompanionBuilder
    = AchievementUnlocksCompanion Function({
  Value<int> id,
  required String achievementId,
  Value<DateTime> unlockedAt,
});
typedef $$AchievementUnlocksTableUpdateCompanionBuilder
    = AchievementUnlocksCompanion Function({
  Value<int> id,
  Value<String> achievementId,
  Value<DateTime> unlockedAt,
});

class $$AchievementUnlocksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AchievementUnlocksTable,
    AchievementUnlock,
    $$AchievementUnlocksTableFilterComposer,
    $$AchievementUnlocksTableOrderingComposer,
    $$AchievementUnlocksTableCreateCompanionBuilder,
    $$AchievementUnlocksTableUpdateCompanionBuilder> {
  $$AchievementUnlocksTableTableManager(
      _$AppDatabase db, $AchievementUnlocksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AchievementUnlocksTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$AchievementUnlocksTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> achievementId = const Value.absent(),
            Value<DateTime> unlockedAt = const Value.absent(),
          }) =>
              AchievementUnlocksCompanion(
            id: id,
            achievementId: achievementId,
            unlockedAt: unlockedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String achievementId,
            Value<DateTime> unlockedAt = const Value.absent(),
          }) =>
              AchievementUnlocksCompanion.insert(
            id: id,
            achievementId: achievementId,
            unlockedAt: unlockedAt,
          ),
        ));
}

class $$AchievementUnlocksTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AchievementUnlocksTable> {
  $$AchievementUnlocksTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get achievementId => $state.composableBuilder(
      column: $state.table.achievementId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get unlockedAt => $state.composableBuilder(
      column: $state.table.unlockedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$AchievementUnlocksTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AchievementUnlocksTable> {
  $$AchievementUnlocksTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get achievementId => $state.composableBuilder(
      column: $state.table.achievementId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get unlockedAt => $state.composableBuilder(
      column: $state.table.unlockedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ProgramsTableCreateCompanionBuilder = ProgramsCompanion Function({
  required String id,
  required String name,
  Value<String?> goal,
  Value<String?> notes,
  required DateTime createdAtUtc,
  Value<DateTime?> archivedAtUtc,
  Value<int> rowid,
});
typedef $$ProgramsTableUpdateCompanionBuilder = ProgramsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> goal,
  Value<String?> notes,
  Value<DateTime> createdAtUtc,
  Value<DateTime?> archivedAtUtc,
  Value<int> rowid,
});

class $$ProgramsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProgramsTable,
    Program,
    $$ProgramsTableFilterComposer,
    $$ProgramsTableOrderingComposer,
    $$ProgramsTableCreateCompanionBuilder,
    $$ProgramsTableUpdateCompanionBuilder> {
  $$ProgramsTableTableManager(_$AppDatabase db, $ProgramsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProgramsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProgramsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> goal = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<DateTime?> archivedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramsCompanion(
            id: id,
            name: name,
            goal: goal,
            notes: notes,
            createdAtUtc: createdAtUtc,
            archivedAtUtc: archivedAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> goal = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required DateTime createdAtUtc,
            Value<DateTime?> archivedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramsCompanion.insert(
            id: id,
            name: name,
            goal: goal,
            notes: notes,
            createdAtUtc: createdAtUtc,
            archivedAtUtc: archivedAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$ProgramsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProgramsTable> {
  $$ProgramsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get goal => $state.composableBuilder(
      column: $state.table.goal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get archivedAtUtc => $state.composableBuilder(
      column: $state.table.archivedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter programVersionsRefs(
      ComposableFilter Function($$ProgramVersionsTableFilterComposer f) f) {
    final $$ProgramVersionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.programId,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableFilterComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter legacyRoutineProgramMappingsRefs(
      ComposableFilter Function(
              $$LegacyRoutineProgramMappingsTableFilterComposer f)
          f) {
    final $$LegacyRoutineProgramMappingsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.legacyRoutineProgramMappings,
            getReferencedColumn: (t) => t.programId,
            builder: (joinBuilder, parentComposers) =>
                $$LegacyRoutineProgramMappingsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.legacyRoutineProgramMappings,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ProgramsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProgramsTable> {
  $$ProgramsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get goal => $state.composableBuilder(
      column: $state.table.goal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get archivedAtUtc => $state.composableBuilder(
      column: $state.table.archivedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ProgramVersionsTableCreateCompanionBuilder = ProgramVersionsCompanion
    Function({
  required String id,
  required String programId,
  required int versionNumber,
  required String status,
  Value<String> origin,
  Value<String?> sourceVersionId,
  required DateTime createdAtUtc,
  Value<DateTime?> publishedAtUtc,
  Value<DateTime?> archivedAtUtc,
  Value<int> rowid,
});
typedef $$ProgramVersionsTableUpdateCompanionBuilder = ProgramVersionsCompanion
    Function({
  Value<String> id,
  Value<String> programId,
  Value<int> versionNumber,
  Value<String> status,
  Value<String> origin,
  Value<String?> sourceVersionId,
  Value<DateTime> createdAtUtc,
  Value<DateTime?> publishedAtUtc,
  Value<DateTime?> archivedAtUtc,
  Value<int> rowid,
});

class $$ProgramVersionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProgramVersionsTable,
    ProgramVersion,
    $$ProgramVersionsTableFilterComposer,
    $$ProgramVersionsTableOrderingComposer,
    $$ProgramVersionsTableCreateCompanionBuilder,
    $$ProgramVersionsTableUpdateCompanionBuilder> {
  $$ProgramVersionsTableTableManager(
      _$AppDatabase db, $ProgramVersionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProgramVersionsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProgramVersionsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> programId = const Value.absent(),
            Value<int> versionNumber = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> origin = const Value.absent(),
            Value<String?> sourceVersionId = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<DateTime?> publishedAtUtc = const Value.absent(),
            Value<DateTime?> archivedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramVersionsCompanion(
            id: id,
            programId: programId,
            versionNumber: versionNumber,
            status: status,
            origin: origin,
            sourceVersionId: sourceVersionId,
            createdAtUtc: createdAtUtc,
            publishedAtUtc: publishedAtUtc,
            archivedAtUtc: archivedAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String programId,
            required int versionNumber,
            required String status,
            Value<String> origin = const Value.absent(),
            Value<String?> sourceVersionId = const Value.absent(),
            required DateTime createdAtUtc,
            Value<DateTime?> publishedAtUtc = const Value.absent(),
            Value<DateTime?> archivedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramVersionsCompanion.insert(
            id: id,
            programId: programId,
            versionNumber: versionNumber,
            status: status,
            origin: origin,
            sourceVersionId: sourceVersionId,
            createdAtUtc: createdAtUtc,
            publishedAtUtc: publishedAtUtc,
            archivedAtUtc: archivedAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$ProgramVersionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProgramVersionsTable> {
  $$ProgramVersionsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get versionNumber => $state.composableBuilder(
      column: $state.table.versionNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get origin => $state.composableBuilder(
      column: $state.table.origin,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get publishedAtUtc => $state.composableBuilder(
      column: $state.table.publishedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get archivedAtUtc => $state.composableBuilder(
      column: $state.table.archivedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProgramsTableFilterComposer get programId {
    final $$ProgramsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.programId,
        referencedTable: $state.db.programs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramsTableFilterComposer(ComposerState(
                $state.db, $state.db.programs, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramVersionsTableFilterComposer get sourceVersionId {
    final $$ProgramVersionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sourceVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableFilterComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter programBlocksRefs(
      ComposableFilter Function($$ProgramBlocksTableFilterComposer f) f) {
    final $$ProgramBlocksTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.programBlocks,
        getReferencedColumn: (t) => t.programVersionId,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramBlocksTableFilterComposer(ComposerState($state.db,
                $state.db.programBlocks, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter programWeeksRefs(
      ComposableFilter Function($$ProgramWeeksTableFilterComposer f) f) {
    final $$ProgramWeeksTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.programWeeks,
        getReferencedColumn: (t) => t.programVersionId,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramWeeksTableFilterComposer(ComposerState($state.db,
                $state.db.programWeeks, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter scheduledSessionOccurrencesRefs(
      ComposableFilter Function(
              $$ScheduledSessionOccurrencesTableFilterComposer f)
          f) {
    final $$ScheduledSessionOccurrencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.programVersionId,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.scheduledSessionOccurrences,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter trainingPlanSettingsRefs(
      ComposableFilter Function($$TrainingPlanSettingsTableFilterComposer f)
          f) {
    final $$TrainingPlanSettingsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.trainingPlanSettings,
            getReferencedColumn: (t) => t.activeProgramVersionId,
            builder: (joinBuilder, parentComposers) =>
                $$TrainingPlanSettingsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.trainingPlanSettings,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter legacyRoutineProgramMappingsRefs(
      ComposableFilter Function(
              $$LegacyRoutineProgramMappingsTableFilterComposer f)
          f) {
    final $$LegacyRoutineProgramMappingsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.legacyRoutineProgramMappings,
            getReferencedColumn: (t) => t.programVersionId,
            builder: (joinBuilder, parentComposers) =>
                $$LegacyRoutineProgramMappingsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.legacyRoutineProgramMappings,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ProgramVersionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProgramVersionsTable> {
  $$ProgramVersionsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get versionNumber => $state.composableBuilder(
      column: $state.table.versionNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get origin => $state.composableBuilder(
      column: $state.table.origin,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get publishedAtUtc => $state.composableBuilder(
      column: $state.table.publishedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get archivedAtUtc => $state.composableBuilder(
      column: $state.table.archivedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProgramsTableOrderingComposer get programId {
    final $$ProgramsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.programId,
        referencedTable: $state.db.programs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramsTableOrderingComposer(ComposerState(
                $state.db, $state.db.programs, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramVersionsTableOrderingComposer get sourceVersionId {
    final $$ProgramVersionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sourceVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ProgramBlocksTableCreateCompanionBuilder = ProgramBlocksCompanion
    Function({
  required String id,
  required String programVersionId,
  required int ordinal,
  required String name,
  Value<String?> description,
  Value<int> rowid,
});
typedef $$ProgramBlocksTableUpdateCompanionBuilder = ProgramBlocksCompanion
    Function({
  Value<String> id,
  Value<String> programVersionId,
  Value<int> ordinal,
  Value<String> name,
  Value<String?> description,
  Value<int> rowid,
});

class $$ProgramBlocksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProgramBlocksTable,
    ProgramBlock,
    $$ProgramBlocksTableFilterComposer,
    $$ProgramBlocksTableOrderingComposer,
    $$ProgramBlocksTableCreateCompanionBuilder,
    $$ProgramBlocksTableUpdateCompanionBuilder> {
  $$ProgramBlocksTableTableManager(_$AppDatabase db, $ProgramBlocksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProgramBlocksTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProgramBlocksTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> programVersionId = const Value.absent(),
            Value<int> ordinal = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramBlocksCompanion(
            id: id,
            programVersionId: programVersionId,
            ordinal: ordinal,
            name: name,
            description: description,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String programVersionId,
            required int ordinal,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramBlocksCompanion.insert(
            id: id,
            programVersionId: programVersionId,
            ordinal: ordinal,
            name: name,
            description: description,
            rowid: rowid,
          ),
        ));
}

class $$ProgramBlocksTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProgramBlocksTable> {
  $$ProgramBlocksTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableFilterComposer get programVersionId {
    final $$ProgramVersionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableFilterComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter programWeeksRefs(
      ComposableFilter Function($$ProgramWeeksTableFilterComposer f) f) {
    final $$ProgramWeeksTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.programWeeks,
        getReferencedColumn: (t) => t.programBlockId,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramWeeksTableFilterComposer(ComposerState($state.db,
                $state.db.programWeeks, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$ProgramBlocksTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProgramBlocksTable> {
  $$ProgramBlocksTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableOrderingComposer get programVersionId {
    final $$ProgramVersionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ProgramWeeksTableCreateCompanionBuilder = ProgramWeeksCompanion
    Function({
  required String id,
  required String programVersionId,
  required String programBlockId,
  required int ordinalInBlock,
  required int programWeekOrdinal,
  Value<String?> name,
  Value<bool> isDeload,
  Value<int> rowid,
});
typedef $$ProgramWeeksTableUpdateCompanionBuilder = ProgramWeeksCompanion
    Function({
  Value<String> id,
  Value<String> programVersionId,
  Value<String> programBlockId,
  Value<int> ordinalInBlock,
  Value<int> programWeekOrdinal,
  Value<String?> name,
  Value<bool> isDeload,
  Value<int> rowid,
});

class $$ProgramWeeksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProgramWeeksTable,
    ProgramWeek,
    $$ProgramWeeksTableFilterComposer,
    $$ProgramWeeksTableOrderingComposer,
    $$ProgramWeeksTableCreateCompanionBuilder,
    $$ProgramWeeksTableUpdateCompanionBuilder> {
  $$ProgramWeeksTableTableManager(_$AppDatabase db, $ProgramWeeksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProgramWeeksTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProgramWeeksTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> programVersionId = const Value.absent(),
            Value<String> programBlockId = const Value.absent(),
            Value<int> ordinalInBlock = const Value.absent(),
            Value<int> programWeekOrdinal = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<bool> isDeload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramWeeksCompanion(
            id: id,
            programVersionId: programVersionId,
            programBlockId: programBlockId,
            ordinalInBlock: ordinalInBlock,
            programWeekOrdinal: programWeekOrdinal,
            name: name,
            isDeload: isDeload,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String programVersionId,
            required String programBlockId,
            required int ordinalInBlock,
            required int programWeekOrdinal,
            Value<String?> name = const Value.absent(),
            Value<bool> isDeload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramWeeksCompanion.insert(
            id: id,
            programVersionId: programVersionId,
            programBlockId: programBlockId,
            ordinalInBlock: ordinalInBlock,
            programWeekOrdinal: programWeekOrdinal,
            name: name,
            isDeload: isDeload,
            rowid: rowid,
          ),
        ));
}

class $$ProgramWeeksTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProgramWeeksTable> {
  $$ProgramWeeksTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get ordinalInBlock => $state.composableBuilder(
      column: $state.table.ordinalInBlock,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get programWeekOrdinal => $state.composableBuilder(
      column: $state.table.programWeekOrdinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isDeload => $state.composableBuilder(
      column: $state.table.isDeload,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableFilterComposer get programVersionId {
    final $$ProgramVersionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableFilterComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramBlocksTableFilterComposer get programBlockId {
    final $$ProgramBlocksTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.programBlockId,
        referencedTable: $state.db.programBlocks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramBlocksTableFilterComposer(ComposerState($state.db,
                $state.db.programBlocks, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter sessionTemplatesRefs(
      ComposableFilter Function($$SessionTemplatesTableFilterComposer f) f) {
    final $$SessionTemplatesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.sessionTemplates,
            getReferencedColumn: (t) => t.programWeekId,
            builder: (joinBuilder, parentComposers) =>
                $$SessionTemplatesTableFilterComposer(ComposerState($state.db,
                    $state.db.sessionTemplates, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$ProgramWeeksTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProgramWeeksTable> {
  $$ProgramWeeksTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get ordinalInBlock => $state.composableBuilder(
      column: $state.table.ordinalInBlock,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get programWeekOrdinal => $state.composableBuilder(
      column: $state.table.programWeekOrdinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isDeload => $state.composableBuilder(
      column: $state.table.isDeload,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableOrderingComposer get programVersionId {
    final $$ProgramVersionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramBlocksTableOrderingComposer get programBlockId {
    final $$ProgramBlocksTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programBlockId,
            referencedTable: $state.db.programBlocks,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramBlocksTableOrderingComposer(ComposerState($state.db,
                    $state.db.programBlocks, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$SessionTemplatesTableCreateCompanionBuilder
    = SessionTemplatesCompanion Function({
  required String id,
  required String programWeekId,
  required int ordinal,
  required String name,
  required int plannedWeekday,
  Value<int?> plannedStartMinute,
  Value<String?> notes,
  Value<int> rowid,
});
typedef $$SessionTemplatesTableUpdateCompanionBuilder
    = SessionTemplatesCompanion Function({
  Value<String> id,
  Value<String> programWeekId,
  Value<int> ordinal,
  Value<String> name,
  Value<int> plannedWeekday,
  Value<int?> plannedStartMinute,
  Value<String?> notes,
  Value<int> rowid,
});

class $$SessionTemplatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionTemplatesTable,
    SessionTemplate,
    $$SessionTemplatesTableFilterComposer,
    $$SessionTemplatesTableOrderingComposer,
    $$SessionTemplatesTableCreateCompanionBuilder,
    $$SessionTemplatesTableUpdateCompanionBuilder> {
  $$SessionTemplatesTableTableManager(
      _$AppDatabase db, $SessionTemplatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SessionTemplatesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SessionTemplatesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> programWeekId = const Value.absent(),
            Value<int> ordinal = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> plannedWeekday = const Value.absent(),
            Value<int?> plannedStartMinute = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionTemplatesCompanion(
            id: id,
            programWeekId: programWeekId,
            ordinal: ordinal,
            name: name,
            plannedWeekday: plannedWeekday,
            plannedStartMinute: plannedStartMinute,
            notes: notes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String programWeekId,
            required int ordinal,
            required String name,
            required int plannedWeekday,
            Value<int?> plannedStartMinute = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionTemplatesCompanion.insert(
            id: id,
            programWeekId: programWeekId,
            ordinal: ordinal,
            name: name,
            plannedWeekday: plannedWeekday,
            plannedStartMinute: plannedStartMinute,
            notes: notes,
            rowid: rowid,
          ),
        ));
}

class $$SessionTemplatesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SessionTemplatesTable> {
  $$SessionTemplatesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get plannedWeekday => $state.composableBuilder(
      column: $state.table.plannedWeekday,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get plannedStartMinute => $state.composableBuilder(
      column: $state.table.plannedStartMinute,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProgramWeeksTableFilterComposer get programWeekId {
    final $$ProgramWeeksTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.programWeekId,
        referencedTable: $state.db.programWeeks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramWeeksTableFilterComposer(ComposerState($state.db,
                $state.db.programWeeks, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter exercisePrescriptionsRefs(
      ComposableFilter Function($$ExercisePrescriptionsTableFilterComposer f)
          f) {
    final $$ExercisePrescriptionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.exercisePrescriptions,
            getReferencedColumn: (t) => t.sessionTemplateId,
            builder: (joinBuilder, parentComposers) =>
                $$ExercisePrescriptionsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.exercisePrescriptions,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter scheduledSessionOccurrencesRefs(
      ComposableFilter Function(
              $$ScheduledSessionOccurrencesTableFilterComposer f)
          f) {
    final $$ScheduledSessionOccurrencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.sessionTemplateId,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.scheduledSessionOccurrences,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$SessionTemplatesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SessionTemplatesTable> {
  $$SessionTemplatesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get plannedWeekday => $state.composableBuilder(
      column: $state.table.plannedWeekday,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get plannedStartMinute => $state.composableBuilder(
      column: $state.table.plannedStartMinute,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProgramWeeksTableOrderingComposer get programWeekId {
    final $$ProgramWeeksTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.programWeekId,
        referencedTable: $state.db.programWeeks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramWeeksTableOrderingComposer(ComposerState($state.db,
                $state.db.programWeeks, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ExercisePrescriptionsTableCreateCompanionBuilder
    = ExercisePrescriptionsCompanion Function({
  required String id,
  required String sessionTemplateId,
  required int ordinal,
  Value<String?> exerciseId,
  required String exerciseNameSnapshot,
  required int plannedSets,
  required String repsRange,
  Value<int> rowid,
});
typedef $$ExercisePrescriptionsTableUpdateCompanionBuilder
    = ExercisePrescriptionsCompanion Function({
  Value<String> id,
  Value<String> sessionTemplateId,
  Value<int> ordinal,
  Value<String?> exerciseId,
  Value<String> exerciseNameSnapshot,
  Value<int> plannedSets,
  Value<String> repsRange,
  Value<int> rowid,
});

class $$ExercisePrescriptionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExercisePrescriptionsTable,
    ExercisePrescription,
    $$ExercisePrescriptionsTableFilterComposer,
    $$ExercisePrescriptionsTableOrderingComposer,
    $$ExercisePrescriptionsTableCreateCompanionBuilder,
    $$ExercisePrescriptionsTableUpdateCompanionBuilder> {
  $$ExercisePrescriptionsTableTableManager(
      _$AppDatabase db, $ExercisePrescriptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ExercisePrescriptionsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ExercisePrescriptionsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionTemplateId = const Value.absent(),
            Value<int> ordinal = const Value.absent(),
            Value<String?> exerciseId = const Value.absent(),
            Value<String> exerciseNameSnapshot = const Value.absent(),
            Value<int> plannedSets = const Value.absent(),
            Value<String> repsRange = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExercisePrescriptionsCompanion(
            id: id,
            sessionTemplateId: sessionTemplateId,
            ordinal: ordinal,
            exerciseId: exerciseId,
            exerciseNameSnapshot: exerciseNameSnapshot,
            plannedSets: plannedSets,
            repsRange: repsRange,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionTemplateId,
            required int ordinal,
            Value<String?> exerciseId = const Value.absent(),
            required String exerciseNameSnapshot,
            required int plannedSets,
            required String repsRange,
            Value<int> rowid = const Value.absent(),
          }) =>
              ExercisePrescriptionsCompanion.insert(
            id: id,
            sessionTemplateId: sessionTemplateId,
            ordinal: ordinal,
            exerciseId: exerciseId,
            exerciseNameSnapshot: exerciseNameSnapshot,
            plannedSets: plannedSets,
            repsRange: repsRange,
            rowid: rowid,
          ),
        ));
}

class $$ExercisePrescriptionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ExercisePrescriptionsTable> {
  $$ExercisePrescriptionsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get exerciseNameSnapshot => $state.composableBuilder(
      column: $state.table.exerciseNameSnapshot,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get plannedSets => $state.composableBuilder(
      column: $state.table.plannedSets,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get repsRange => $state.composableBuilder(
      column: $state.table.repsRange,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$SessionTemplatesTableFilterComposer get sessionTemplateId {
    final $$SessionTemplatesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sessionTemplateId,
            referencedTable: $state.db.sessionTemplates,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$SessionTemplatesTableFilterComposer(ComposerState($state.db,
                    $state.db.sessionTemplates, joinBuilder, parentComposers)));
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $state.db.exercises,
        getReferencedColumn: (t) => t.stableId,
        builder: (joinBuilder, parentComposers) =>
            $$ExercisesTableFilterComposer(ComposerState(
                $state.db, $state.db.exercises, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ExercisePrescriptionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ExercisePrescriptionsTable> {
  $$ExercisePrescriptionsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get exerciseNameSnapshot => $state.composableBuilder(
      column: $state.table.exerciseNameSnapshot,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get plannedSets => $state.composableBuilder(
      column: $state.table.plannedSets,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get repsRange => $state.composableBuilder(
      column: $state.table.repsRange,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$SessionTemplatesTableOrderingComposer get sessionTemplateId {
    final $$SessionTemplatesTableOrderingComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sessionTemplateId,
            referencedTable: $state.db.sessionTemplates,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$SessionTemplatesTableOrderingComposer(ComposerState($state.db,
                    $state.db.sessionTemplates, joinBuilder, parentComposers)));
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $state.db.exercises,
        getReferencedColumn: (t) => t.stableId,
        builder: (joinBuilder, parentComposers) =>
            $$ExercisesTableOrderingComposer(ComposerState(
                $state.db, $state.db.exercises, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ScheduledSessionOccurrencesTableCreateCompanionBuilder
    = ScheduledSessionOccurrencesCompanion Function({
  required String id,
  required String programVersionId,
  required String sessionTemplateId,
  required int programBlockOrdinal,
  required int programWeekOrdinal,
  required int sessionOrdinal,
  Value<int> repeatOrdinal,
  required String originalLocalDate,
  required String originalTimezoneId,
  required String effectiveLocalDate,
  required String effectiveTimezoneId,
  Value<String> status,
  Value<String> progressionDisposition,
  Value<String?> skipMode,
  Value<String?> repeatPurpose,
  Value<String?> repeatedFromOccurrenceId,
  Value<String?> executionSnapshotJson,
  Value<DateTime?> startedAtUtc,
  Value<DateTime?> terminalAtUtc,
  required DateTime createdAtUtc,
  Value<int> rowid,
});
typedef $$ScheduledSessionOccurrencesTableUpdateCompanionBuilder
    = ScheduledSessionOccurrencesCompanion Function({
  Value<String> id,
  Value<String> programVersionId,
  Value<String> sessionTemplateId,
  Value<int> programBlockOrdinal,
  Value<int> programWeekOrdinal,
  Value<int> sessionOrdinal,
  Value<int> repeatOrdinal,
  Value<String> originalLocalDate,
  Value<String> originalTimezoneId,
  Value<String> effectiveLocalDate,
  Value<String> effectiveTimezoneId,
  Value<String> status,
  Value<String> progressionDisposition,
  Value<String?> skipMode,
  Value<String?> repeatPurpose,
  Value<String?> repeatedFromOccurrenceId,
  Value<String?> executionSnapshotJson,
  Value<DateTime?> startedAtUtc,
  Value<DateTime?> terminalAtUtc,
  Value<DateTime> createdAtUtc,
  Value<int> rowid,
});

class $$ScheduledSessionOccurrencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScheduledSessionOccurrencesTable,
    ScheduledSessionOccurrence,
    $$ScheduledSessionOccurrencesTableFilterComposer,
    $$ScheduledSessionOccurrencesTableOrderingComposer,
    $$ScheduledSessionOccurrencesTableCreateCompanionBuilder,
    $$ScheduledSessionOccurrencesTableUpdateCompanionBuilder> {
  $$ScheduledSessionOccurrencesTableTableManager(
      _$AppDatabase db, $ScheduledSessionOccurrencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ScheduledSessionOccurrencesTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ScheduledSessionOccurrencesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> programVersionId = const Value.absent(),
            Value<String> sessionTemplateId = const Value.absent(),
            Value<int> programBlockOrdinal = const Value.absent(),
            Value<int> programWeekOrdinal = const Value.absent(),
            Value<int> sessionOrdinal = const Value.absent(),
            Value<int> repeatOrdinal = const Value.absent(),
            Value<String> originalLocalDate = const Value.absent(),
            Value<String> originalTimezoneId = const Value.absent(),
            Value<String> effectiveLocalDate = const Value.absent(),
            Value<String> effectiveTimezoneId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> progressionDisposition = const Value.absent(),
            Value<String?> skipMode = const Value.absent(),
            Value<String?> repeatPurpose = const Value.absent(),
            Value<String?> repeatedFromOccurrenceId = const Value.absent(),
            Value<String?> executionSnapshotJson = const Value.absent(),
            Value<DateTime?> startedAtUtc = const Value.absent(),
            Value<DateTime?> terminalAtUtc = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ScheduledSessionOccurrencesCompanion(
            id: id,
            programVersionId: programVersionId,
            sessionTemplateId: sessionTemplateId,
            programBlockOrdinal: programBlockOrdinal,
            programWeekOrdinal: programWeekOrdinal,
            sessionOrdinal: sessionOrdinal,
            repeatOrdinal: repeatOrdinal,
            originalLocalDate: originalLocalDate,
            originalTimezoneId: originalTimezoneId,
            effectiveLocalDate: effectiveLocalDate,
            effectiveTimezoneId: effectiveTimezoneId,
            status: status,
            progressionDisposition: progressionDisposition,
            skipMode: skipMode,
            repeatPurpose: repeatPurpose,
            repeatedFromOccurrenceId: repeatedFromOccurrenceId,
            executionSnapshotJson: executionSnapshotJson,
            startedAtUtc: startedAtUtc,
            terminalAtUtc: terminalAtUtc,
            createdAtUtc: createdAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String programVersionId,
            required String sessionTemplateId,
            required int programBlockOrdinal,
            required int programWeekOrdinal,
            required int sessionOrdinal,
            Value<int> repeatOrdinal = const Value.absent(),
            required String originalLocalDate,
            required String originalTimezoneId,
            required String effectiveLocalDate,
            required String effectiveTimezoneId,
            Value<String> status = const Value.absent(),
            Value<String> progressionDisposition = const Value.absent(),
            Value<String?> skipMode = const Value.absent(),
            Value<String?> repeatPurpose = const Value.absent(),
            Value<String?> repeatedFromOccurrenceId = const Value.absent(),
            Value<String?> executionSnapshotJson = const Value.absent(),
            Value<DateTime?> startedAtUtc = const Value.absent(),
            Value<DateTime?> terminalAtUtc = const Value.absent(),
            required DateTime createdAtUtc,
            Value<int> rowid = const Value.absent(),
          }) =>
              ScheduledSessionOccurrencesCompanion.insert(
            id: id,
            programVersionId: programVersionId,
            sessionTemplateId: sessionTemplateId,
            programBlockOrdinal: programBlockOrdinal,
            programWeekOrdinal: programWeekOrdinal,
            sessionOrdinal: sessionOrdinal,
            repeatOrdinal: repeatOrdinal,
            originalLocalDate: originalLocalDate,
            originalTimezoneId: originalTimezoneId,
            effectiveLocalDate: effectiveLocalDate,
            effectiveTimezoneId: effectiveTimezoneId,
            status: status,
            progressionDisposition: progressionDisposition,
            skipMode: skipMode,
            repeatPurpose: repeatPurpose,
            repeatedFromOccurrenceId: repeatedFromOccurrenceId,
            executionSnapshotJson: executionSnapshotJson,
            startedAtUtc: startedAtUtc,
            terminalAtUtc: terminalAtUtc,
            createdAtUtc: createdAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$ScheduledSessionOccurrencesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ScheduledSessionOccurrencesTable> {
  $$ScheduledSessionOccurrencesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get programBlockOrdinal => $state.composableBuilder(
      column: $state.table.programBlockOrdinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get programWeekOrdinal => $state.composableBuilder(
      column: $state.table.programWeekOrdinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sessionOrdinal => $state.composableBuilder(
      column: $state.table.sessionOrdinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get repeatOrdinal => $state.composableBuilder(
      column: $state.table.repeatOrdinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get originalLocalDate => $state.composableBuilder(
      column: $state.table.originalLocalDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get originalTimezoneId => $state.composableBuilder(
      column: $state.table.originalTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get effectiveLocalDate => $state.composableBuilder(
      column: $state.table.effectiveLocalDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get effectiveTimezoneId => $state.composableBuilder(
      column: $state.table.effectiveTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get progressionDisposition => $state.composableBuilder(
      column: $state.table.progressionDisposition,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get skipMode => $state.composableBuilder(
      column: $state.table.skipMode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get repeatPurpose => $state.composableBuilder(
      column: $state.table.repeatPurpose,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get executionSnapshotJson => $state.composableBuilder(
      column: $state.table.executionSnapshotJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get startedAtUtc => $state.composableBuilder(
      column: $state.table.startedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get terminalAtUtc => $state.composableBuilder(
      column: $state.table.terminalAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableFilterComposer get programVersionId {
    final $$ProgramVersionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableFilterComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionTemplatesTableFilterComposer get sessionTemplateId {
    final $$SessionTemplatesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sessionTemplateId,
            referencedTable: $state.db.sessionTemplates,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$SessionTemplatesTableFilterComposer(ComposerState($state.db,
                    $state.db.sessionTemplates, joinBuilder, parentComposers)));
    return composer;
  }

  $$ScheduledSessionOccurrencesTableFilterComposer
      get repeatedFromOccurrenceId {
    final $$ScheduledSessionOccurrencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.repeatedFromOccurrenceId,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.scheduledSessionOccurrences,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }

  ComposableFilter occurrenceEventsRefs(
      ComposableFilter Function($$OccurrenceEventsTableFilterComposer f) f) {
    final $$OccurrenceEventsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.occurrenceEvents,
            getReferencedColumn: (t) => t.occurrenceId,
            builder: (joinBuilder, parentComposers) =>
                $$OccurrenceEventsTableFilterComposer(ComposerState($state.db,
                    $state.db.occurrenceEvents, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter travelContextOccurrencesRefs(
      ComposableFilter Function($$TravelContextOccurrencesTableFilterComposer f)
          f) {
    final $$TravelContextOccurrencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.travelContextOccurrences,
            getReferencedColumn: (t) => t.occurrenceId,
            builder: (joinBuilder, parentComposers) =>
                $$TravelContextOccurrencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.travelContextOccurrences,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ScheduledSessionOccurrencesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ScheduledSessionOccurrencesTable> {
  $$ScheduledSessionOccurrencesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get programBlockOrdinal => $state.composableBuilder(
      column: $state.table.programBlockOrdinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get programWeekOrdinal => $state.composableBuilder(
      column: $state.table.programWeekOrdinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sessionOrdinal => $state.composableBuilder(
      column: $state.table.sessionOrdinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get repeatOrdinal => $state.composableBuilder(
      column: $state.table.repeatOrdinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get originalLocalDate => $state.composableBuilder(
      column: $state.table.originalLocalDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get originalTimezoneId => $state.composableBuilder(
      column: $state.table.originalTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get effectiveLocalDate => $state.composableBuilder(
      column: $state.table.effectiveLocalDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get effectiveTimezoneId => $state.composableBuilder(
      column: $state.table.effectiveTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get progressionDisposition =>
      $state.composableBuilder(
          column: $state.table.progressionDisposition,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get skipMode => $state.composableBuilder(
      column: $state.table.skipMode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get repeatPurpose => $state.composableBuilder(
      column: $state.table.repeatPurpose,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get executionSnapshotJson => $state.composableBuilder(
      column: $state.table.executionSnapshotJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get startedAtUtc => $state.composableBuilder(
      column: $state.table.startedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get terminalAtUtc => $state.composableBuilder(
      column: $state.table.terminalAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableOrderingComposer get programVersionId {
    final $$ProgramVersionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionTemplatesTableOrderingComposer get sessionTemplateId {
    final $$SessionTemplatesTableOrderingComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sessionTemplateId,
            referencedTable: $state.db.sessionTemplates,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$SessionTemplatesTableOrderingComposer(ComposerState($state.db,
                    $state.db.sessionTemplates, joinBuilder, parentComposers)));
    return composer;
  }

  $$ScheduledSessionOccurrencesTableOrderingComposer
      get repeatedFromOccurrenceId {
    final $$ScheduledSessionOccurrencesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.repeatedFromOccurrenceId,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableOrderingComposer(
                    ComposerState(
                        $state.db,
                        $state.db.scheduledSessionOccurrences,
                        joinBuilder,
                        parentComposers)));
    return composer;
  }
}

typedef $$OccurrenceEventsTableCreateCompanionBuilder
    = OccurrenceEventsCompanion Function({
  required String id,
  required String occurrenceId,
  required String commandId,
  required String eventType,
  Value<String?> fromStatus,
  Value<String?> toStatus,
  Value<String?> beforeLocalDate,
  Value<String?> beforeTimezoneId,
  Value<String?> afterLocalDate,
  Value<String?> afterTimezoneId,
  Value<String?> reason,
  Value<String?> metadataJson,
  required DateTime occurredAtUtc,
  Value<int> rowid,
});
typedef $$OccurrenceEventsTableUpdateCompanionBuilder
    = OccurrenceEventsCompanion Function({
  Value<String> id,
  Value<String> occurrenceId,
  Value<String> commandId,
  Value<String> eventType,
  Value<String?> fromStatus,
  Value<String?> toStatus,
  Value<String?> beforeLocalDate,
  Value<String?> beforeTimezoneId,
  Value<String?> afterLocalDate,
  Value<String?> afterTimezoneId,
  Value<String?> reason,
  Value<String?> metadataJson,
  Value<DateTime> occurredAtUtc,
  Value<int> rowid,
});

class $$OccurrenceEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OccurrenceEventsTable,
    OccurrenceEvent,
    $$OccurrenceEventsTableFilterComposer,
    $$OccurrenceEventsTableOrderingComposer,
    $$OccurrenceEventsTableCreateCompanionBuilder,
    $$OccurrenceEventsTableUpdateCompanionBuilder> {
  $$OccurrenceEventsTableTableManager(
      _$AppDatabase db, $OccurrenceEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$OccurrenceEventsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$OccurrenceEventsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> occurrenceId = const Value.absent(),
            Value<String> commandId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String?> fromStatus = const Value.absent(),
            Value<String?> toStatus = const Value.absent(),
            Value<String?> beforeLocalDate = const Value.absent(),
            Value<String?> beforeTimezoneId = const Value.absent(),
            Value<String?> afterLocalDate = const Value.absent(),
            Value<String?> afterTimezoneId = const Value.absent(),
            Value<String?> reason = const Value.absent(),
            Value<String?> metadataJson = const Value.absent(),
            Value<DateTime> occurredAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OccurrenceEventsCompanion(
            id: id,
            occurrenceId: occurrenceId,
            commandId: commandId,
            eventType: eventType,
            fromStatus: fromStatus,
            toStatus: toStatus,
            beforeLocalDate: beforeLocalDate,
            beforeTimezoneId: beforeTimezoneId,
            afterLocalDate: afterLocalDate,
            afterTimezoneId: afterTimezoneId,
            reason: reason,
            metadataJson: metadataJson,
            occurredAtUtc: occurredAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String occurrenceId,
            required String commandId,
            required String eventType,
            Value<String?> fromStatus = const Value.absent(),
            Value<String?> toStatus = const Value.absent(),
            Value<String?> beforeLocalDate = const Value.absent(),
            Value<String?> beforeTimezoneId = const Value.absent(),
            Value<String?> afterLocalDate = const Value.absent(),
            Value<String?> afterTimezoneId = const Value.absent(),
            Value<String?> reason = const Value.absent(),
            Value<String?> metadataJson = const Value.absent(),
            required DateTime occurredAtUtc,
            Value<int> rowid = const Value.absent(),
          }) =>
              OccurrenceEventsCompanion.insert(
            id: id,
            occurrenceId: occurrenceId,
            commandId: commandId,
            eventType: eventType,
            fromStatus: fromStatus,
            toStatus: toStatus,
            beforeLocalDate: beforeLocalDate,
            beforeTimezoneId: beforeTimezoneId,
            afterLocalDate: afterLocalDate,
            afterTimezoneId: afterTimezoneId,
            reason: reason,
            metadataJson: metadataJson,
            occurredAtUtc: occurredAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$OccurrenceEventsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $OccurrenceEventsTable> {
  $$OccurrenceEventsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get commandId => $state.composableBuilder(
      column: $state.table.commandId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get eventType => $state.composableBuilder(
      column: $state.table.eventType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fromStatus => $state.composableBuilder(
      column: $state.table.fromStatus,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get toStatus => $state.composableBuilder(
      column: $state.table.toStatus,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get beforeLocalDate => $state.composableBuilder(
      column: $state.table.beforeLocalDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get beforeTimezoneId => $state.composableBuilder(
      column: $state.table.beforeTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get afterLocalDate => $state.composableBuilder(
      column: $state.table.afterLocalDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get afterTimezoneId => $state.composableBuilder(
      column: $state.table.afterTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get reason => $state.composableBuilder(
      column: $state.table.reason,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get metadataJson => $state.composableBuilder(
      column: $state.table.metadataJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get occurredAtUtc => $state.composableBuilder(
      column: $state.table.occurredAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ScheduledSessionOccurrencesTableFilterComposer get occurrenceId {
    final $$ScheduledSessionOccurrencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.occurrenceId,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.scheduledSessionOccurrences,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$OccurrenceEventsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $OccurrenceEventsTable> {
  $$OccurrenceEventsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get commandId => $state.composableBuilder(
      column: $state.table.commandId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get eventType => $state.composableBuilder(
      column: $state.table.eventType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fromStatus => $state.composableBuilder(
      column: $state.table.fromStatus,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get toStatus => $state.composableBuilder(
      column: $state.table.toStatus,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get beforeLocalDate => $state.composableBuilder(
      column: $state.table.beforeLocalDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get beforeTimezoneId => $state.composableBuilder(
      column: $state.table.beforeTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get afterLocalDate => $state.composableBuilder(
      column: $state.table.afterLocalDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get afterTimezoneId => $state.composableBuilder(
      column: $state.table.afterTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get reason => $state.composableBuilder(
      column: $state.table.reason,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get metadataJson => $state.composableBuilder(
      column: $state.table.metadataJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get occurredAtUtc => $state.composableBuilder(
      column: $state.table.occurredAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ScheduledSessionOccurrencesTableOrderingComposer get occurrenceId {
    final $$ScheduledSessionOccurrencesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.occurrenceId,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableOrderingComposer(
                    ComposerState(
                        $state.db,
                        $state.db.scheduledSessionOccurrences,
                        joinBuilder,
                        parentComposers)));
    return composer;
  }
}

typedef $$EquipmentProfilesTableCreateCompanionBuilder
    = EquipmentProfilesCompanion Function({
  required String id,
  required String name,
  Value<double?> defaultWeightIncrementKg,
  Value<String?> legacyAccessCode,
  Value<String?> note,
  Value<DateTime?> archivedAtUtc,
  required DateTime createdAtUtc,
  required DateTime updatedAtUtc,
  Value<int> rowid,
});
typedef $$EquipmentProfilesTableUpdateCompanionBuilder
    = EquipmentProfilesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<double?> defaultWeightIncrementKg,
  Value<String?> legacyAccessCode,
  Value<String?> note,
  Value<DateTime?> archivedAtUtc,
  Value<DateTime> createdAtUtc,
  Value<DateTime> updatedAtUtc,
  Value<int> rowid,
});

class $$EquipmentProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EquipmentProfilesTable,
    EquipmentProfile,
    $$EquipmentProfilesTableFilterComposer,
    $$EquipmentProfilesTableOrderingComposer,
    $$EquipmentProfilesTableCreateCompanionBuilder,
    $$EquipmentProfilesTableUpdateCompanionBuilder> {
  $$EquipmentProfilesTableTableManager(
      _$AppDatabase db, $EquipmentProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$EquipmentProfilesTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$EquipmentProfilesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double?> defaultWeightIncrementKg = const Value.absent(),
            Value<String?> legacyAccessCode = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime?> archivedAtUtc = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<DateTime> updatedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EquipmentProfilesCompanion(
            id: id,
            name: name,
            defaultWeightIncrementKg: defaultWeightIncrementKg,
            legacyAccessCode: legacyAccessCode,
            note: note,
            archivedAtUtc: archivedAtUtc,
            createdAtUtc: createdAtUtc,
            updatedAtUtc: updatedAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<double?> defaultWeightIncrementKg = const Value.absent(),
            Value<String?> legacyAccessCode = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime?> archivedAtUtc = const Value.absent(),
            required DateTime createdAtUtc,
            required DateTime updatedAtUtc,
            Value<int> rowid = const Value.absent(),
          }) =>
              EquipmentProfilesCompanion.insert(
            id: id,
            name: name,
            defaultWeightIncrementKg: defaultWeightIncrementKg,
            legacyAccessCode: legacyAccessCode,
            note: note,
            archivedAtUtc: archivedAtUtc,
            createdAtUtc: createdAtUtc,
            updatedAtUtc: updatedAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$EquipmentProfilesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $EquipmentProfilesTable> {
  $$EquipmentProfilesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get defaultWeightIncrementKg =>
      $state.composableBuilder(
          column: $state.table.defaultWeightIncrementKg,
          builder: (column, joinBuilders) =>
              ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get legacyAccessCode => $state.composableBuilder(
      column: $state.table.legacyAccessCode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get note => $state.composableBuilder(
      column: $state.table.note,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get archivedAtUtc => $state.composableBuilder(
      column: $state.table.archivedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAtUtc => $state.composableBuilder(
      column: $state.table.updatedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter trainingPlanSettingsRefs(
      ComposableFilter Function($$TrainingPlanSettingsTableFilterComposer f)
          f) {
    final $$TrainingPlanSettingsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.trainingPlanSettings,
            getReferencedColumn: (t) => t.defaultEquipmentProfileId,
            builder: (joinBuilder, parentComposers) =>
                $$TrainingPlanSettingsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.trainingPlanSettings,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter equipmentProfileItemsRefs(
      ComposableFilter Function($$EquipmentProfileItemsTableFilterComposer f)
          f) {
    final $$EquipmentProfileItemsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.equipmentProfileItems,
            getReferencedColumn: (t) => t.equipmentProfileId,
            builder: (joinBuilder, parentComposers) =>
                $$EquipmentProfileItemsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.equipmentProfileItems,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter travelContextsRefs(
      ComposableFilter Function($$TravelContextsTableFilterComposer f) f) {
    final $$TravelContextsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.travelContexts,
        getReferencedColumn: (t) => t.equipmentProfileId,
        builder: (joinBuilder, parentComposers) =>
            $$TravelContextsTableFilterComposer(ComposerState($state.db,
                $state.db.travelContexts, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$EquipmentProfilesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $EquipmentProfilesTable> {
  $$EquipmentProfilesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get defaultWeightIncrementKg =>
      $state.composableBuilder(
          column: $state.table.defaultWeightIncrementKg,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get legacyAccessCode => $state.composableBuilder(
      column: $state.table.legacyAccessCode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get note => $state.composableBuilder(
      column: $state.table.note,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get archivedAtUtc => $state.composableBuilder(
      column: $state.table.archivedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAtUtc => $state.composableBuilder(
      column: $state.table.updatedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$TrainingPlanSettingsTableCreateCompanionBuilder
    = TrainingPlanSettingsCompanion Function({
  Value<int> id,
  Value<String?> activeProgramVersionId,
  Value<String?> activeSinceLocalDate,
  Value<String?> activeSinceTimezoneId,
  Value<String?> defaultEquipmentProfileId,
  required DateTime updatedAtUtc,
});
typedef $$TrainingPlanSettingsTableUpdateCompanionBuilder
    = TrainingPlanSettingsCompanion Function({
  Value<int> id,
  Value<String?> activeProgramVersionId,
  Value<String?> activeSinceLocalDate,
  Value<String?> activeSinceTimezoneId,
  Value<String?> defaultEquipmentProfileId,
  Value<DateTime> updatedAtUtc,
});

class $$TrainingPlanSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrainingPlanSettingsTable,
    TrainingPlanSetting,
    $$TrainingPlanSettingsTableFilterComposer,
    $$TrainingPlanSettingsTableOrderingComposer,
    $$TrainingPlanSettingsTableCreateCompanionBuilder,
    $$TrainingPlanSettingsTableUpdateCompanionBuilder> {
  $$TrainingPlanSettingsTableTableManager(
      _$AppDatabase db, $TrainingPlanSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$TrainingPlanSettingsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$TrainingPlanSettingsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> activeProgramVersionId = const Value.absent(),
            Value<String?> activeSinceLocalDate = const Value.absent(),
            Value<String?> activeSinceTimezoneId = const Value.absent(),
            Value<String?> defaultEquipmentProfileId = const Value.absent(),
            Value<DateTime> updatedAtUtc = const Value.absent(),
          }) =>
              TrainingPlanSettingsCompanion(
            id: id,
            activeProgramVersionId: activeProgramVersionId,
            activeSinceLocalDate: activeSinceLocalDate,
            activeSinceTimezoneId: activeSinceTimezoneId,
            defaultEquipmentProfileId: defaultEquipmentProfileId,
            updatedAtUtc: updatedAtUtc,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> activeProgramVersionId = const Value.absent(),
            Value<String?> activeSinceLocalDate = const Value.absent(),
            Value<String?> activeSinceTimezoneId = const Value.absent(),
            Value<String?> defaultEquipmentProfileId = const Value.absent(),
            required DateTime updatedAtUtc,
          }) =>
              TrainingPlanSettingsCompanion.insert(
            id: id,
            activeProgramVersionId: activeProgramVersionId,
            activeSinceLocalDate: activeSinceLocalDate,
            activeSinceTimezoneId: activeSinceTimezoneId,
            defaultEquipmentProfileId: defaultEquipmentProfileId,
            updatedAtUtc: updatedAtUtc,
          ),
        ));
}

class $$TrainingPlanSettingsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $TrainingPlanSettingsTable> {
  $$TrainingPlanSettingsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get activeSinceLocalDate => $state.composableBuilder(
      column: $state.table.activeSinceLocalDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get activeSinceTimezoneId => $state.composableBuilder(
      column: $state.table.activeSinceTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAtUtc => $state.composableBuilder(
      column: $state.table.updatedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableFilterComposer get activeProgramVersionId {
    final $$ProgramVersionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.activeProgramVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableFilterComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  $$EquipmentProfilesTableFilterComposer get defaultEquipmentProfileId {
    final $$EquipmentProfilesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.defaultEquipmentProfileId,
            referencedTable: $state.db.equipmentProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$EquipmentProfilesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.equipmentProfiles,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$TrainingPlanSettingsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $TrainingPlanSettingsTable> {
  $$TrainingPlanSettingsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get activeSinceLocalDate => $state.composableBuilder(
      column: $state.table.activeSinceLocalDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get activeSinceTimezoneId => $state.composableBuilder(
      column: $state.table.activeSinceTimezoneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAtUtc => $state.composableBuilder(
      column: $state.table.updatedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ProgramVersionsTableOrderingComposer get activeProgramVersionId {
    final $$ProgramVersionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.activeProgramVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }

  $$EquipmentProfilesTableOrderingComposer get defaultEquipmentProfileId {
    final $$EquipmentProfilesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.defaultEquipmentProfileId,
            referencedTable: $state.db.equipmentProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$EquipmentProfilesTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.equipmentProfiles,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$EquipmentProfileItemsTableCreateCompanionBuilder
    = EquipmentProfileItemsCompanion Function({
  required String id,
  required String equipmentProfileId,
  required String equipmentCode,
  Value<bool> isAvailable,
  Value<double?> weightIncrementKg,
  Value<int> rowid,
});
typedef $$EquipmentProfileItemsTableUpdateCompanionBuilder
    = EquipmentProfileItemsCompanion Function({
  Value<String> id,
  Value<String> equipmentProfileId,
  Value<String> equipmentCode,
  Value<bool> isAvailable,
  Value<double?> weightIncrementKg,
  Value<int> rowid,
});

class $$EquipmentProfileItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EquipmentProfileItemsTable,
    EquipmentProfileItem,
    $$EquipmentProfileItemsTableFilterComposer,
    $$EquipmentProfileItemsTableOrderingComposer,
    $$EquipmentProfileItemsTableCreateCompanionBuilder,
    $$EquipmentProfileItemsTableUpdateCompanionBuilder> {
  $$EquipmentProfileItemsTableTableManager(
      _$AppDatabase db, $EquipmentProfileItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$EquipmentProfileItemsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$EquipmentProfileItemsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> equipmentProfileId = const Value.absent(),
            Value<String> equipmentCode = const Value.absent(),
            Value<bool> isAvailable = const Value.absent(),
            Value<double?> weightIncrementKg = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EquipmentProfileItemsCompanion(
            id: id,
            equipmentProfileId: equipmentProfileId,
            equipmentCode: equipmentCode,
            isAvailable: isAvailable,
            weightIncrementKg: weightIncrementKg,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String equipmentProfileId,
            required String equipmentCode,
            Value<bool> isAvailable = const Value.absent(),
            Value<double?> weightIncrementKg = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EquipmentProfileItemsCompanion.insert(
            id: id,
            equipmentProfileId: equipmentProfileId,
            equipmentCode: equipmentCode,
            isAvailable: isAvailable,
            weightIncrementKg: weightIncrementKg,
            rowid: rowid,
          ),
        ));
}

class $$EquipmentProfileItemsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $EquipmentProfileItemsTable> {
  $$EquipmentProfileItemsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get equipmentCode => $state.composableBuilder(
      column: $state.table.equipmentCode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isAvailable => $state.composableBuilder(
      column: $state.table.isAvailable,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get weightIncrementKg => $state.composableBuilder(
      column: $state.table.weightIncrementKg,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$EquipmentProfilesTableFilterComposer get equipmentProfileId {
    final $$EquipmentProfilesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.equipmentProfileId,
            referencedTable: $state.db.equipmentProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$EquipmentProfilesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.equipmentProfiles,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$EquipmentProfileItemsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $EquipmentProfileItemsTable> {
  $$EquipmentProfileItemsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get equipmentCode => $state.composableBuilder(
      column: $state.table.equipmentCode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isAvailable => $state.composableBuilder(
      column: $state.table.isAvailable,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get weightIncrementKg => $state.composableBuilder(
      column: $state.table.weightIncrementKg,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$EquipmentProfilesTableOrderingComposer get equipmentProfileId {
    final $$EquipmentProfilesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.equipmentProfileId,
            referencedTable: $state.db.equipmentProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$EquipmentProfilesTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.equipmentProfiles,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$TravelContextsTableCreateCompanionBuilder = TravelContextsCompanion
    Function({
  required String id,
  required String startLocalDate,
  required String endLocalDate,
  required String timezoneId,
  required String equipmentProfileId,
  Value<String> status,
  Value<String?> note,
  required DateTime createdAtUtc,
  Value<DateTime?> endedAtUtc,
  Value<int> rowid,
});
typedef $$TravelContextsTableUpdateCompanionBuilder = TravelContextsCompanion
    Function({
  Value<String> id,
  Value<String> startLocalDate,
  Value<String> endLocalDate,
  Value<String> timezoneId,
  Value<String> equipmentProfileId,
  Value<String> status,
  Value<String?> note,
  Value<DateTime> createdAtUtc,
  Value<DateTime?> endedAtUtc,
  Value<int> rowid,
});

class $$TravelContextsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TravelContextsTable,
    TravelContext,
    $$TravelContextsTableFilterComposer,
    $$TravelContextsTableOrderingComposer,
    $$TravelContextsTableCreateCompanionBuilder,
    $$TravelContextsTableUpdateCompanionBuilder> {
  $$TravelContextsTableTableManager(
      _$AppDatabase db, $TravelContextsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$TravelContextsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$TravelContextsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> startLocalDate = const Value.absent(),
            Value<String> endLocalDate = const Value.absent(),
            Value<String> timezoneId = const Value.absent(),
            Value<String> equipmentProfileId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<DateTime?> endedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TravelContextsCompanion(
            id: id,
            startLocalDate: startLocalDate,
            endLocalDate: endLocalDate,
            timezoneId: timezoneId,
            equipmentProfileId: equipmentProfileId,
            status: status,
            note: note,
            createdAtUtc: createdAtUtc,
            endedAtUtc: endedAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String startLocalDate,
            required String endLocalDate,
            required String timezoneId,
            required String equipmentProfileId,
            Value<String> status = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required DateTime createdAtUtc,
            Value<DateTime?> endedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TravelContextsCompanion.insert(
            id: id,
            startLocalDate: startLocalDate,
            endLocalDate: endLocalDate,
            timezoneId: timezoneId,
            equipmentProfileId: equipmentProfileId,
            status: status,
            note: note,
            createdAtUtc: createdAtUtc,
            endedAtUtc: endedAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$TravelContextsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $TravelContextsTable> {
  $$TravelContextsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get startLocalDate => $state.composableBuilder(
      column: $state.table.startLocalDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get endLocalDate => $state.composableBuilder(
      column: $state.table.endLocalDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get timezoneId => $state.composableBuilder(
      column: $state.table.timezoneId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get note => $state.composableBuilder(
      column: $state.table.note,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get endedAtUtc => $state.composableBuilder(
      column: $state.table.endedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$EquipmentProfilesTableFilterComposer get equipmentProfileId {
    final $$EquipmentProfilesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.equipmentProfileId,
            referencedTable: $state.db.equipmentProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$EquipmentProfilesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.equipmentProfiles,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }

  ComposableFilter travelContextOccurrencesRefs(
      ComposableFilter Function($$TravelContextOccurrencesTableFilterComposer f)
          f) {
    final $$TravelContextOccurrencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.travelContextOccurrences,
            getReferencedColumn: (t) => t.travelContextId,
            builder: (joinBuilder, parentComposers) =>
                $$TravelContextOccurrencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.travelContextOccurrences,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$TravelContextsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $TravelContextsTable> {
  $$TravelContextsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get startLocalDate => $state.composableBuilder(
      column: $state.table.startLocalDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get endLocalDate => $state.composableBuilder(
      column: $state.table.endLocalDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get timezoneId => $state.composableBuilder(
      column: $state.table.timezoneId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get note => $state.composableBuilder(
      column: $state.table.note,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get endedAtUtc => $state.composableBuilder(
      column: $state.table.endedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$EquipmentProfilesTableOrderingComposer get equipmentProfileId {
    final $$EquipmentProfilesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.equipmentProfileId,
            referencedTable: $state.db.equipmentProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$EquipmentProfilesTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.equipmentProfiles,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$TravelContextOccurrencesTableCreateCompanionBuilder
    = TravelContextOccurrencesCompanion Function({
  required String travelContextId,
  required String occurrenceId,
  required DateTime confirmedAtUtc,
  Value<int> rowid,
});
typedef $$TravelContextOccurrencesTableUpdateCompanionBuilder
    = TravelContextOccurrencesCompanion Function({
  Value<String> travelContextId,
  Value<String> occurrenceId,
  Value<DateTime> confirmedAtUtc,
  Value<int> rowid,
});

class $$TravelContextOccurrencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TravelContextOccurrencesTable,
    TravelContextOccurrence,
    $$TravelContextOccurrencesTableFilterComposer,
    $$TravelContextOccurrencesTableOrderingComposer,
    $$TravelContextOccurrencesTableCreateCompanionBuilder,
    $$TravelContextOccurrencesTableUpdateCompanionBuilder> {
  $$TravelContextOccurrencesTableTableManager(
      _$AppDatabase db, $TravelContextOccurrencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$TravelContextOccurrencesTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$TravelContextOccurrencesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> travelContextId = const Value.absent(),
            Value<String> occurrenceId = const Value.absent(),
            Value<DateTime> confirmedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TravelContextOccurrencesCompanion(
            travelContextId: travelContextId,
            occurrenceId: occurrenceId,
            confirmedAtUtc: confirmedAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String travelContextId,
            required String occurrenceId,
            required DateTime confirmedAtUtc,
            Value<int> rowid = const Value.absent(),
          }) =>
              TravelContextOccurrencesCompanion.insert(
            travelContextId: travelContextId,
            occurrenceId: occurrenceId,
            confirmedAtUtc: confirmedAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$TravelContextOccurrencesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $TravelContextOccurrencesTable> {
  $$TravelContextOccurrencesTableFilterComposer(super.$state);
  ColumnFilters<DateTime> get confirmedAtUtc => $state.composableBuilder(
      column: $state.table.confirmedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TravelContextsTableFilterComposer get travelContextId {
    final $$TravelContextsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.travelContextId,
        referencedTable: $state.db.travelContexts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TravelContextsTableFilterComposer(ComposerState($state.db,
                $state.db.travelContexts, joinBuilder, parentComposers)));
    return composer;
  }

  $$ScheduledSessionOccurrencesTableFilterComposer get occurrenceId {
    final $$ScheduledSessionOccurrencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.occurrenceId,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.scheduledSessionOccurrences,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$TravelContextOccurrencesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $TravelContextOccurrencesTable> {
  $$TravelContextOccurrencesTableOrderingComposer(super.$state);
  ColumnOrderings<DateTime> get confirmedAtUtc => $state.composableBuilder(
      column: $state.table.confirmedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TravelContextsTableOrderingComposer get travelContextId {
    final $$TravelContextsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.travelContextId,
            referencedTable: $state.db.travelContexts,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$TravelContextsTableOrderingComposer(ComposerState($state.db,
                    $state.db.travelContexts, joinBuilder, parentComposers)));
    return composer;
  }

  $$ScheduledSessionOccurrencesTableOrderingComposer get occurrenceId {
    final $$ScheduledSessionOccurrencesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.occurrenceId,
            referencedTable: $state.db.scheduledSessionOccurrences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ScheduledSessionOccurrencesTableOrderingComposer(
                    ComposerState(
                        $state.db,
                        $state.db.scheduledSessionOccurrences,
                        joinBuilder,
                        parentComposers)));
    return composer;
  }
}

typedef $$ExerciseUserPreferencesTableCreateCompanionBuilder
    = ExerciseUserPreferencesCompanion Function({
  required String id,
  required String identityKey,
  Value<String?> exerciseId,
  Value<String?> exerciseNameFallback,
  Value<String?> generalNote,
  required DateTime createdAtUtc,
  required DateTime updatedAtUtc,
  Value<int> rowid,
});
typedef $$ExerciseUserPreferencesTableUpdateCompanionBuilder
    = ExerciseUserPreferencesCompanion Function({
  Value<String> id,
  Value<String> identityKey,
  Value<String?> exerciseId,
  Value<String?> exerciseNameFallback,
  Value<String?> generalNote,
  Value<DateTime> createdAtUtc,
  Value<DateTime> updatedAtUtc,
  Value<int> rowid,
});

class $$ExerciseUserPreferencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExerciseUserPreferencesTable,
    ExerciseUserPreference,
    $$ExerciseUserPreferencesTableFilterComposer,
    $$ExerciseUserPreferencesTableOrderingComposer,
    $$ExerciseUserPreferencesTableCreateCompanionBuilder,
    $$ExerciseUserPreferencesTableUpdateCompanionBuilder> {
  $$ExerciseUserPreferencesTableTableManager(
      _$AppDatabase db, $ExerciseUserPreferencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ExerciseUserPreferencesTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ExerciseUserPreferencesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> identityKey = const Value.absent(),
            Value<String?> exerciseId = const Value.absent(),
            Value<String?> exerciseNameFallback = const Value.absent(),
            Value<String?> generalNote = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<DateTime> updatedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseUserPreferencesCompanion(
            id: id,
            identityKey: identityKey,
            exerciseId: exerciseId,
            exerciseNameFallback: exerciseNameFallback,
            generalNote: generalNote,
            createdAtUtc: createdAtUtc,
            updatedAtUtc: updatedAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String identityKey,
            Value<String?> exerciseId = const Value.absent(),
            Value<String?> exerciseNameFallback = const Value.absent(),
            Value<String?> generalNote = const Value.absent(),
            required DateTime createdAtUtc,
            required DateTime updatedAtUtc,
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseUserPreferencesCompanion.insert(
            id: id,
            identityKey: identityKey,
            exerciseId: exerciseId,
            exerciseNameFallback: exerciseNameFallback,
            generalNote: generalNote,
            createdAtUtc: createdAtUtc,
            updatedAtUtc: updatedAtUtc,
            rowid: rowid,
          ),
        ));
}

class $$ExerciseUserPreferencesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ExerciseUserPreferencesTable> {
  $$ExerciseUserPreferencesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get identityKey => $state.composableBuilder(
      column: $state.table.identityKey,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get exerciseNameFallback => $state.composableBuilder(
      column: $state.table.exerciseNameFallback,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get generalNote => $state.composableBuilder(
      column: $state.table.generalNote,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAtUtc => $state.composableBuilder(
      column: $state.table.updatedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $state.db.exercises,
        getReferencedColumn: (t) => t.stableId,
        builder: (joinBuilder, parentComposers) =>
            $$ExercisesTableFilterComposer(ComposerState(
                $state.db, $state.db.exercises, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter exerciseSetupValuesRefs(
      ComposableFilter Function($$ExerciseSetupValuesTableFilterComposer f) f) {
    final $$ExerciseSetupValuesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.exerciseSetupValues,
            getReferencedColumn: (t) => t.exerciseUserPreferenceId,
            builder: (joinBuilder, parentComposers) =>
                $$ExerciseSetupValuesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.exerciseSetupValues,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter exercisePersonalCuesRefs(
      ComposableFilter Function($$ExercisePersonalCuesTableFilterComposer f)
          f) {
    final $$ExercisePersonalCuesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.exercisePersonalCues,
            getReferencedColumn: (t) => t.exerciseUserPreferenceId,
            builder: (joinBuilder, parentComposers) =>
                $$ExercisePersonalCuesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.exercisePersonalCues,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ExerciseUserPreferencesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ExerciseUserPreferencesTable> {
  $$ExerciseUserPreferencesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get identityKey => $state.composableBuilder(
      column: $state.table.identityKey,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get exerciseNameFallback => $state.composableBuilder(
      column: $state.table.exerciseNameFallback,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get generalNote => $state.composableBuilder(
      column: $state.table.generalNote,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAtUtc => $state.composableBuilder(
      column: $state.table.createdAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAtUtc => $state.composableBuilder(
      column: $state.table.updatedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $state.db.exercises,
        getReferencedColumn: (t) => t.stableId,
        builder: (joinBuilder, parentComposers) =>
            $$ExercisesTableOrderingComposer(ComposerState(
                $state.db, $state.db.exercises, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ExerciseSetupValuesTableCreateCompanionBuilder
    = ExerciseSetupValuesCompanion Function({
  required String id,
  required String exerciseUserPreferenceId,
  required int ordinal,
  required String label,
  required String value,
  Value<int> rowid,
});
typedef $$ExerciseSetupValuesTableUpdateCompanionBuilder
    = ExerciseSetupValuesCompanion Function({
  Value<String> id,
  Value<String> exerciseUserPreferenceId,
  Value<int> ordinal,
  Value<String> label,
  Value<String> value,
  Value<int> rowid,
});

class $$ExerciseSetupValuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExerciseSetupValuesTable,
    ExerciseSetupValue,
    $$ExerciseSetupValuesTableFilterComposer,
    $$ExerciseSetupValuesTableOrderingComposer,
    $$ExerciseSetupValuesTableCreateCompanionBuilder,
    $$ExerciseSetupValuesTableUpdateCompanionBuilder> {
  $$ExerciseSetupValuesTableTableManager(
      _$AppDatabase db, $ExerciseSetupValuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ExerciseSetupValuesTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ExerciseSetupValuesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> exerciseUserPreferenceId = const Value.absent(),
            Value<int> ordinal = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseSetupValuesCompanion(
            id: id,
            exerciseUserPreferenceId: exerciseUserPreferenceId,
            ordinal: ordinal,
            label: label,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String exerciseUserPreferenceId,
            required int ordinal,
            required String label,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseSetupValuesCompanion.insert(
            id: id,
            exerciseUserPreferenceId: exerciseUserPreferenceId,
            ordinal: ordinal,
            label: label,
            value: value,
            rowid: rowid,
          ),
        ));
}

class $$ExerciseSetupValuesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ExerciseSetupValuesTable> {
  $$ExerciseSetupValuesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get label => $state.composableBuilder(
      column: $state.table.label,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ExerciseUserPreferencesTableFilterComposer get exerciseUserPreferenceId {
    final $$ExerciseUserPreferencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.exerciseUserPreferenceId,
            referencedTable: $state.db.exerciseUserPreferences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ExerciseUserPreferencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.exerciseUserPreferences,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$ExerciseSetupValuesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ExerciseSetupValuesTable> {
  $$ExerciseSetupValuesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get label => $state.composableBuilder(
      column: $state.table.label,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ExerciseUserPreferencesTableOrderingComposer get exerciseUserPreferenceId {
    final $$ExerciseUserPreferencesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.exerciseUserPreferenceId,
            referencedTable: $state.db.exerciseUserPreferences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ExerciseUserPreferencesTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.exerciseUserPreferences,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$ExercisePersonalCuesTableCreateCompanionBuilder
    = ExercisePersonalCuesCompanion Function({
  required String id,
  required String exerciseUserPreferenceId,
  required int ordinal,
  required String cueText,
  Value<int> rowid,
});
typedef $$ExercisePersonalCuesTableUpdateCompanionBuilder
    = ExercisePersonalCuesCompanion Function({
  Value<String> id,
  Value<String> exerciseUserPreferenceId,
  Value<int> ordinal,
  Value<String> cueText,
  Value<int> rowid,
});

class $$ExercisePersonalCuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExercisePersonalCuesTable,
    ExercisePersonalCue,
    $$ExercisePersonalCuesTableFilterComposer,
    $$ExercisePersonalCuesTableOrderingComposer,
    $$ExercisePersonalCuesTableCreateCompanionBuilder,
    $$ExercisePersonalCuesTableUpdateCompanionBuilder> {
  $$ExercisePersonalCuesTableTableManager(
      _$AppDatabase db, $ExercisePersonalCuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ExercisePersonalCuesTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ExercisePersonalCuesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> exerciseUserPreferenceId = const Value.absent(),
            Value<int> ordinal = const Value.absent(),
            Value<String> cueText = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExercisePersonalCuesCompanion(
            id: id,
            exerciseUserPreferenceId: exerciseUserPreferenceId,
            ordinal: ordinal,
            cueText: cueText,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String exerciseUserPreferenceId,
            required int ordinal,
            required String cueText,
            Value<int> rowid = const Value.absent(),
          }) =>
              ExercisePersonalCuesCompanion.insert(
            id: id,
            exerciseUserPreferenceId: exerciseUserPreferenceId,
            ordinal: ordinal,
            cueText: cueText,
            rowid: rowid,
          ),
        ));
}

class $$ExercisePersonalCuesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ExercisePersonalCuesTable> {
  $$ExercisePersonalCuesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get cueText => $state.composableBuilder(
      column: $state.table.cueText,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ExerciseUserPreferencesTableFilterComposer get exerciseUserPreferenceId {
    final $$ExerciseUserPreferencesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.exerciseUserPreferenceId,
            referencedTable: $state.db.exerciseUserPreferences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ExerciseUserPreferencesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.exerciseUserPreferences,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

class $$ExercisePersonalCuesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ExercisePersonalCuesTable> {
  $$ExercisePersonalCuesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get ordinal => $state.composableBuilder(
      column: $state.table.ordinal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cueText => $state.composableBuilder(
      column: $state.table.cueText,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ExerciseUserPreferencesTableOrderingComposer get exerciseUserPreferenceId {
    final $$ExerciseUserPreferencesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.exerciseUserPreferenceId,
            referencedTable: $state.db.exerciseUserPreferences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ExerciseUserPreferencesTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.exerciseUserPreferences,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }
}

typedef $$LegacyRoutineProgramMappingsTableCreateCompanionBuilder
    = LegacyRoutineProgramMappingsCompanion Function({
  Value<int> legacyRoutineId,
  required String programId,
  required String programVersionId,
  required DateTime importedAtUtc,
});
typedef $$LegacyRoutineProgramMappingsTableUpdateCompanionBuilder
    = LegacyRoutineProgramMappingsCompanion Function({
  Value<int> legacyRoutineId,
  Value<String> programId,
  Value<String> programVersionId,
  Value<DateTime> importedAtUtc,
});

class $$LegacyRoutineProgramMappingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LegacyRoutineProgramMappingsTable,
    LegacyRoutineProgramMapping,
    $$LegacyRoutineProgramMappingsTableFilterComposer,
    $$LegacyRoutineProgramMappingsTableOrderingComposer,
    $$LegacyRoutineProgramMappingsTableCreateCompanionBuilder,
    $$LegacyRoutineProgramMappingsTableUpdateCompanionBuilder> {
  $$LegacyRoutineProgramMappingsTableTableManager(
      _$AppDatabase db, $LegacyRoutineProgramMappingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$LegacyRoutineProgramMappingsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$LegacyRoutineProgramMappingsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> legacyRoutineId = const Value.absent(),
            Value<String> programId = const Value.absent(),
            Value<String> programVersionId = const Value.absent(),
            Value<DateTime> importedAtUtc = const Value.absent(),
          }) =>
              LegacyRoutineProgramMappingsCompanion(
            legacyRoutineId: legacyRoutineId,
            programId: programId,
            programVersionId: programVersionId,
            importedAtUtc: importedAtUtc,
          ),
          createCompanionCallback: ({
            Value<int> legacyRoutineId = const Value.absent(),
            required String programId,
            required String programVersionId,
            required DateTime importedAtUtc,
          }) =>
              LegacyRoutineProgramMappingsCompanion.insert(
            legacyRoutineId: legacyRoutineId,
            programId: programId,
            programVersionId: programVersionId,
            importedAtUtc: importedAtUtc,
          ),
        ));
}

class $$LegacyRoutineProgramMappingsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $LegacyRoutineProgramMappingsTable> {
  $$LegacyRoutineProgramMappingsTableFilterComposer(super.$state);
  ColumnFilters<DateTime> get importedAtUtc => $state.composableBuilder(
      column: $state.table.importedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$WorkoutRoutinesTableFilterComposer get legacyRoutineId {
    final $$WorkoutRoutinesTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.legacyRoutineId,
            referencedTable: $state.db.workoutRoutines,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutRoutinesTableFilterComposer(ComposerState($state.db,
                    $state.db.workoutRoutines, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramsTableFilterComposer get programId {
    final $$ProgramsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.programId,
        referencedTable: $state.db.programs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramsTableFilterComposer(ComposerState(
                $state.db, $state.db.programs, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramVersionsTableFilterComposer get programVersionId {
    final $$ProgramVersionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableFilterComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$LegacyRoutineProgramMappingsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase,
        $LegacyRoutineProgramMappingsTable> {
  $$LegacyRoutineProgramMappingsTableOrderingComposer(super.$state);
  ColumnOrderings<DateTime> get importedAtUtc => $state.composableBuilder(
      column: $state.table.importedAtUtc,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$WorkoutRoutinesTableOrderingComposer get legacyRoutineId {
    final $$WorkoutRoutinesTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.legacyRoutineId,
            referencedTable: $state.db.workoutRoutines,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$WorkoutRoutinesTableOrderingComposer(ComposerState($state.db,
                    $state.db.workoutRoutines, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramsTableOrderingComposer get programId {
    final $$ProgramsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.programId,
        referencedTable: $state.db.programs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$ProgramsTableOrderingComposer(ComposerState(
                $state.db, $state.db.programs, joinBuilder, parentComposers)));
    return composer;
  }

  $$ProgramVersionsTableOrderingComposer get programVersionId {
    final $$ProgramVersionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.programVersionId,
            referencedTable: $state.db.programVersions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ProgramVersionsTableOrderingComposer(ComposerState($state.db,
                    $state.db.programVersions, joinBuilder, parentComposers)));
    return composer;
  }
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoodItemsTableTableManager get foodItems =>
      $$FoodItemsTableTableManager(_db, _db.foodItems);
  $$FoodLogsTableTableManager get foodLogs =>
      $$FoodLogsTableTableManager(_db, _db.foodLogs);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$BodyMeasurementsTableTableManager get bodyMeasurements =>
      $$BodyMeasurementsTableTableManager(_db, _db.bodyMeasurements);
  $$WorkoutRoutinesTableTableManager get workoutRoutines =>
      $$WorkoutRoutinesTableTableManager(_db, _db.workoutRoutines);
  $$RoutineDaysTableTableManager get routineDays =>
      $$RoutineDaysTableTableManager(_db, _db.routineDays);
  $$RoutineExercisesTableTableManager get routineExercises =>
      $$RoutineExercisesTableTableManager(_db, _db.routineExercises);
  $$WorkoutDraftsTableTableManager get workoutDrafts =>
      $$WorkoutDraftsTableTableManager(_db, _db.workoutDrafts);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$MealTemplatesTableTableManager get mealTemplates =>
      $$MealTemplatesTableTableManager(_db, _db.mealTemplates);
  $$MealTemplateItemsTableTableManager get mealTemplateItems =>
      $$MealTemplateItemsTableTableManager(_db, _db.mealTemplateItems);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$DailyHydrationsTableTableManager get dailyHydrations =>
      $$DailyHydrationsTableTableManager(_db, _db.dailyHydrations);
  $$HealthProvenancesTableTableManager get healthProvenances =>
      $$HealthProvenancesTableTableManager(_db, _db.healthProvenances);
  $$AchievementUnlocksTableTableManager get achievementUnlocks =>
      $$AchievementUnlocksTableTableManager(_db, _db.achievementUnlocks);
  $$ProgramsTableTableManager get programs =>
      $$ProgramsTableTableManager(_db, _db.programs);
  $$ProgramVersionsTableTableManager get programVersions =>
      $$ProgramVersionsTableTableManager(_db, _db.programVersions);
  $$ProgramBlocksTableTableManager get programBlocks =>
      $$ProgramBlocksTableTableManager(_db, _db.programBlocks);
  $$ProgramWeeksTableTableManager get programWeeks =>
      $$ProgramWeeksTableTableManager(_db, _db.programWeeks);
  $$SessionTemplatesTableTableManager get sessionTemplates =>
      $$SessionTemplatesTableTableManager(_db, _db.sessionTemplates);
  $$ExercisePrescriptionsTableTableManager get exercisePrescriptions =>
      $$ExercisePrescriptionsTableTableManager(_db, _db.exercisePrescriptions);
  $$ScheduledSessionOccurrencesTableTableManager
      get scheduledSessionOccurrences =>
          $$ScheduledSessionOccurrencesTableTableManager(
              _db, _db.scheduledSessionOccurrences);
  $$OccurrenceEventsTableTableManager get occurrenceEvents =>
      $$OccurrenceEventsTableTableManager(_db, _db.occurrenceEvents);
  $$EquipmentProfilesTableTableManager get equipmentProfiles =>
      $$EquipmentProfilesTableTableManager(_db, _db.equipmentProfiles);
  $$TrainingPlanSettingsTableTableManager get trainingPlanSettings =>
      $$TrainingPlanSettingsTableTableManager(_db, _db.trainingPlanSettings);
  $$EquipmentProfileItemsTableTableManager get equipmentProfileItems =>
      $$EquipmentProfileItemsTableTableManager(_db, _db.equipmentProfileItems);
  $$TravelContextsTableTableManager get travelContexts =>
      $$TravelContextsTableTableManager(_db, _db.travelContexts);
  $$TravelContextOccurrencesTableTableManager get travelContextOccurrences =>
      $$TravelContextOccurrencesTableTableManager(
          _db, _db.travelContextOccurrences);
  $$ExerciseUserPreferencesTableTableManager get exerciseUserPreferences =>
      $$ExerciseUserPreferencesTableTableManager(
          _db, _db.exerciseUserPreferences);
  $$ExerciseSetupValuesTableTableManager get exerciseSetupValues =>
      $$ExerciseSetupValuesTableTableManager(_db, _db.exerciseSetupValues);
  $$ExercisePersonalCuesTableTableManager get exercisePersonalCues =>
      $$ExercisePersonalCuesTableTableManager(_db, _db.exercisePersonalCues);
  $$LegacyRoutineProgramMappingsTableTableManager
      get legacyRoutineProgramMappings =>
          $$LegacyRoutineProgramMappingsTableTableManager(
              _db, _db.legacyRoutineProgramMappings);
}
