package fu.macros;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

class FieldUtils {
    public static function hasField(name) {
        var fields = Context.getBuildFields();
        for (f in fields)
            if (f.name == name)
                return true;
        var lc = Context.getLocalClass().get();
        return hasFieldInClassType(lc, name);
    }

    public static function hasFieldInClassType(ct:ClassType, name) {
        if (ct == null)
            return false;
        for (f in ct.fields.get())
            if (f.name == name) {
                return true;
            }
        if (ct.superClass != null) {
            var r = hasFieldInClassType(ct.superClass.t.get(), name);
            return r;
        }
        return false;
    }

    public static function implementz(ct:ClassType, name) {
        if (ct.interfaces.filter(f -> f.t.get().name == name).length > 0)
            return true;

        if (ct.superClass != null)
            return implementz(ct.superClass.t.get(), name);

        return false;
    }

    public static function addField(fields:Array<Field>, name, type, ?e) {
        if (!hasField(name))
            fields.push({
                pos: Context.currentPos(),
                name: name,
                kind: FieldType.FVar(type, e),
            });
    }

    public static function addMethod(fields:Array<Field>, name, exprs:Array<Expr>, args:Array<FunctionArg> = null, ret:ComplexType = null) {
        var access = [APublic];
        if (args == null)
            args = [];
        if (hasFieldInClassType(Context.getLocalClass().get(), name)) {
            access.push(AOverride);
            if (ret != null)
                exprs.unshift(macro var ret = $p{["super", name]}($a{args.map(ar -> macro $i{ar.name})}));
            else
                exprs.unshift(macro $p{["super", name]}($a{args.map(ar -> macro $i{ar.name})}));
        }
        fields.push({
            pos: Context.currentPos(),
            name: name,
            access: access,
            kind: FieldType.FFun({args: args, expr: {expr: EBlock(exprs), pos: Context.currentPos()}, ret: ret}),
        });
    }
}
#end
