package fu;

@:autoBuild(fu.SerializableMacro.build())
interface Serializable {
    function dump():Dynamic;
    function load(data:Dynamic):Void;
}