package {
import flash.utils.Dictionary;

import uiwidgets.ScriptsPane;
import blocks.Block;
import flash.display.DisplayObject;
import scratch.ScratchComment;
import scratch.ScratchObj;
import flash.display.Sprite;

public class GameRoutes {

    private var viewedObjID:String = "";                     // The current sprite uuid
    private var viewedObj:ScratchObj;                       // the current sprite
    private var routes:Dictionary = new Dictionary();      //  Maps the sprite to a list of game routes
    private var app:Scratch;

    public function GameRoutes(app:Scratch) {
        this.app = app;
    }


    public function getPadding():int {
        if (routes[viewedObjID] == null) return 0;
        return (routes[viewedObjID][0] as ScriptsPane).padding;
    }

    public function getXY():Array {
        if (routes[viewedObjID] == null)  return [0, 0];
        var pane:ScriptsPane = routes[viewedObjID][0] as ScriptsPane;
        return [pane.x, pane.y];
    }

    // Append a scripts pane to the active game route
    public function appendToRoute(pane:ScriptsPane):void {
        if (routes[viewedObjID] == null) {
            routes[viewedObjID] = [];
        }
        (routes[viewedObjID] as Array).push(pane);
    }

    // remove pane from active game route at index i
    public function removeFromRoute(i:int):void {
        if (routes[viewedObjID] == null) return;
        (routes[viewedObjID] as Array).removeAt(i);
    }

    // swap the two routes at given indices for the active game route
    public function swapRoutePanes(i:int, j:int):void {
        if (routes[viewedObjID] == null) return;

        var temp:ScriptsPane = routes[viewedObjID][i];
        routes[viewedObjID][i] = routes[viewedObjID][j];
        routes[viewedObjID][j] = temp;
    }


    // add a block to the active game route in the specified container
    public function addBlockToContainer(index:int, sprite:DisplayObject):Boolean {
        if (routes[viewedObjID] == null) return false;
        if (routes[viewedObjID].length <= index) return false;
        (routes[viewedObjID][index] as ScriptsPane).addChild(sprite);
        return true;

    }

    public function updateFeedbackFor(b:Block):void {
        if (routes[viewedObjID] == null) return;
        for (var i:int = 0; i < routes[viewedObjID].length; i++) {
            var pane:ScriptsPane = routes[viewedObjID][i];
            pane.updateFeedbackFor(b);
        }
    }

    public function draggingDone():void {
        if (routes[viewedObjID] == null) return;
        for (var i:int = 0; i < routes[viewedObjID].length; i++) {
            var pane:ScriptsPane = routes[viewedObjID][i];
            pane.draggingDone();
        }
    }

    public function prepareToDrag(b:Block):void {
        if (routes[viewedObjID] == null) return;
        for (var i:int = 0; i < routes[viewedObjID].length; i++) {
            var pane:ScriptsPane = routes[viewedObjID][i];
            pane.prepareToDrag(b);
        }
    }

    public function prepareToDragComment(c:ScratchComment):void {
        if (routes[viewedObjID] == null) return;
        for (var i:int = 0; i < routes[viewedObjID].length; i++) {
            var pane:ScriptsPane = routes[viewedObjID][i];
            pane.prepareToDragComment(c);
        }
    }

    public function setScale(newScale:Number):void {
        if (routes[viewedObjID] == null) return;
        for (var i:int = 0; i < routes[viewedObjID].length; i++) {
            var pane:ScriptsPane = routes[viewedObjID][i];
            pane.setScale(newScale);
        }
    }

    // get the current scale of the game route. All script panes should have the same scale.
    // Returns the scale, or 1 if no script panes are in the route.
    public function getScale():Number {
        if (routes[viewedObjID] == null) return 1;
        var pane:ScriptsPane = routes[viewedObjID][0];
        return pane.scaleX;
    }

    public function findTargetsFor(b:Block):void {
        if (routes[viewedObjID] == null) return;
        for (var i:int = 0; i < routes[viewedObjID].length; i++) {
            var pane:ScriptsPane = routes[viewedObjID][i];
            pane.findTargetsFor(b);
        }
    }

    public function viewScriptsFor(obj:ScratchObj):void {
        if (routes[viewedObjID] == null) return;

        saveScripts(false);

        if (obj != null) {
            viewedObj = obj;
            viewedObjID = obj.uuid;
            app.scriptsPart.clearAndRedrawWith(routes[viewedObjID]);
        }

        for each (var pane:ScriptsPane in routes[viewedObjID]) {
            pane.resetUI();
        }

//        for (var i:int = 0; i < routes[viewedObjID].length; i++) {
//            var pane:ScriptsPane = routes[viewedObjID][i];
//            pane.viewScriptsFor(obj);
//        }
    }

    // Save the blocks in each pane to the viewed objects scripts list.
    public function saveScripts(saveNeeded:Boolean = true):void {
        if (viewedObj == null) return;
        viewedObj.scripts.splice(0); // remove all
        viewedObj.scriptComments.splice(0); // remove all

        for (var t:int = 0; t < routes[viewedObjID].length; t++) {
            var pane:ScriptsPane = routes[viewedObjID][t];

            for (var i:int = 0; i < pane.numChildren; i++) {
                var o:* = pane.getChildAt(i);
                if (o is Block) viewedObj.scripts.push(o);
                if (o is ScratchComment) viewedObj.scriptComments.push(o);
            }

            var blockList:Array = viewedObj.allBlocks();
            for each (var c:ScratchComment in viewedObj.scriptComments) {
                c.updateBlockID(blockList);
            }

            if (saveNeeded) app.setSaveNeeded();
//            fixCommentLayout();
        }
    }


}
}