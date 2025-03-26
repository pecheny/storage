package fu;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using haxe.macro.ComplexTypeTools;

typedef SerializingTypeExprs = {
    dump:String->Expr,
    load:String->Expr,
}

enum SerializingType {
    SClass;
    SValue;
    SEnum;
    SArray(vtype:SerializingType);
}

interface SerializableExprs {
    /** Returns an expression the value of which represents value from runtime to be serialized **/
    function runtimeValueExpr(name:Expr):Expr;

    /** receives expression of "value extracted from data" and Returns an expression which put received value to the runtime instance **/
    function loadValueExpr(name:Expr, serializedValueExpr:Expr):Expr;

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    function serializedValueExpr(name:String):Expr;

    // function assertExpr(name:Expr):Null<Expr>;
    // function assignExpr(name:String):Expr;
    // function extractExpr(name:String):Expr;
    // assignExpr: (name, extractExpr) -> macro $i{name} = $extractExpr,
    // extractExpr: name -> macro Reflect.field(data, $v{name}),
}

class SerializerStorage {
    static final singletones:Map<SerializingType, SerializableExprs> = [SClass => new ClassSExprs(), SValue => new ValueSExprs()];

    public static function getSExpressions(type:SerializingType):SerializableExprs {
        return switch type {
            case SArray(vtype): new ArraySExprs(getSExpressions(vtype));
            case single: singletones[single];
        }
    }
}

class ArraySExprs implements SerializableExprs {
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
            for (j in 0...data.length) {
                $name[j] = data[j];
                // ${valueExprs.assertExpr(macro $name[j])};
                // ${valueExprs.loadValueExpr(macro $name[j], macro data[j])};
                // ${valueExprs.loadValueExpr(macro $name[j], macro ${valueExprs.serializedValueExpr(macro data[j])})};
            }
        }
    }

    /** Assuming that data variable in the scope represents serialized dynamic structure, returns an expression the value of which should be assigned/put to runtime field **/
    public function serializedValueExpr(name:String):Expr {
        return macro Reflect.field(data, $v{name});
    }

    // public function assertExpr(name:Expr):Null<Expr> {
    //     return macro if($name == null) $name = [];
    // }
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

    // public function assertExpr(name:Expr):Null<Expr> {
    //     return macro null;
    // }
}

class ClassSExprs implements SerializableExprs {
    public function new() {}

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

    // public function assertExpr(name:Expr):Null<Expr> {
    //     throw new haxe.exceptions.NotImplementedException();
    // }
}

class SerializableMacro {
    public static function build() {
        // var exprsMap = new Map<SerializingType, SerializingTypeExprs>();

        // exprsMap[SValue] = {
        //     // valueExpr: name -> macro $i{name},
        //     // assignExpr: (name, extractExpr) -> macro $i{name} = $extractExpr,
        //     // extractExpr: name -> macro Reflect.field(data, $v{name}),

        //     dump: name -> macro Reflect.setField(data, $v{name}, $i{name}),
        //     load: name -> macro $i{name} = Reflect.field(data, $v{name})
        // };
        // exprsMap[SClass] = {
        //     // valueExpr: name -> macro $i{name}.dump(),
        //     // assignExpr: (name, extractExpr) -> macro $i{name}.load($extractExpr),
        //     // extractExpr: name -> macro Reflect.field(data, $v{name}),

        //     dump: name -> macro Reflect.setField(data, $v{name}, $i{name}.dump()),
        //     load: name -> macro $i{name}.load(Reflect.field(data, $v{name})),
        // };
        // exprsMap[SEnum] = {
        //     dump: name -> macro Reflect.setField(data, $v{name}, haxe.Json.parse(tink.Json.stringify($i{name}))),
        //     load: name -> macro $i{name} =
        // };

        // var se:SerializableExprs;
        // var runtimeValueExpr = macro haxe.Json.parse(tink.Json.stringify($i{name}));
        // var serializedValueExpr = macro tink.Json.parse(haxe.Json.stringify(data.$name));
        // var loadValueExpr = dumpExprs.push(macro Reflect.setField(data, $v{name}, se.runtimeValueExpr(name)));
        // loadExprs.push();

        // var arrayExprs = {
        //     extractExpr: name -> macro {
        //         var arrayData = Reflect.field(data, $v{name});
        //         for (j in 0...arrayData.length) {
        //             var itemData = arrayData[j];
        //             $i{name}[j]

        //         }
        //     }
        // }

        function toSerializingType(ct:ComplexType, name, pos) {
            return switch ct {
                case null:
                    Context.error('Define explicit type for $name variable to be serialized', pos);
                case macro :Int, macro :String, macro :Float, macro :Bool:
                    SValue;
                case TPath({name: 'Array', params: [TPType(cpt)]}):
                    // macro {var data = }
                    SArray(toSerializingType(cpt, name, pos));
                case TPath(p):
                    var t:Type = ct.toType();
                    switch t {
                        case TInst(_.get() => ct, params):
                            if (ct.interfaces.filter(f -> f.t.get().name == "Serializable").length < 1)
                                Context.error('${ct.name} doesnt implement Serializable', pos);
                            SClass;
                        case TEnum(t, params):
                            SEnum;
                        case _:
                            Context.error('Serialization of $t not supported', pos);
                    }
                case _:
                    Context.error('Serialization of $ct not supported', pos);
            }
        }

        var fields = Context.getBuildFields();
        var loadExprs = new MethodExprs(fields, "load");

        loadExprs.addArg("data", macro :Dynamic);
        var dumpExprs = new MethodExprs(fields, "dump");

        dumpExprs.push(macro var data = {});
        for (f in fields) {
            switch f {
                case {
                    name: name,
                    kind: FVar(ct),
                    meta: [{name: ":serialize"}],
                    pos: pos
                }:
                    var stype = toSerializingType(ct, name, pos);
                    var sexprs = SerializerStorage.getSExpressions(stype);
                    dumpExprs.push(macro Reflect.setField(data, $v{name}, ${sexprs.runtimeValueExpr(macro $i{name})} ));
                    loadExprs.push(sexprs.loadValueExpr(macro $i{name}, sexprs.serializedValueExpr(name)));
                    // trace(stype);
                    // switch stype {
                    //     case SSkip:
                    //     case _:
                    //         dumpExprs.push(exprsMap[stype].dump(name));
                    //         loadExprs.push(exprsMap[stype].load(name));
                    // }
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
                    trace('failing $name');
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
