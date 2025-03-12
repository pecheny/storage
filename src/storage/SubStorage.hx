package storage;

import storage.Storage;

class SubStorage implements Storage {
    var realStorage:Storage;
    var prefix:String;
    
    public function new(storage, prefix) {
        this.realStorage = storage;
        this.prefix = prefix;
    }

    public function saveValue(key:String, val:Dynamic):Void {
        var data = realStorage.getValue(prefix, {});
        Reflect.setField(data, key, val);
        realStorage.saveValue(prefix, data);
    }

    public function getValue(key:String, defaultVal:Dynamic):Dynamic {
        var data = realStorage.getValue(prefix, defaultVal);
        var val = Reflect.field(data, key);
        if (val == null)
            return defaultVal;
        return val;
    }
}
