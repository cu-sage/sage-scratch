/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// ScriptsPart.as
// John Maloney, November 2011
//
// This part holds the palette and scripts pane for the current sprite (or stage).

package ui.parts {
	import flash.display.*;
	import flash.text.*;
	import flash.utils.getTimer;

import flashx.textLayout.debug.assert;

import mx.controls.Text;

import mx.effects.Zoom;

import scratch.*;
	import ui.*;
	import uiwidgets.*;
	import util.*;

public class ScriptsPart extends UIPart {

	private var shape:Shape;
	private var selector:PaletteSelector;
	private var spriteWatermark:Bitmap;
	private var paletteFrame:ScrollFrame;

	private var scriptsFrames:Array = [];
    private var zoomWidget:ZoomWidget;
	private var newContainerButton:Button;
	private var closeContainerButtons:Array = [];
	private var upButtons:Array = [];
    private var downButtons:Array = [];
    private var constraintWidgets:Array = [];

	private const readoutLabelFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor, true);
	private const readoutFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor);

	private var xyDisplay:Sprite;
	private var xLabel:TextField;
	private var yLabel:TextField;
	private var xReadout:TextField;
	private var yReadout:TextField;
	private var lastX:int = -10000000; // impossible value to force initial update
	private var lastY:int = -10000000; // impossible value to force initial update
	private var firstScriptFrameChildIndex:int = -1;	// child index of first script pane

	public function ScriptsPart(app:Scratch) {
		this.app = app;

		addChild(shape = new Shape());
		addChild(spriteWatermark = new Bitmap());
		addXYDisplay();
		addChild(selector = new PaletteSelector(app));

		var palette:BlockPalette = new BlockPalette();
		palette.color = CSS.tabColor;
		paletteFrame = new ScrollFrame();
		paletteFrame.allowHorizontalScrollbar = false;
		paletteFrame.setContents(palette);
		addChild(paletteFrame);

		if (app.gameRoutes == null) app.gameRoutes = new GameRoutes(app);

		// zoom widget
		if (zoomWidget == null) {
			zoomWidget = new ZoomWidget(app.gameRoutes);
            addChild(zoomWidget);
        }


		appendScriptsPane(createScriptsPane());

        newContainerButton = new Button("New Container", function ():void {
            appendScriptsPane(createScriptsPane());
			setWidthHeight(w, h);
        });
        addChild(newContainerButton);

        app.palette = palette;
	}

	// Update the constraints widgets
    public function updateConstraints():void {
		for each (var widget:ConstraintsWidget in constraintWidgets) {
			widget.updateConstraints();
		}
    }

	public function toggleDesignMode(isOn:Boolean):void {
		newContainerButton.visible = isOn;
		for each (var b1:Button in upButtons) b1.visible = isOn;
        for each (var b2:Button in downButtons) b2.visible = isOn;
        for each (var b3:Button in closeContainerButtons) b3.visible = isOn;
		for each (var w:ConstraintsWidget in constraintWidgets) isOn ? w.renderDesignMode() : w.renderPlayMode();
		updateConstraints();
	}


	// Clear the ui and redraw with given script panes
	public function clearAndRedrawWith(scriptPanes:Array):void {
		clearChildren(scriptsFrames);
        clearChildren(closeContainerButtons);
        clearChildren(upButtons);
        clearChildren(downButtons);
		clearChildren(constraintWidgets);
        closeContainerButtons = [];
        upButtons = [];
		downButtons = [];
        scriptsFrames = [];
		constraintWidgets = [];

		// repopulate ui with given script panes
		if (scriptPanes == null || scriptPanes.length == 0) { // have at least one scripts pane
            appendScriptsPane(createScriptsPane());
		} else {
            for each (var pane:ScriptsPane in scriptPanes) {
                appendScriptsPane(pane);
            }
        }

		setWidthHeight(w, h); // redraw ui
		toggleDesignMode(app.interp.sageDesignMode);
	}

	// detach children from parent
	public function clearChildren(children:Array):void {
		for each (var child:Sprite in children) {
			removeChild(child);
			child = null;
		}
	}

	// create a new scripts pane and update the game routes variable
	public function createScriptsPane():ScriptsPane {
        var scriptsPane:ScriptsPane = new ScriptsPane(app);
        app.gameRoutes.appendToRoute(scriptsPane);
		return scriptsPane;
	}

	// Add a new scripts pane to the ui.
	public function appendScriptsPane(scriptsPane:ScriptsPane):void {
		scriptsPane.setScale(app.gameRoutes.getScale());

		var scrollFrame = new ScrollFrame();
		scrollFrame.setContents(scriptsPane);
		addChild(scrollFrame);
		scriptsFrames.push(scrollFrame);

		if (scriptsFrames.length == 1) firstScriptFrameChildIndex = getChildIndex(scriptsFrames[0]);

		// determine how many close buttons to add
		var numCloseButtons:int = 0;
		if (scriptsFrames.length == 2) numCloseButtons = 2;
		if (scriptsFrames.length > 2) numCloseButtons = 1;

		// close button/s
		for (var i:int = 0; i < numCloseButtons; i++) {
			var closeButton:Button = new Button("Close", function ():void {
                removeScriptsPaneAt(this.tag);
            });

            closeContainerButtons.push(closeButton);
            addChild(closeButton);
        }

		// order buttons
		if (scriptsFrames.length >= 2) {
            var upButton:Button = new Button("Up", function ():void {
                swapScriptPanes(this.tag, this.tag - 1)
            });
            var downButton:Button = new Button("Down", function ():void {
                swapScriptPanes(this.tag, this.tag + 1)
            });
            upButtons.push(upButton);
            downButtons.push(downButton);
            addChild(upButton);
            addChild(downButton);
        }

        // Constraint widget
        var cw:ConstraintsWidget = new ConstraintsWidget(scriptsPane, app.interp.sageDesignMode);
        constraintWidgets.push(cw);
        addChild(cw);

        updateConstraints();
        updateButtonTags();
    }

	// remove a scripts pane. Whenever there is 1 pane remaining, remove close and order buttons.
	public function removeScriptsPaneAt(index:int):void {
		if (scriptsFrames.length == 2) {
            removeChild(closeContainerButtons.pop());
            removeChild(closeContainerButtons.pop());
        } else {
            removeChild(closeContainerButtons.removeAt(index));
		}

		if (scriptsFrames.length == 2 || index == scriptsFrames.length-1) {
			removeChild(upButtons.pop());
            removeChild(downButtons.pop());
		} else if (index == 0) {
            removeChild(upButtons.removeAt(index));
            removeChild(downButtons.removeAt(index));
		} else {
            removeChild(upButtons.removeAt(index-1));
            removeChild(downButtons.removeAt(index));
		}

		removeChild(constraintWidgets.removeAt(index));
        removeChild(scriptsFrames.removeAt(index));
		app.gameRoutes.removeFromRoute(index);

        updateButtonTags();
        setWidthHeight(w, h);
	}

	// swap the position of two scripts panes
	public function swapScriptPanes(i:int, j:int):void {
        app.gameRoutes.swapRoutePanes(i, j);
		swap(scriptsFrames, i, j);
        swap(constraintWidgets, i, j);

        // update z index so that scripts pane is in front of buttons
		setChildIndex(scriptsFrames[i], firstScriptFrameChildIndex);
        setChildIndex(scriptsFrames[j], firstScriptFrameChildIndex);

		updateConstraints();
		setWidthHeight(w, h);
    }

	// generic swap function for an array of Sprites
	private function swap(arr:Array, i:int, j:int):void {
        var temp:Sprite = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
	}

	// Set the tags for each button. helps determine which button has been pressed
	public function updateButtonTags():void {
        for (var i:int = 0; i < closeContainerButtons.length; i++) {
            closeContainerButtons[i].tag = i;
        }

		for (var i:int = 0; i < upButtons.length; i++) {
            upButtons[i].tag = i+1;
            downButtons[i].tag = i;
		}
	}


	public function resetCategory():void { selector.select(Specs.motionCategory) }

	public function updatePalette():void {
		selector.updateTranslation();
		selector.select(selector.selectedCategory);
	}
	
	public function getSagePalettes():Array {
		return selector.sageCategories;
	}
	
	public function setSagePalettes(palettes:Array):void {
		selector.sageCategories = util.JSON.clone(palettes);
	}	

	public function updateSpriteWatermark():void {
		var target:ScratchObj = app.viewedObj();
		if (target && !target.isStage) {
			spriteWatermark.bitmapData = target.currentCostume().thumbnail(40, 40, false);
		} else {
			spriteWatermark.bitmapData = null;
		}
	}

	public function step():void {
		// Update the mouse readouts. Do nothing if they are up-to-date (to minimize CPU load).
		var target:ScratchObj = app.viewedObj();
		if (target.isStage) {
			if (xyDisplay.visible) xyDisplay.visible = false;
		} else {
			if (!xyDisplay.visible) xyDisplay.visible = true;

			var spr:ScratchSprite = target as ScratchSprite;
			if (!spr) return;
			if (spr.scratchX != lastX) {
				lastX = spr.scratchX;
				xReadout.text = String(lastX);
			}
			if (spr.scratchY != lastY) {
				lastY = spr.scratchY;
				yReadout.text = String(lastY);
			}
		}
		updateExtensionIndicators();
	}

	private var lastUpdateTime:uint;

	private function updateExtensionIndicators():void {
		if ((getTimer() - lastUpdateTime) < 500) return;
		for (var i:int = 0; i < app.palette.numChildren; i++) {
			var indicator:IndicatorLight = app.palette.getChildAt(i) as IndicatorLight;
			if (indicator) app.extensionManager.updateIndicator(indicator, indicator.target);
		}		
		lastUpdateTime = getTimer();
	}

	public function setWidthHeight(w:int, h:int):void {
		this.w = w;
		this.h = h;
		fixlayout();
		redraw();
	}

	private function fixlayout():void {
		selector.x = 1;
		selector.y = 5;

		paletteFrame.x = selector.x;
		paletteFrame.y = selector.y + selector.height + 2;
		paletteFrame.setWidthHeight(selector.width + 1, h - paletteFrame.y - 2); // 5

        var margin:int = 5;
        var startX:int = selector.x + selector.width + 2;
		var startY:int = selector.y;
		var height:int = (h - startY - margin*2) / scriptsFrames.length;
		var width:int = w - startX - margin;

		for (var i:int = 0; i < scriptsFrames.length; i++) {
			scriptsFrames[i].x = startX;
			scriptsFrames[i].y = startY + (height * i) + margin;
            scriptsFrames[i].setWidthHeight(width, height);
        }

		spriteWatermark.x = w - 60;
		spriteWatermark.y = scriptsFrames[0].y + 10;

		xyDisplay.x = spriteWatermark.x + 1;
		xyDisplay.y = spriteWatermark.y + 43;

		// close buttons
		for (var i:int = 0; i < closeContainerButtons.length; i++) {
            closeContainerButtons[i].x = scriptsFrames[i].x + scriptsFrames[i].width - closeContainerButtons[i].width - margin;
            closeContainerButtons[i].y = scriptsFrames[i].y + margin;
		}

		for (var i:int = 0; i < upButtons.length; i++) {
            upButtons[i].x = closeContainerButtons[i].x;
            upButtons[i].y = closeContainerButtons[i].y + closeContainerButtons[i].height + margin + height;

            downButtons[i].x = closeContainerButtons[i].x;
            downButtons[i].y = i > 0 ?
					upButtons[i-1].y + upButtons[i-1].height + margin :
                    closeContainerButtons[i].y + closeContainerButtons[i].height + margin;
		}

		// Constraint widgets
        for (var i:int = 0; i < constraintWidgets.length; i++) {
			constraintWidgets[i].x = scriptsFrames[i].x + margin;
			constraintWidgets[i].y = scriptsFrames[i].y + margin;
        }

		zoomWidget.x = w - zoomWidget.width - 3;
        zoomWidget.y = -zoomWidget.height - 4;

        // zoom widget
        newContainerButton.x = zoomWidget.x - newContainerButton.width - 10;
        newContainerButton.y = -newContainerButton.height - 4;
	}

	private function redraw():void {
		var paletteW:int = paletteFrame.visibleW();
		var paletteH:int = paletteFrame.visibleH();

		var g:Graphics = shape.graphics;
		g.clear();
		g.lineStyle(1, CSS.borderColor, 1, true);
		g.beginFill(CSS.tabColor);
		g.drawRect(0, 0, w, h);
		g.endFill();

		var lineY:int = selector.y + selector.height;
		var darkerBorder:int = CSS.borderColor - 0x141414;
		var lighterBorder:int = 0xF2F2F2;
		g.lineStyle(1, darkerBorder, 1, true);
		hLine(g, paletteFrame.x + 8, lineY, paletteW - 20);
		g.lineStyle(1, lighterBorder, 1, true);
		hLine(g, paletteFrame.x + 8, lineY + 1, paletteW - 20);

		g.lineStyle(1, darkerBorder, 1, true);

		for (var i:int = 0; i < scriptsFrames.length; i++) {
            g.drawRect(
				scriptsFrames[i].x - 1,
				scriptsFrames[i].y - 1,
				scriptsFrames[i].visibleW() + 1,
				scriptsFrames[0].visibleH() + 1
			);
        }
    }

	private function hLine(g:Graphics, x:int, y:int, w:int):void {
		g.moveTo(x, y);
		g.lineTo(x + w, y);
	}

	private function addXYDisplay():void {
		xyDisplay = new Sprite();
		xyDisplay.addChild(xLabel = makeLabel('x:', readoutLabelFormat, 0, 0));
		xyDisplay.addChild(xReadout = makeLabel('-888', readoutFormat, 15, 0));
		xyDisplay.addChild(yLabel = makeLabel('y:', readoutLabelFormat, 0, 13));
		xyDisplay.addChild(yReadout = makeLabel('-888', readoutFormat, 15, 13));
		addChild(xyDisplay);
	}

	public function getPaletteSelector():PaletteSelector {
		return this.selector;
	}

}}
