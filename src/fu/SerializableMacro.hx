package fu;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using haxe.macro.ComplexTypeTools;

class SerializableMacro {
    public static function build() {
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
                    switch ct {
                        case null:
                            Context.error('Define explicit type for $name variable to be serialized', pos);
                        case macro :Int, macro :String, macro :Float, macro :Bool:
                            dumpExprs.push(macro Reflect.setField(data, $v{name}, $i{name}));
                            loadExprs.push(macro $i{name} = Reflect.field(data, $v{name}));
                        case TPath(p):
                            var t:Type = ct.toType();
                            switch t {
                                case TInst(_.get() => ct, params):
                                    if (ct.interfaces.filter(f -> f.t.get().name == "Serializable").length < 1)
                                        throw '$ct doesnt implement Serializable';
                                    dumpExprs.push(macro Reflect.setField(data, $v{name}, $i{name}.dump()));
                                    loadExprs.push(macro $i{name}.load(Reflect.field(data, $v{name})));

                                case TEnum(t, params):
                                    dumpExprs.push(macro Reflect.setField(data, $v{name}, haxe.Json.parse(tink.Json.stringify($i{name}))));
                                    loadExprs.push(macro $i{name} = tink.Json.parse(haxe.Json.stringify(data.$name)));
                                case _:
                                    Context.error('Serialization of $t not supported', pos);
                            }
                        case _:
                            Context.error('Serialization of $ct not supported', pos);
                    }

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
