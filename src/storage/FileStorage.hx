package storage;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class FileStorage implements Storage {
    var data:Dynamic = {};

    public function new() {
        try {
            var rdata = File.getContent(getFileLocation());
            data = Json.parse(rdata);
        } catch (e:Dynamic) {
            trace("no storage at " + getFileLocation(), e);
        }
    }

    function ensureDir(path) {
        var dir = Path.directory(path);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
    }

    function getFileLocation() {
        return Path.join([
            lime.system.System.applicationStorageDirectory,
            #if !mobile // there is no app sandbox on windows and app-name based collision is very possible
            Macros.pkg(),
            #end
            "localStorage.json"
        ]);
    }

    public function saveValue(key:String, val:Dynamic):Void {
        Reflect.setField(data, key, val);
        var path = getFileLocation();
        ensureDir(path);
        File.saveContent(path, Json.stringify(data, null, " "));
    }

    public function getValue(key:String, defaultVal:Dynamic):Dynamic {
        var val = Reflect.field(data, key);
        if (val == null)
            return defaultVal;
        return val;
    }
}
