package;

import storage.Storage;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.display.Sprite;

class Main extends Sprite {
    var tf = new TextField();
    var storage:Storage;
    var key = "key";
    var val:Int;

    public function new() {
        super();
        addChild(tf);
        tf.text = "---";
        storage = new storage.LocalStorage();
        val = storage.getValue(key, 0);
        addButton("Incr", e -> {
            val++;
            storage.saveValue(key, val);
            invdLbl();
        });
        invdLbl();
    }

    function invdLbl() {
        tf.text = "val: " + val;
    }

    var dy = 100;

    function addButton(caption, handler) {
        var spr = new Sprite();
        spr.graphics.beginFill(0x90bbff);
        spr.graphics.drawRect(0, -20, 300, 80);
        spr.graphics.endFill();
        
        var tf = new TextField();
        spr.addChild(tf);
        spr.y = dy += 100;
        tf.text = caption;
        addChild(spr);
        spr.addEventListener(MouseEvent.CLICK, handler);
    }
}
