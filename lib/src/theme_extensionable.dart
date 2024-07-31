import 'dart:async';
import 'package:macro_util/macro_util.dart';
import 'package:macros/macros.dart';
import 'package:data_class/data_class.dart';
import 'package:collection/collection.dart';

macro class ThemeExtensionable
    with _LerpMixin
    implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const ThemeExtensionable();

  @override
  Future<void> buildDeclarationsForClass(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    await CopyWith().buildDeclarationsForClass(clazz, builder);
    await declareLerp(clazz, builder);
  }

  @override
  Future<void> buildDefinitionForClass(ClassDeclaration clazz,
      TypeDefinitionBuilder builder) async {
    await CopyWith().buildDefinitionForClass(clazz, builder);
    await buildLerp(clazz, builder);
  }
}

mixin _LerpMixin {
  Future<void> declareLerp(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    final methods = await builder.methodsOf(clazz);
    final lerpMethod = methods.firstWhereOrNull(
          (method) => method.identifier.name == 'lerp',
    );
    if (lerpMethod != null) {
      builder.reportError('The lerp method exists');
      return;
    }

    final className = clazz.identifier.name;
    final superclass = clazz.superclass;
    if (superclass == null) {
      builder.reportError(
          'The class does not extend ThemeExtension<$className>');
      return;
    }

    final doubleType = await builder.resolveIdentifier(
        Uri.parse('dart:core'), 'double');
    final parts = <Object>[
      'external ',
      className,
      ' lerp(covariant ',
      superclass.code.asNullable,
      ' other, ',
      doubleType,
      ' t);\n'
    ].indent();

    builder.declareInType(DeclarationCode.fromParts(parts));
  }

  Future<void> buildLerp(ClassDeclaration clazz,
      TypeDefinitionBuilder typeBuilder) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final lerpMethod = methods
        .firstWhereOrNull(
          (method) => method.identifier.name == 'lerp',
    );
    if (lerpMethod == null) return;

    final methodBuilder = await typeBuilder.buildMethod(lerpMethod.identifier);
    final className = clazz.identifier.name;
    final lerpDouble = await typeBuilder.resolveIdentifier(
        Uri.parse('dart:ui'), 'lerpDouble');
    final fieldList = await _setup(clazz, typeBuilder);
    final parts = <Object>[
      '{\n',
      '\t\tif (other is! $className) return this as $className;\n',
      '\t\treturn ',
      className,
      '(\n',
      ..._generateLerpFields(fieldList, lerpDouble),
      '\t\t);\n',
      '\t}\n',
    ];

    methodBuilder.augment(FunctionBodyCode.fromParts(parts));
  }

  Future<List<FieldInfo>> _setup(ClassDeclaration clazz,
      TypeDefinitionBuilder builder) async {
    final fields = await builder.fieldsOf(clazz);
    final newList = <FieldInfo>[];
    for (final field in fields) {
      final fieldInfo = FieldInfo(field);
      fieldInfo.isLerping =
      await FieldInfo.isLerp(builder, fieldInfo.namedTypeCode.name);
      newList.add(fieldInfo);
    }
    return newList;
  }

  Iterable<Object> _generateLerpFields(List<FieldInfo> fields,
      Identifier lerpDouble) {
    return fields.map((field) {
      final name = field.name;
      if (field.isLerping) {
        return RawCode.fromParts([
          '\t\t\t$name: ',
          field.namedTypeCode,
          '.lerp($name, other.$name, t)',
          field.typeCode.isNullable ? '' : '!',
          ',\n'
        ]);
      }
      final type = field.namedTypeCode.name.name;
      if (type == 'double' || type == 'int') {
        return RawCode.fromParts(
            ['\t\t\t$name: ',
              lerpDouble,
              '( $name,  other.$name, t)',
              if(!field.typeCode.isNullable)'!' else
                if(type == 'int') '?',
              if(type == 'int')
                '.toInt()',
              ',\n',
            ]);
      }
      return RawCode.fromParts(
          ['\t\t\t$name: t < 0.5 ? $name : other.$name,\n']);
    });
  }
}

class FieldInfo {
  bool isLerping;
  final FieldDeclaration field;

  FieldInfo(this.field, [this.isLerping = false]);

  TypeAnnotationCode get typeCode => field.type.code;

  NamedTypeAnnotationCode get namedTypeCode =>
      typeCode.asNonNullable as NamedTypeAnnotationCode;

  String get name => field.identifier.name;

  static Future<bool> isLerp(builder, Identifier namedTypeName) async {
    final fieldTypeDeclaration = await builder.typeDeclarationOf(
        namedTypeName);
    final methods = await builder.methodsOf(fieldTypeDeclaration);
    return methods.any((method) =>
    method.identifier.name == 'lerp');
  }
}