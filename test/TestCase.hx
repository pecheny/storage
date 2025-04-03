import haxe.Json;
import fu.Serializable;
import utest.Assert;
import utest.Async;

class TestCase extends utest.Test {
    var foo:Foo;
    var bar:Bar;
    var fixArray:Array<Bar>;

    public function setup() {
        foo = new Foo();
        bar = foo.cl;
        fixArray = foo.fixedBars;

        var data = '{
            "intVar":6,
            "map":[["key", "newVal"]],
            "cl": { "stringVar": "rts", "strings": [["foo", "bar"]] },
            "enu": {"C":{}},
            "boolVar": false,
            "fixedBars": [{ "stringVar": "fixed", "strings": [["foo", "bar"]] }],
            "bars": [{ "stringVar": "ttt", "strings": [["foo", "bar"]] }]
        }';
        var deser = Json.parse(data);

        foo.load(deser);
        trace("foo ", foo.enu);
        trace(foo.dump());
    }


    function specField() {
        foo.boolVar == false;
        foo.intVar == 6;
    }

    function specMap() {
        foo.map["key"] == "newVal";
    }

    function specClass() {
        bar == foo.cl;
        bar.stringVar == "rts";
        bar.strings[0][1] == "bar";
    }

    function specDynArray() {
        foo.bars[0].stringVar == "ttt";
    }

    function specFixArray() {
        fixArray == foo.fixedBars;
        foo.fixedBars[0].stringVar == "fixed";
    }
    
    function specEnum() {
        foo.enu.match(C) == true;
    }
    
    
}

class Foo implements Serializable {
    @:serialize public var intVar:Int = 5;
    @:serialize public var boolVar:Bool = true;

    @:serialize public var cl:Bar = new Bar();
    @:serialize public var map:Map<String, String> = ["key" => "val"];

    @:serialize(itemCtr = new Bar()) public var bars:Array<Bar> = [];
    @:serialize(fixedArray = true) public var fixedBars:Array<Bar> = [new Bar()];

    // @:serialize var data:DataParam = {value: "DATA"};
    @:serialize public var enu:A = IntParam(5);
    // @:serialize public var enu:A = Folded(Afo);
    // @:serialize var fo:Folded = Afo;

    public function new() {}
}

typedef DataParam = {
    value:String,
}


enum Folded {
    Afo(v:String);
    Bfo;
}

enum A {
    IntParam(intVar:Int);
    StringPara(strVar:String);
    // DataParam(data:DataParam);
    Folded(a:Folded);
    // ClassParam(inst:Bar);
    C;
}


class Bar implements Serializable {
    @:serialize public var stringVar:String = "str";
    @:serialize public var strings:Array<Array<String>> = [["str"]];

    public function new() {}

    public function dump() {
        trace('dumping bar');
    }
}
