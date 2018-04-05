package {
import uiwidgets.ScriptsPane;

import blocks.Block;

import scratch.ScratchComment;

public class GameRoutes {

    private var routes:Array = [];      //  2D array of game routes
    private var activeIndex:int = 0;    // index of the active game route in the UI

    // Append a scripts pane to the active game route
    public function appendToRoute(pane:ScriptsPane):void {
        if (routes.length <= activeIndex) {
            routes.push([]);
        }
        (routes[activeIndex] as Array).push(pane);
    }


    // remove pane from active game route at index i
    public function removeFromRoute(i:int):void {
        (routes[activeIndex] as Array).removeAt(i);
    }


    // swap the two routes at given indices for the active game route
    public function swapRoutePanes(i:int, j:int):void {
        var temp:ScriptsPane = routes[activeIndex][i];
        routes[activeIndex][i] = routes[activeIndex][j];
        routes[activeIndex][j] = temp;
    }

    public function updateFeedbackFor(b:Block):void {
        for (var i:int = 0; i < routes[activeIndex].length; i++) {
            var pane:ScriptsPane = routes[activeIndex][i];
            pane.updateFeedbackFor(b);
        }
    }

    public function draggingDone():void {
        for (var i:int = 0; i < routes[activeIndex].length; i++) {
            var pane:ScriptsPane = routes[activeIndex][i];
            pane.draggingDone();
        }
    }

    public function prepareToDrag(b:Block):void {
        for (var i:int = 0; i < routes[activeIndex].length; i++) {
            var pane:ScriptsPane = routes[activeIndex][i];
            pane.prepareToDrag(b);
        }
    }

    public function prepareToDragComment(c:ScratchComment):void {
        for (var i:int = 0; i < routes[activeIndex].length; i++) {
            var pane:ScriptsPane = routes[activeIndex][i];
            pane.prepareToDragComment(c);
        }
    }

    public function setScale(newScale:Number):void {
        for (var r:int = 0; r < routes.length; r++) {
            for (var c:int = 0; c < routes[r].length; c++) {
                var pane:ScriptsPane = routes[r][c];
                pane.setScale(newScale);
            }
        }
    }

    // get the current scale of the game route. All script panes should have the same scale.
    // Returns the scale, or 1 if no script panes are in the route.
    public function getScale():Number {
        if (routes.length < 1 || routes[activeIndex].length > 1) return 1;
        var pane:ScriptsPane = routes[activeIndex][0];
        return pane.scaleX;
    }

    public function findTargetsFor(b:Block):void {
        for (var i:int = 0; i < routes[activeIndex].length; i++) {
            var pane:ScriptsPane = routes[activeIndex][i];
            pane.findTargetsFor(b);
        }
    }
}
}