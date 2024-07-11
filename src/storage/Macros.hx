package storage;

class Macros {
    public static macro function pkg() {
        #if macro
        var defines:Map<String, String> = haxe.macro.Context.getDefines();
        var val = defines.get("localStoragePrefix");
        if (val != null)
            return macro $v{val};
        else
            return macro "";
        #end
    }
}
