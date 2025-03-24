package fu;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using haxe.macro.ComplexTypeTools;

class SerializableMacro {
    public static function build() {
        var fields = Context.getBuildFields();
        var dumpExprs:Array<Expr> = [];
        var loadExprs:Array<Expr> = [];
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
                            trace(name);
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
                    if (meta.filter(f -> f.name == ':serialize').length > 0)
                        Context.error('Serialization of $name not supported', pos);
                case _:
            }
        }
        dumpExprs.push(macro return data);
        fields.push({
            name: "dump",
            access: [APublic],
            kind: FFun({
                args: [],
                expr: {expr: EBlock(dumpExprs), pos: Context.currentPos()}
            }),
            pos: Context.currentPos()
        });

        fields.push({
            name: "load",
            access: [APublic],
            kind: FFun({
                args: [{name: "data", type: macro :Dynamic}],
                expr: {expr: EBlock(loadExprs), pos: Context.currentPos()}
            }),
            pos: Context.currentPos()
        });
        return fields;
    }
}
#end
