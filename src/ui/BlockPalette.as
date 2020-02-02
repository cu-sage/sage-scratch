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

// BlockPalette.as
// John Maloney, August 2009
//
// A BlockPalette holds the blocks for the selected category.
// The mouse handling code detects when a Block's parent is a BlocksPalette and
// creates a copy of that block when it is dragged out of the palette.

package ui {

	import blocks.Block;
	import interpreter.Interpreter;

import mx.utils.ObjectUtil;

import uiwidgets.*;
	import scratch.ScratchObj;
	import scratch.ScratchComment;

import flash.events.Event;

import uiwidgets.ScriptsPane;

import util.Logger;


public class BlockPalette extends ScrollFrameContents {

	public const isBlockPalette:Boolean = true;
	public const hints:Hints = new Hints();
	private var nextAutoHintTime:Date = null;
	public var scriptsPane:ScriptsPane;


	public function BlockPalette():void {
		super();
		this.color = 0xE0E0E0;
	}

	override public function clear(scrollToOrigin:Boolean = true):void {
		var interp:Interpreter = Scratch.app.interp;
		var targetObj:ScratchObj = Scratch.app.viewedObj();
		while (numChildren > 0) {
			var b:Block = getChildAt(0) as Block;
			if (interp.isRunning(b, targetObj)) interp.toggleThread(b, targetObj);
			removeChildAt(0);
		}
		if (scrollToOrigin) x = y = 0;
	}

	public function handleDrop(obj:*):Boolean {

		trace("blockpalette.handledrop called");

		// Delete blocks and stacks dropped onto the palette.
		var c:ScratchComment = obj as ScratchComment;
		if (c) {
			c.x = c.y = 20; // position for undelete
			c.deleteComment();
			return true;
		}
		var b:Block = obj as Block;


		//yc2937 if block was dragged from scripts pane to palette, decrement points

		if (b) {

			if (Scratch.app.blockDraggedFrom == Scratch.K_DRAGGED_FROM_SCRIPTS_PANE) {
				b.allBlocksDo(function(b:Block):void {
					trace ("dragged from scripts pane to palette: " + b.spec);

					//sm4241 - parsons logic
					//Scratch.app.parsonsLogic();
					//Scratch.app.decrementPoints(b.pointValue);

					// update block to hint on after deleting removed blocks

					// pz2244
					// when drag back, reveal blocks in palette
					//if (app.interp.gameType == "parsons") {
						for (var i = 0; i < 100; i++) {
							try {
								var vb:Block = Scratch.app.palette.getChildAt(i) as Block;
								trace(vb.spec);
								if (vb.spec == b.spec && !vb.visible) {
									trace("We are going to set " + i + " visible");
									vb.visible = true;
									break;
								}
							} catch (e) {
							}
						}
					// }
					latestHint(b);
				});
			}

			trace("blockpalette.handledrop resetting flag ");

			Scratch.app.blockDraggedFrom = Scratch.K_NOT_DRAGGED_FROM_PALETTE_OR_SCRIPTS_PANE;

			return b.deleteStack();
		}

		Scratch.app.blockDraggedFrom = Scratch.K_NOT_DRAGGED_FROM_PALETTE_OR_SCRIPTS_PANE;

		return false;
	}

	public static function strings():Array {
		return ['Cannot Delete', 'To delete a block definition, first remove all uses of the block.'];
	}

	// deletes blocks removed by user from latestBlockList
	private function updateLatestBlock(b:Block):Block {
		// update latest block for hinting purposes (to account for block(s) being removed)
		var latestList:Array = b.getLatestList();
		if (latestList.length > 0) {
			if (latestList.indexOf(b) >= 0) {
				latestList.splice(latestList.indexOf(b), 1);
			}
			if (latestList.length > 0) {
				b.updateLatest(latestList[latestList.length - 1].bottomBlock(), false, true);
			} else { // no more blocks present to use for hinting
				b.updateLatest(null, false, true);
			}
		} else { // no more blocks present to use for hinting
			b.updateLatest(null, false, true);
		}
		b.printLatest();
		var latestBlock:Block = b.getLatestBlock();
		return latestBlock;
	}

	private function latestHint(b:Block):void {
		var latestBlock:Block = updateLatestBlock(b);
		//if (latestBlock) {
			// see if a hint can be issued based on the current latest block
		var latestHint:Hints = new Hints(latestBlock);
		if (latestHint) {
			addChild(latestHint);
			latestHint.checkHint();
		}
	}

    /*
     * Updates hints with blocks to suggest and the nextAutoHintTime. If nextAutoHintTime is null, stop the
     * hint timer.
     * Currently, all given hints will be shown to the user simultaneously either on demand or automatically.
     * We can modify this to show only a subset of the blocks as hints by providing this subset to the
     * hints.setHints method.
     * yli Nov, 2018
     */
    public function updateHints(blocksToSuggest:Array, nextAutoHintTime:Date):void {

		// check if there are any updates to hints.
		if (blocksToSuggest.length === hints.getBlocksToSuggest().length
				&& ObjectUtil.dateCompare(this.nextAutoHintTime, nextAutoHintTime) === 0)
		{
            var sameBlocks:Boolean = true;
            for each (var block:String in hints.getBlocksToSuggest()) {
                if (blocksToSuggest.indexOf(block) < 0) {
                    sameBlocks = false;
					break;
				}
            }
            // Do nothing if no updates at all.
			if (sameBlocks) return;
		}
		hints.setBlocksToSuggest(blocksToSuggest);
        this.nextAutoHintTime = nextAutoHintTime;
		if (this.nextAutoHintTime) {
            const now:Date = new Date();
            const delay:Number = this.nextAutoHintTime.valueOf() - now.valueOf();
            hints.startTimer(delay);
		}
		else {
            hints.stopTimer();
		}
    }


    /*
     * Requests on-demand hints. Suggested blocks/categories will start shaking immediately.
	 * yli Nov, 2018
 	 */
    public function requestHints():void {
        Logger.logAll("requestHints");
        hints.showHints();
    }
}}
