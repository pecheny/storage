package fu;

import tink.macro.Exprs;
#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using haxe.macro.ComplexTypeTools;

enum SerializingType {
    SClass(?ctr:Expr);
    SValue;
    SEnum;
    SMap;
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
        SEnum => new TinkSExprs(),
        SMap => new TinkSExprs()
    ];

    public static function getSExpressions(type:SerializingType):SerializableExprs {
        return switch type {
            case SArray(vtype): new ArraySExprs(getSExpressions(vtype));
            case SFArray(vtype): new FixedArraySExprs(getSExpressions(vtype));
            case SClass(ctr): if (ctr != null) new ClassSExprs(ctr) else singletones[SClass(null)];
            case single: singletones[single];
        }
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
        return macro $name.copy();
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

class ArraySExprs implements SerializableExprs {
    static var jPostfix = 0;

    var valueExprs:SerializableExprs;

    public function new(valueExprs) {
        this.valueExprs = valueExprs;
    }

    /** Returns an expression the value of which represents value from runtime to be serialized **/
    public function runtimeValueExpr(name:Expr):Expr {
        // return macro [for (rv in macro $name) macro ${valueExprs.runtimeValueExpr(macro $i{"rv"})}];
        return macro $name.copy();
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
    ?fixedArray:Bool
}

class SerializableMacro {
    public static function build() {
        function toSerializingType(ct:ComplexType, name, pos, ctx:FieldConfig) {
            return switch ct {
                case null:
                    Context.error('Define explicit type for $name variable to be serialized', pos);
                case macro :Int, macro :String, macro :Float, macro :Bool:
                    SValue;
                case TPath({name: 'Array', params: [TPType(cpt)]}):
                    if (ctx.fixedArray) {
                        SFArray(toSerializingType(cpt, name, pos, ctx));
                    } else {
                        SArray(toSerializingType(cpt, name, pos, ctx));
                    }
                case TPath(p):
                    var t:Type = ct.toType();
                    switch t {
                        case TInst(_.get() => ct, params):
                            if (ct.interfaces.filter(f -> f.t.get().name == "Serializable").length < 1)
                                Context.error('${ct.name} doesnt implement Serializable', pos);
                            SClass(ctx.itemCtr);
                        case TEnum(t, params):
                            SEnum;
                        case TType(_.get() => {name: "Map"}, params):
                            SMap;
                        case _:
                            Context.error('Serialization of $t not supported', pos);
                    }
                case _:
                    Context.error('Serialization of $ct not supported', pos);
            }
        }

        var fields:Array<Field> = Context.getBuildFields();
        var loadExprs = new MethodExprs(fields, "load");

        loadExprs.addArg("data", macro :Dynamic);
        var dumpExprs = new MethodExprs(fields, "dump");

        dumpExprs.push(macro var data = {});
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

                    var stype = toSerializingType(ct, name, pos, ctx);
                    var sexprs = SerializerStorage.getSExpressions(stype);
                    dumpExprs.push(macro Reflect.setField(data, $v{name}, ${sexprs.runtimeValueExpr(macro $i{name})}));
                    loadExprs.push(sexprs.loadValueExpr(macro $i{name}, sexprs.serializedValueExpr(name)));
                case {meta: meta, pos: pos, name: name}:
                    if (meta?.filter(f -> f.name == ':serialize').length > 0)
                        Context.error('Serialization of $name not supported', pos);
                case _:
            }
        }
        dumpExprs.push(macro return data);
        return fields;
    }
}

class MethodExprs {
    var args:Array<FunctionArg> = [];
    var exprs:Array<Expr> = [];

    public function new(fields:Array<Field>, name) {
        var found = false;
        for (f in fields) {
            if (f.name != name)
                continue;
            switch f {
                case {
                    access: [APublic],
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
        if (!found)
            fields.push({
                name: name,
                access: [APublic],
                kind: FFun({
                    args: this.args,
                    expr: {expr: EBlock(this.exprs), pos: Context.currentPos()}
                }),
                pos: Context.currentPos()
            });
    }

    public function push(e) {
        exprs.push(e);
    }

    public function addArg(name, type) {
        args.push({name: name, type: type});
    }
}
#end
