package uiwidgets {
import flash.display.Sprite;
import flash.text.*;
import flash.events.TextEvent;

public class ConstraintsWidget extends Sprite {

    private static const MARGIN:int = 5;
    private static const PADDING:int = 1;
    private static const errorfmt:TextFormat = new TextFormat(CSS.font, 12, CSS.errorText, true);
    private static const fmt:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor, true);

    private var scriptsPane:ScriptsPane;
    private var numBlocksLabel:TextField;
    private var maxBlocksLabel:TextField;

    public function ConstraintsWidget(scriptsPane:ScriptsPane, designMode:Boolean) {
        this.scriptsPane = scriptsPane;
        if (designMode) renderDesignMode();
        else renderPlayMode();
    }

    // render the UI for design mode
    public function renderDesignMode():void {
        clearUI();

        var label:TextField;
        addChild(label = makeLabel("Max Blocks:", 0, 0, true, false));
        addChild(maxBlocksLabel = makeLabel(scriptsPane.maxBlocks.toString(), label.x + label.width + MARGIN, 0, false, true));
        if (scriptsPane.maxBlocks <= 0) maxBlocksLabel.text = "";
        maxBlocksLabel.addEventListener(TextEvent.TEXT_INPUT, maxBlocksChanged);
    }

    // render the UI for play mode
    public function renderPlayMode():void {
        clearUI();

        var label:TextField;
        addChild(label = makeLabel("Blocks:", 0, 0, true, false));
        addChild(numBlocksLabel = makeLabel("0", label.x + label.width + MARGIN, 0, true, false));
        if (scriptsPane.maxBlocks > 0) {
            addChild(label = makeLabel("/", numBlocksLabel.x + numBlocksLabel.width + PADDING, 0, true, false));
            addChild(maxBlocksLabel = makeLabel(scriptsPane.maxBlocks.toString(), label.x + label.width + PADDING, 0, true, false));
        }
        updateConstraints();
    }

    private function clearUI():void {
        while (numChildren > 0) removeChildAt(0);
        numBlocksLabel = null;
        maxBlocksLabel = null;
    }


    // Update the values in this widget based on the associated scripts pane
    public function updateConstraints():void {
        if (numBlocksLabel != null) {
            numBlocksLabel.text = scriptsPane.numBlocks.toString();
            numBlocksLabel.setTextFormat(scriptsPane.maxBlocks > 0 && scriptsPane.numBlocks > scriptsPane.maxBlocks ? errorfmt : fmt);
        }
    }

    private static function makeLabel(text:String, x:int, y:int, autoSize:Boolean, input:Boolean):TextField {
        var tf:TextField = new TextField();
        tf.selectable = input;
        tf.background = input;
        tf.defaultTextFormat = fmt;
        tf.text = text;
        tf.x = x;
        tf.y = y;
        tf.restrict = "0-9";
        if (input) tf.type = TextFieldType.INPUT;

        if (autoSize)  {
            tf.autoSize = TextFieldAutoSize.LEFT
        } else {
            tf.width = 50;
            tf.height = 15;
        }
        return tf;
    }

    public function maxBlocksChanged(event:TextEvent):void {
        scriptsPane.maxBlocks = parseInt(event.text);
    }

}}
