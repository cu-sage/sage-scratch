package {
import flash.utils.Dictionary;

import uiwidgets.ScriptsPane;
import blocks.Block;
import flash.display.DisplayObject;
import scratch.ScratchComment;
import scratch.ScratchObj;
import flash.display.Sprite;

public class GameRoutes {

    private var viewedObj:String = "";                     // The current sprite uuid
    private var routes:Dictionary = new Dictionary();      //  Maps the sprite to a list of game routes
    private var app:Scratch;

    public function GameRoutes(app:Scratch) {
        this.app = app;
    }


    public function getPadding():int {
        if (routes[viewedObj] == null) return 0;
        return (routes[viewedObj][0] as ScriptsPane).padding;
    }

    public function getXY():Array {
        if (routes[viewedObj] == null)  return [0, 0];
        var pane:ScriptsPane = routes[viewedObj][0] as ScriptsPane;
        return [pane.x, pane.y];
    }

    // Append a scripts pane to the active game route
    public function appendToRoute(pane:ScriptsPane):void {
        if (routes[viewedObj] == null) {
            routes[viewedObj] = [];
        }
        (routes[viewedObj] as Array).push(pane);
    }

    // remove pane from active game route at index i
    public function removeFromRoute(i:int):void {
        if (routes[viewedObj] == null) return;
        (routes[viewedObj] as Array).removeAt(i);
    }

    // swap the two routes at given indices for the active game route
    public function swapRoutePanes(i:int, j:int):void {
        if (routes[viewedObj] == null) return;

        var temp:ScriptsPane = routes[viewedObj][i];
        routes[viewedObj][i] = routes[viewedObj][j];
        routes[viewedObj][j] = temp;
    }


    // add a block to the active game route in the specified container
    public function addBlockToContainer(index:int, sprite:DisplayObject):Boolean {
        if (routes[viewedObj] == null) return false;
        if (routes[viewedObj].length <= index) return false;
        (routes[viewedObj][index] as ScriptsPane).addChild(sprite);
        return true;

    }

    public function updateFeedbackFor(b:Block):void {
        if (routes[viewedObj] == null) return;
        for (var i:int = 0; i < routes[viewedObj].length; i++) {
            var pane:ScriptsPane = routes[viewedObj][i];
            pane.updateFeedbackFor(b);
        }
    }

    public function draggingDone():void {
        if (routes[viewedObj] == null) return;
        for (var i:int = 0; i < routes[viewedObj].length; i++) {
            var pane:ScriptsPane = routes[viewedObj][i];
            pane.draggingDone();
        }
    }

    public function prepareToDrag(b:Block):void {
        if (routes[viewedObj] == null) return;
        for (var i:int = 0; i < routes[viewedObj].length; i++) {
            var pane:ScriptsPane = routes[viewedObj][i];
            pane.prepareToDrag(b);
        }
    }

    public function prepareToDragComment(c:ScratchComment):void {
        if (routes[viewedObj] == null) return;
        for (var i:int = 0; i < routes[viewedObj].length; i++) {
            var pane:ScriptsPane = routes[viewedObj][i];
            pane.prepareToDragComment(c);
        }
    }

    public function setScale(newScale:Number):void {
        if (routes[viewedObj] == null) return;
        for (var i:int = 0; i < routes[viewedObj].length; i++) {
            var pane:ScriptsPane = routes[viewedObj][i];
            pane.setScale(newScale);
        }
    }

    // get the current scale of the game route. All script panes should have the same scale.
    // Returns the scale, or 1 if no script panes are in the route.
    public function getScale():Number {
        if (routes[viewedObj] == null) return 1;
        var pane:ScriptsPane = routes[viewedObj][0];
        return pane.scaleX;
    }

    public function findTargetsFor(b:Block):void {
        if (routes[viewedObj] == null) return;
        for (var i:int = 0; i < routes[viewedObj].length; i++) {
            var pane:ScriptsPane = routes[viewedObj][i];
            pane.findTargetsFor(b);
        }
    }

    public function viewScriptsFor(obj:ScratchObj):void {
        if (routes[viewedObj] == null) return;

        for each (var pane:ScriptsPane in routes[viewedObj]) {
            pane.saveScripts(false);
        }

        if (obj != null) {
            viewedObj = obj.uuid;
            app.scriptsPart.clearAndRedrawWith(routes[viewedObj]);
        }

        for each (var pane:ScriptsPane in routes[viewedObj]) {
            pane.resetUI();
        }

//        for (var i:int = 0; i < routes[viewedObj].length; i++) {
//            var pane:ScriptsPane = routes[viewedObj][i];
//            pane.viewScriptsFor(obj);
//        }
    }


    public function saveScripts(saveNeeded:Boolean = true):void {
        //TODO: (Gavi) Implement. Maybe should call saveScripts() of each scripts pane and combine
    }


}
}