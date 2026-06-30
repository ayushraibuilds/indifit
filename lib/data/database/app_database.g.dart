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
        isCustom
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
      required this.isCustom});
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
          bool? isCustom}) =>
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
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, nameHindi, calories, proteinG,
      carbsG, fatG, fiberG, servingSize, servingUnit, category, isCustom);
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
          other.isCustom == this.isCustom);
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
      Value<bool>? isCustom}) {
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
          ..write('isCustom: $isCustom')
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
        isSynced
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
      required this.isSynced});
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
          bool? isSynced}) =>
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
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, foodItemId, name, calories, proteinG,
      carbsG, fatG, servingLogged, servingUnit, mealType, loggedAt, isSynced);
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
          other.isSynced == this.isSynced);
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
      Value<bool>? isSynced}) {
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
          ..write('isSynced: $isSynced')
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
  int get hashCode => Object.hash(id, name, muscleGroups, equipment, difficulty,
      formCues, commonMistakes, youtubeId, isCustom);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
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
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        totalVolume,
        durationSeconds,
        estimatedCalories,
        completedAt,
        isSynced
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
  const WorkoutSession(
      {required this.id,
      required this.name,
      required this.totalVolume,
      required this.durationSeconds,
      required this.estimatedCalories,
      required this.completedAt,
      required this.isSynced});
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
    };
  }

  WorkoutSession copyWith(
          {int? id,
          String? name,
          double? totalVolume,
          int? durationSeconds,
          int? estimatedCalories,
          DateTime? completedAt,
          bool? isSynced}) =>
      WorkoutSession(
        id: id ?? this.id,
        name: name ?? this.name,
        totalVolume: totalVolume ?? this.totalVolume,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        estimatedCalories: estimatedCalories ?? this.estimatedCalories,
        completedAt: completedAt ?? this.completedAt,
        isSynced: isSynced ?? this.isSynced,
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
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, totalVolume, durationSeconds,
      estimatedCalories, completedAt, isSynced);
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
          other.isSynced == this.isSynced);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSession> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> totalVolume;
  final Value<int> durationSeconds;
  final Value<int> estimatedCalories;
  final Value<DateTime> completedAt;
  final Value<bool> isSynced;
  const WorkoutSessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.totalVolume = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.estimatedCalories = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double totalVolume,
    required int durationSeconds,
    required int estimatedCalories,
    this.completedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
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
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (totalVolume != null) 'total_volume': totalVolume,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (estimatedCalories != null) 'estimated_calories': estimatedCalories,
      if (completedAt != null) 'completed_at': completedAt,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  WorkoutSessionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<double>? totalVolume,
      Value<int>? durationSeconds,
      Value<int>? estimatedCalories,
      Value<DateTime>? completedAt,
      Value<bool>? isSynced}) {
    return WorkoutSessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      totalVolume: totalVolume ?? this.totalVolume,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      completedAt: completedAt ?? this.completedAt,
      isSynced: isSynced ?? this.isSynced,
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
          ..write('isSynced: $isSynced')
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
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, exerciseName, weight, reps, setNumber, isPr];
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
  const WorkoutSet(
      {required this.id,
      required this.sessionId,
      required this.exerciseName,
      required this.weight,
      required this.reps,
      required this.setNumber,
      required this.isPr});
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
    };
  }

  WorkoutSet copyWith(
          {int? id,
          int? sessionId,
          String? exerciseName,
          double? weight,
          int? reps,
          int? setNumber,
          bool? isPr}) =>
      WorkoutSet(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        exerciseName: exerciseName ?? this.exerciseName,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        setNumber: setNumber ?? this.setNumber,
        isPr: isPr ?? this.isPr,
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
          ..write('isPr: $isPr')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, exerciseName, weight, reps, setNumber, isPr);
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
          other.isPr == this.isPr);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> exerciseName;
  final Value<double> weight;
  final Value<int> reps;
  final Value<int> setNumber;
  final Value<bool> isPr;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.isPr = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String exerciseName,
    required double weight,
    required int reps,
    required int setNumber,
    this.isPr = const Value.absent(),
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
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (weight != null) 'weight': weight,
      if (reps != null) 'reps': reps,
      if (setNumber != null) 'set_number': setNumber,
      if (isPr != null) 'is_pr': isPr,
    });
  }

  WorkoutSetsCompanion copyWith(
      {Value<int>? id,
      Value<int>? sessionId,
      Value<String>? exerciseName,
      Value<double>? weight,
      Value<int>? reps,
      Value<int>? setNumber,
      Value<bool>? isPr}) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseName: exerciseName ?? this.exerciseName,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      setNumber: setNumber ?? this.setNumber,
      isPr: isPr ?? this.isPr,
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
          ..write('isPr: $isPr')
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
        bodyMeasurements
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
}

class $$ExercisesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
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
          }) =>
              WorkoutSessionsCompanion(
            id: id,
            name: name,
            totalVolume: totalVolume,
            durationSeconds: durationSeconds,
            estimatedCalories: estimatedCalories,
            completedAt: completedAt,
            isSynced: isSynced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required double totalVolume,
            required int durationSeconds,
            required int estimatedCalories,
            Value<DateTime> completedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
          }) =>
              WorkoutSessionsCompanion.insert(
            id: id,
            name: name,
            totalVolume: totalVolume,
            durationSeconds: durationSeconds,
            estimatedCalories: estimatedCalories,
            completedAt: completedAt,
            isSynced: isSynced,
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
          }) =>
              WorkoutSetsCompanion(
            id: id,
            sessionId: sessionId,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            setNumber: setNumber,
            isPr: isPr,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sessionId,
            required String exerciseName,
            required double weight,
            required int reps,
            required int setNumber,
            Value<bool> isPr = const Value.absent(),
          }) =>
              WorkoutSetsCompanion.insert(
            id: id,
            sessionId: sessionId,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            setNumber: setNumber,
            isPr: isPr,
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
}
