package storage;
interface Storage {
  function saveValue(key:String, val:Dynamic):Void;
  function getValue(key:String, defaultVal:Dynamic):Dynamic ;
}
