package fu;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import fu.macros.FieldUtils;

using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using fu.macros.FieldUtils;

enum SerializingType {
    SClass(?ctr:Expr);
    SValue;
    SEnum(et:EnumType);
    SMap(vtype:SerializingType);
    SArray(vtype:SerializingType);
    SFArray(vtype:SerializingType);
}

interface SerializableExprs {
    /** Returns an expression the value of which represents value from runtime to be serialized **/
    function runtimeValueExpr(name:Expr):Expr;

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance **/
    function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr;

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    function serializedValueExpr(name:String):Expr;

    /**In cases where instance should exist to be inited with data, returns expression that creates the instance. **/
    function assertExpr(name:Expr):Null<Expr>;
}

class SerializerStorage {
    static final singletones:Map<SerializingType, SerializableExprs> = [
        SClass(null) => new ClassSExprs(),
        SValue => new ValueSExprs(),
        // SMap => new MapSExprs()
    ];

    public static function getSExpressions(type:SerializingType):SerializableExprs {
        return switch type {
            case SArray(vtype): new ArraySExprs(getSExpressions(vtype));
            case SMap(vtype): new MapSExprs(getSExpressions(vtype));
            case SFArray(vtype): new FixedArraySExprs(getSExpressions(vtype));
            case SClass(ctr): if (ctr != null) new ClassSExprs(ctr) else singletones[SClass(null)];
            case SEnum(et): new EnumSExprs(et);
            case single: singletones[single];
        }
    }

    public static function toSerializingType(ct:ComplexType, name, pos, ctx:FieldConfig) {
        return switch ct {
            case null:
                Context.error('Define explicit type for $name variable to be serialized', pos);
            case macro :Int, macro :String, macro :Float, macro :Bool, TPath({name: "StdTypes", sub: "Int"}), TAnonymous(_):
                SValue;
            case TPath({name: 'Array', params: [TPType(cpt)]}):
                if (ctx.fixedArray) {
                    SFArray(toSerializingType(cpt, name, pos, ctx));
                } else {
                    SArray(toSerializingType(cpt, name, pos, ctx));
                }
            case TPath(p):
                var t:Type = ct.toType();
                switch t.follow() {
                    case TInst(_.get() => {name: "Array"}, [cpt]):
                        if (ctx.fixedArray) {
                            SFArray(toSerializingType(cpt.toComplexType(), name, pos, ctx));
                        } else {
                            SArray(toSerializingType(cpt.toComplexType(), name, pos, ctx));
                        }
                    case TInst(_.get() => ct, params):
                        if (!FieldUtils.implementz (ct, "Serializable"))
                            Context.error('${ct.name} doesnt implement Serializable, $t, ${t.follow()},\n\n\n\n $p', pos);
                        SClass(ctx.itemCtr);
                    case TEnum(_.get() => et, params):
                        SEnum(et);
                    case TType(_.get() => {name: "Map"}, params), TAbstract(_.get() => {name: "Map"}, params):
                        SMap(toSerializingType(params[1].toComplexType(), name, pos, ctx));
                    case TAnonymous(a):
                        SValue;
                    case TAbstract(_.get() => at, params):
                        toSerializingType(at.type.followWithAbstracts().toComplexType(), name, pos, ctx);
                    case _:
                        Context.error('Serialization of ${t + "\n flw: " + t.follow() + "\n ct: " + ct + "\n nam: " + name} not supported', pos);
                }
            case _:
                Context.error('Serialization of $ct not supported', pos);
        }
    }
}

class ClassSExprs implements SerializableExprs {
    var itemConstructorExpr:Expr;

    public function new(itemConstructor:Expr = null) {
        this.itemConstructorExpr = itemConstructor;
    }

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        return macro $name.dump();
    }

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance **/
    public function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr {
        return macro $name.load($serializedValueExpr);
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        return macro Reflect.field(data, $v{name});
    }

    public function assertExpr(name:Expr):Null<Expr> {
        if (itemConstructorExpr == null)
            return macro null;
        return macro if ($name == null) $name = $itemConstructorExpr;
    }
}

typedef FieldConfig = {
    ?itemCtr:Expr,
    ?skipNullLoad:Bool,
    ?fixedArray:Bool
}

class SerializableMacro {
    public static function build() {
        var fields:Array<Field> = Context.getBuildFields();
        var lc = Context.getLocalClass().get();
        var hasSerializing = false;
        var loadExprs = new MethodExprs(fields, lc, "load");
        loadExprs.addArg("data", macro :Dynamic);
        var dumpExprs = new MethodExprs(fields, lc, "dump", macro :Dynamic);

        for (f in fields) {
            switch f {
                case {
                    name: name,
                    kind: FVar(ct),
                    meta: [{name: ":serialize", params: params}],
                    pos: pos
                }, {
                    name: name,
                    kind: FProp(_, _, ct, _),
                    meta: [{name: ":serialize", params: params}],
                    pos: pos
                }:
                    hasSerializing = true;
                    var ctx = {};
                    if (params != null)
                        for (p in params) {
                            switch p.expr {
                                case EBinop(OpAssign, {expr: EConst(CIdent(prop))}, macro true):
                                    Reflect.setField(ctx, prop, true);
                                case EBinop(OpAssign, {expr: EConst(CIdent(prop))}, e2):
                                    Reflect.setField(ctx, prop, e2);
                                case _:
                            }
                        }

                    var stype = SerializerStorage.toSerializingType(ct, name, pos, ctx);
                    var sexprs = SerializerStorage.getSExpressions(stype);
                    dumpExprs.push(macro Reflect.setField(data, $v{name}, ${sexprs.runtimeValueExpr(macro this.$name)}));
                    var loadAndAssignExp = sexprs.loadValueExpr(macro this.$name, sexprs.serializedValueExpr(name)) ;
                    if (ctx.skipNullLoad)
                        loadAndAssignExp = macro if (Reflect.hasField(data, $v{name})) $loadAndAssignExp;
                    loadExprs.push(loadAndAssignExp);
                case {meta: meta, pos: pos, name: name}:
                    if (meta?.filter(f -> f.name == ':serialize').length > 0)
                        Context.error('Serialization of $name not supported', pos);
                case _:
            }
        }

        var dumpRequired = hasSerializing || dumpExprs.found || !dumpExprs.hasSuper;
        if (dumpRequired) {
            if (dumpExprs.hasSuper)
                dumpExprs.unshift(macro var data:Dynamic = __ret__);
            else {
                dumpExprs.unshift(macro __ret__ = data);
                dumpExprs.unshift(macro var data:Dynamic = {});
            }
            dumpExprs.finalize();
        }

        var loadRequired = hasSerializing || loadExprs.found || !dumpExprs.hasSuper;
        if (loadRequired)
            loadExprs.finalize();

        return fields;
    }
}

class MethodExprs {
    var args:Array<FunctionArg> = [];
    var exprs:Array<Expr> = [];
    var fields:Array<Field>;
    var name:String;
    var ret:ComplexType;

    public var found(default, null) = false;
    public var hasSuper(default, null) = false;

    public function new(fields:Array<Field>, lc, name, ?ret:ComplexType) {
        this.name = name;
        this.ret = ret;
        this.fields = fields;
        hasSuper = (FieldUtils.hasFieldInClassType(lc.superClass?.t.get(), name));
        for (f in fields) {
            if (f.name != name)
                continue;
            switch f {
                case {
                    kind: FFun({
                        args: args,
                        expr: {expr: EBlock(exprs)}
                    }),
                }:
                    this.exprs = exprs;
                    this.args = args;
                    found = true;
                    break;
                case {
                    pos: pos
                }:
                    Context.error('Wrong $name() signature for Serializable ', pos);
                case _:
            }
        }
    }

    public function finalize() {
        var access = [APublic];
        if (hasSuper) {
            access.push(AOverride);
            if (ret != null)
                exprs.unshift(macro var __ret__ = $p{["super", name]}($a{args.map(ar -> macro $i{ar.name})}));
            else
                exprs.unshift(macro $p{["super", name]}($a{args.map(ar -> macro $i{ar.name})}));
        } else {
            if (ret != null)
                exprs.unshift(macro var __ret__:$ret);
        }

        if (ret != null)
            exprs.push(macro return __ret__);

        if (!found)
            fields.push({
                name: name,
                access: access,
                kind: FFun({
                    args: this.args,
                    ret: ret,
                    expr: {expr: EBlock(this.exprs), pos: Context.currentPos()}
                }),
                pos: Context.currentPos()
            });
    }

    public function push(e) {
        exprs.push(e);
    }

    public function unshift(e) {
        exprs.unshift(e);
    }

    public function addArg(name, type) {
        if (found)
            return;
        args.push({name: name, type: type});
    }
}

/**
    Assuming thar runtime representation of this array has fixed size, already exists as well as all item instances.
    If size of serialized representation differs, unpredictable errors would occure.
**/
class FixedArraySExprs implements SerializableExprs {
    static var jPostfix = 0;

    var valueExprs:SerializableExprs;

    public function new(valueExprs) {
        this.valueExprs = valueExprs;
    }

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        return macro [for (v in $name) ${valueExprs.runtimeValueExpr(macro v)}];
    }

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance 
        name is expr of runtime array, serializedValueExpr is expr of array contains serialized item representations.
    **/
    public function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr {
        return macro {
            var data = $serializedValueExpr; // Reflect.field(data, $v{name});
            for ($i{"j" + ++jPostfix} in 0...data.length) {
                ${valueExprs.loadValueExpr(macro $name[$i{"j" + jPostfix}], macro data[$i{"j" + jPostfix}])};
            }
        }
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        return macro Reflect.field(data, $v{name});
    }

    public function assertExpr(name:Expr):Null<Expr> {
        return macro null;
    }
}
class MapSExprs implements SerializableExprs {
    static var jPostfix = 0;

    var valueExprs:SerializableExprs;

    public function new(valueExprs) {
        this.valueExprs = valueExprs;
    }

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        var itemExpr = macro $name.get(__k);
        return macro [for (__k in $name.keys()) [__k, ${valueExprs.runtimeValueExpr(itemExpr)}]];
    }

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance 
        name is expr of runtime array, serializedValueExpr is expr of array contains serialized item representations.
    **/
    public function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr {
        return macro {
            $name.clear();
            var data:Array<Dynamic> = $serializedValueExpr; 
            for ($i{"j" + ++jPostfix} in 0...data.length) {
                var pair:Array<Dynamic> = data[$i{"j" + jPostfix}];
                var value:Dynamic;
                ${valueExprs.assertExpr(macro value)};
                ${valueExprs.loadValueExpr(macro value, macro pair[1])};
                $name.set(pair[0], value);
            }
        }
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        return macro Reflect.field(data, $v{name});
    }

    public function assertExpr(name:Expr):Null<Expr> {
        return macro if ($name == null) $name = new Map();
}
}


class ArraySExprs implements SerializableExprs {
    static var jPostfix = 0;

    var valueExprs:SerializableExprs;

    public function new(valueExprs) {
        this.valueExprs = valueExprs;
    }

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        return macro [for (v in $name) ${valueExprs.runtimeValueExpr(macro v)}];
    }

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance 
        name is expr of runtime array, serializedValueExpr is expr of array contains serialized item representations.
    **/
    public function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr {
        return macro {
            $name.resize(0);
            var data = $serializedValueExpr; // Reflect.field(data, $v{name});
            for ($i{"j" + ++jPostfix} in 0...data.length) {
                ${valueExprs.assertExpr(macro $name[$i{"j" + jPostfix}])};
                ${valueExprs.loadValueExpr(macro $name[$i{"j" + jPostfix}], macro data[$i{"j" + jPostfix}])};
            }
        }
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        return macro Reflect.field(data, $v{name});
    }

    public function assertExpr(name:Expr):Null<Expr> {
        return macro if ($name == null) $name = [];
    }
}

class EnumSExprs implements SerializableExprs {
    var et:EnumType;
    var runtimeCases:Array<Case> = [];
    var deserializeExprs:Array<Expr> = [];

    public function new(et) {
        this.et = et;
        for (ctr in et.constructs) {
            switch ctr.type {
                case TFun(args, ret):
                    runtimeCases.push({
                        values: [macro $i{ctr.name}($a{args.map(a -> macro $i{a.name})})],
                        expr: objDecl([
                            {name: ctr.name, expr: objDecl(args.map(a -> {name: a.name, expr: getValueExpr(a.t, a.name)}))}
                        ])
                    });
                    deserializeExprs.push(macro {});
                case TEnum(t, params):
                    runtimeCases.push({
                        values: [macro $i{ctr.name}],
                        expr: objDecl([{name: ctr.name, expr: objDecl([])}])
                    });

                case _:
                    throw ctr.type;
            }
        }
    }

    function getValueExpr(t:Type, name:String) {
        var st = SerializerStorage.toSerializingType(t.toComplexType(), 'Within Enum ${et.name}', Context.currentPos(), {});
        var se = SerializerStorage.getSExpressions(st);
        return se.runtimeValueExpr(macro cast $i{name});
    }

    function objDecl(fields:Array<{name:String, expr:Expr}>) {
        var expr = {
            expr: EObjectDecl(fields.map(a -> {quotes: Unquoted, field: a.name, expr: a.expr})),
            pos: Context.currentPos(),
        }
        return macro cast $expr;
    }

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        return {
            expr: ESwitch(macro $name, runtimeCases, macro throw "Wrong"),
            pos: Context.currentPos(),
        }
    }

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance **/
    public function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr {
        return macro $name = $serializedValueExpr;
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        var exprs = [];
        exprs.push(macro var enumData:Dynamic = Reflect.field(data, $v{name}));
        var deserializeExprs = [];
        deserializeExprs.push(macro var result = null);

        for (ctr in et.constructs) {
            switch ctr.type {
                case TFun(args, ret):
                    var ctargs = [];
                    for (a in args) {
                        var st = SerializerStorage.toSerializingType(a.t.toComplexType(), '${a.name} in ctr.name', Context.currentPos(), {});
                        var et = SerializerStorage.getSExpressions(st);
                        ctargs.push(et.serializedValueExpr(a.name));
                    }

                    deserializeExprs.push(macro if (Reflect.hasField(enumData, $v{ctr.name})) {
                        var data = Reflect.field(enumData, $v{ctr.name});
                        result = cast $i{ctr.name}($a{ctargs});
                    });
                case TEnum(t, params):
                    deserializeExprs.push(macro if (Reflect.hasField(enumData, $v{ctr.name})) result = cast $i{ctr.name});
                case _:
                    throw ctr.type;
            }
        }

        deserializeExprs.push(macro if (result == null) throw 'Can`t deserealize ' + enumData + ' to ' + $v{name});
        deserializeExprs.push(macro result);

        return macro $b{exprs.concat(deserializeExprs)};
    }

    public function assertExpr(name:Expr):Null<Expr> {
        return macro cast "ass";
    }
}

class TinkSExprs implements SerializableExprs {
    public function new() {}

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        return macro haxe.Json.parse(tink.Json.stringify($name));
    }

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance **/
    public function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr {
        return macro $name = $serializedValueExpr;
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        return macro tink.Json.parse(haxe.Json.stringify(data.$name));
    }

    public function assertExpr(name:Expr):Null<Expr> {
        return macro null;
    }
}

class ValueSExprs implements SerializableExprs {
    public function new() {}

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        return name;
    }

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance **/
    public function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr {
        return macro $name = $serializedValueExpr;
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        return macro Reflect.field(data, $v{name});
    }

    public function assertExpr(name:Expr):Null<Expr> {
        return macro null;
    }
}
#end
