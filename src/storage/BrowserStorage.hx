package storage;

import js.Browser;

class BrowserStorage implements Storage {
    public function new() {}

    public function saveValue(key:String, val:Dynamic):Void {
        Browser.window.localStorage.setItem(key, val);
    }

    public function getValue(key:String, defaultVal:Dynamic):Dynamic {
        var val = null;
        try {
            val = Browser.window.localStorage.getItem(key);
        } catch (e:Dynamic) {
            trace('cant read value "$key" from storage');
        }
        if (val == null)
            return defaultVal;
        return val;
    }
}
