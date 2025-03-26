package fu;

import haxe.EnumTools;
import haxe.Json;

class SerializableTest {
    public static function main() {
        // var data = '{"B":{"i":5}}';
        // var enm:A = C;
        // data = tink.Json.stringify(enm);
        // trace(data);
        // enm = tink.Json.parse(data);
        // trace(enm);
        // return;

        var foo = new Foo();
        var data = Json.stringify(foo.dump());
        trace(data, Type.getClass(data));
        data = '{"intVar":6,"cl":{"stringVar":"rts", "strings":["foo", "bar"]},"enu":"C","boolVar":false}';
        var parsed = Json.parse(data);
        trace(parsed.enu);
        foo.load(parsed);
        assert(foo.intVar, 6);
        assert(foo.boolVar, false, "bool");
        assert(foo.cl.stringVar, "rts");
        assert(foo.cl.strings.indexOf("foo"), 0, "foo");
        assert(foo.cl.strings.indexOf("bar"), 1, "bar");
        trace('done');
        // assert(true, foo.enu == C, "enum");

        // trace(tink.Json.stringify(foo.enu));
    }

    static function assert(val1:Dynamic, val2:Dynamic, msg = "") {
        if (val1 != val2)
            throw '$msg: $val1!=$val2';
    }
}

class Foo implements Serializable {
    @:serialize public var intVar:Int = 5;
    @:serialize public var boolVar:Bool = true;
    @:serialize public var cl:Bar = new Bar();
    // @:serialize public var enu:A = C;

    public function new() {}
}

enum A {
    // @:json({type: 'B'})
    B(i:Int);
    @:json("C") C;
}

class Bar implements Serializable {
    @:serialize public var stringVar:String = "str";
    @:serialize public var strings:Array<String> = ["str"];

    public function new() {}
    
    public function dump() {
        trace('dumping bar');
    }
}
