package uiwidgets {
import flash.display.Sprite;
import flash.events.Event;
import flash.text.*;

public class ConstraintsWidget extends Sprite {

    private static const MARGIN:int = 5;
    private static const PADDING:int = 1;
    private static const errorfmt:TextFormat = new TextFormat(CSS.font, 12, CSS.errorText, true);
    private static const fmt:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor, true);

    private var scriptsPane:ScriptsPane;
    private var numBlocksLabel:TextField;
    private var maxBlocksLabel:TextField;
    private var numPointsLabel:TextField;
    private var maxPointsLabel:TextField;

    public function ConstraintsWidget(scriptsPane:ScriptsPane, designMode:Boolean) {
        this.scriptsPane = scriptsPane;
        if (designMode) renderDesignMode();
        else renderPlayMode();
    }

    // render the UI for design mode
    public function renderDesignMode():void {
        clearUI();

        // # of blocks
        var label:TextField;
        addChild(label = makeLabel("Max Blocks:", 0, 0, true, false));
        addChild(maxBlocksLabel = makeLabel(scriptsPane.maxBlocks.toString(), label.x + label.width + MARGIN, 0, false, true));
        if (scriptsPane.maxBlocks <= 0) maxBlocksLabel.text = "";
        maxBlocksLabel.addEventListener(Event.CHANGE, maxBlocksChanged);

        // # of points
        addChild(label = makeLabel("Max Points:", 0, maxBlocksLabel.height + MARGIN, true, false));
        addChild(maxPointsLabel = makeLabel(scriptsPane.maxPoints.toString(), label.x + label.width + MARGIN, label.y, false, true));
        if (scriptsPane.maxPoints <= 0) maxPointsLabel.text = "";
        maxPointsLabel.addEventListener(Event.CHANGE, maxPointsChanged);
    }

    // render the UI for play mode
    public function renderPlayMode():void {
        clearUI();

        // # of blocks
        var label:TextField;
        addChild(label = makeLabel("Blocks:", 0, 0, true, false));
        addChild(numBlocksLabel = makeLabel("0", label.x + label.width + MARGIN, 0, true, false));
        if (scriptsPane.maxBlocks > 0) {
            addChild(label = makeLabel("/", numBlocksLabel.x + numBlocksLabel.width + PADDING, 0, true, false));
            addChild(maxBlocksLabel = makeLabel(scriptsPane.maxBlocks.toString(), label.x + label.width + PADDING, 0, true, false));
        }

        // # of points
        addChild(label = makeLabel("Points:", 0, label.height + MARGIN, true, false));
        addChild(numPointsLabel = makeLabel("0", label.x + label.width + MARGIN, label.y, true, false));
        if (scriptsPane.maxPoints > 0) {
            addChild(label = makeLabel("/", numPointsLabel.x + numPointsLabel.width + PADDING, numPointsLabel.y, true, false));
            addChild(maxPointsLabel = makeLabel(scriptsPane.maxPoints.toString(), label.x + label.width + PADDING, label.y, true, false));
        }

        updateConstraints();
    }

    private function clearUI():void {
        while (numChildren > 0) removeChildAt(0);
        numBlocksLabel = maxBlocksLabel = numPointsLabel = maxPointsLabel = null;
    }


    // Update the values in this widget based on the associated scripts pane
    public function updateConstraints():void {
        if (numBlocksLabel != null) {
            numBlocksLabel.text = scriptsPane.numBlocks.toString();
            numBlocksLabel.setTextFormat(scriptsPane.maxBlocks > 0 && scriptsPane.numBlocks > scriptsPane.maxBlocks ? errorfmt : fmt);
        }
        if (numPointsLabel != null) {
            numPointsLabel.text = scriptsPane.numPoints.toString();
            numPointsLabel.setTextFormat(scriptsPane.numPoints > 0 && scriptsPane.numPoints > scriptsPane.maxPoints ? errorfmt : fmt);
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

    // ****** Event Listeners ******
    public function maxBlocksChanged(event:Event):void {
        if (event.currentTarget.length == 0) scriptsPane.maxBlocks = 0;
        else scriptsPane.maxBlocks = parseInt(event.currentTarget.text);
    }
    public function maxPointsChanged(event:Event):void {
        if (event.currentTarget.length == 0) scriptsPane.maxPoints = 0;
        else scriptsPane.maxPoints = parseInt(event.currentTarget.text);
    }
}}
