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
        var barFromFixed = foo.fixedBars[0];
        var data = Json.stringify(foo.dump());
        trace(data, Type.getClass(data));
        data = '{"intVar":6,"cl":{"stringVar":"rts", "strings":[["foo", "bar"]]},"enu":"C","boolVar":false, "fixedBars":[{"stringVar":"fixed", "strings":[["foo", "bar"]]}], "bars":[{"stringVar":"rts", "strings":[["foo", "bar"]]}]}';
        var parsed = Json.parse(data);
        trace(parsed.enu);
        foo.load(parsed);
        assert(foo.intVar, 6);
        assert(foo.boolVar, false, "bool");
        assert(foo.cl.stringVar, "rts");
        assert(foo.cl.strings[0].indexOf("foo"), 0, "foo");
        assert(foo.cl.strings[0].indexOf("bar"), 1, "bar");
        assert(foo.bars[0].stringVar, "rts");
        assert(foo.fixedBars[0], barFromFixed);
        assert("fixed", barFromFixed.stringVar);
        assert(true, foo.enu == C, "enum");
        trace('done');

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
    @:serialize(itemCtr = new Bar()) public var bars:Array<Bar> = [];
    @:serialize(fixedArray = true) public var fixedBars:Array<Bar> = [new Bar()];

    @:serialize public var enu:A = B(5);

    public function new() {}
}

enum A {
    B(i:Int);
    @:json("C") C;
}

class Bar implements Serializable {
    @:serialize public var stringVar:String = "str";
    @:serialize public var strings:Array<Array<String>> = [["str"]];
    // @:serialize public var map:Map<String, String> = ["key" => "val"];

    public function new() {}

    public function dump() {
        trace('dumping bar');
    }
}
